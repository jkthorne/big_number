# BigNumber — Pure Crystal Arbitrary-Precision Arithmetic

Replace Crystal's GMP dependency with native code. No C, no FFI, no excuses.

## Philosophy

Don't architect. Write code. The structure will emerge from the code that works,
not from diagrams drawn before the first function compiles.

The algorithms are well-known (Knuth Vol 2, HAC, Wikipedia). Crystal gives us
`UInt128` for widening multiply and LLVM intrinsics for CLZ/CTZ. That's all we
need. Write the usage code first, make it compile, make it correct, make it fast.

**Reference material** (algorithms only, not code):
- Knuth, *The Art of Computer Programming*, Vol 2: Seminumerical Algorithms
- *Handbook of Applied Cryptography*, Chapter 14
- GMP documentation for algorithm descriptions (not source code)
- Wikipedia: Karatsuba, Toom-Cook, Burnikel-Ziegler

**License**: This is a clean-room implementation. We implement well-known
algorithms from textbooks. We do not read, copy, or translate GMP/mini-gmp
source code.

---

## The Representation

One struct. Sign-magnitude. UInt64 limbs. That's it.

```crystal
struct BigNumber::BigInt
  @limbs : Pointer(UInt64)  # least-significant limb first
  @alloc : Int32            # capacity (limb count)
  @size  : Int32            # used limbs; negative means negative number; 0 means zero
end
```

This is the only type that matters until integers are done and battle-tested.
BigRational and BigFloat come later — they're just consumers of BigInt.

---

## Step 1: Make It Exist

**Goal: `BigInt.new(42) + BigInt.new(17)` prints `"59"`. Benchmark it immediately.**

Write these in order, in one or two files, because each one depends on the last:

1. **`BigInt.new(value : Int)`** — Allocate limbs, store the value. Handle negative.
2. **`to_s`** — You cannot test anything you cannot print. Implement base-10
   conversion immediately. It doesn't have to be fast yet (repeated division by 10
   is fine).
3. **`BigInt.new(str : String, base = 10)`** — Parse strings. Now you can round-trip.
4. **`<=>`** — Compare two BigInts. Compare signs first, then magnitudes
   (limb-by-limb from the top). Include `Comparable(BigInt)` and
   `Comparable(Int)` right here, not in some future "wrapper phase."
5. **`+` and `-`** — The sign logic dispatches to unsigned add/sub on the limb
   arrays. Write the limb-array helpers as private methods, not in a separate
   module. Carry propagation for add, borrow propagation for sub. Handle
   different-sized operands.
6. **`*`** — Schoolbook multiply. O(n*m). Leave a comment: `# TODO: Karatsuba
   when min(n,m) > KARATSUBA_THRESHOLD`. Don't implement Karatsuba yet. Don't
   even define the threshold yet.
7. **`divmod`** — Truncating division. This is the hardest part. Algorithm D from
   Knuth Vol 2, Section 4.3.1. Get it right, don't try to be clever.
   `//` and `%` are floor-division and floor-remainder (Crystal convention).
   Implement in terms of truncating divmod + sign adjustment.

**Now benchmark.** Compare against Crystal's stdlib `BigInt` (which uses libgmp):
- Single-limb add/sub/mul (64-bit numbers)
- 10-limb numbers (~640 bits)
- 100-limb numbers (~6400 bits)

This benchmark runs from Step 1 onward. Every subsequent step re-runs it. If
we're 100x slower at single-limb add, something is fundamentally wrong and we
need to know *now*, not after writing 4,000 lines.

```crystal
# bench/sanity.cr — run this constantly
require "benchmark"
require "../src/big_number"

sizes = [1, 10, 100, 1000]
sizes.each do |n_limbs|
  ours   = BigNumber::BigInt.new("9" * (n_limbs * 19))  # ~n_limbs limbs
  theirs = ::BigInt.new("9" * (n_limbs * 19))

  Benchmark.ips do |x|
    x.report("BigNumber add #{n_limbs}L") { ours + ours }
    x.report("stdlib    add #{n_limbs}L") { theirs + theirs }
  end
end
```

---

## Step 2: Make It Complete

**Goal: Drop-in replacement for every `::BigInt` operation Crystal's stdlib exposes.**

Implement what people actually use, in the order they'll notice it missing:

1. **Bit operations**: `&`, `|`, `^`, `~`, `<<`, `>>`, `bit(n)`, `popcount`.
   Two's complement semantics for negative numbers (same as Ruby/Crystal convention).
   The sign-magnitude representation means you have to simulate two's complement
   for bitwise ops on negatives — this is annoying but well-understood.

2. **Number theory**: `gcd` (binary GCD — just do the algorithm, it's simple),
   `lcm`, `pow_mod` (binary exponentiation with Montgomery reduction or
   simple square-and-multiply to start), `prime?` (Miller-Rabin).

3. **Powers & roots**: `**`, `sqrt` (Newton's method on integers), `root(n)`.

4. **Conversions**: `to_i8` through `to_u64` (with overflow checks), `to_f64`,
   `to_s(base)` for bases 2-36, `to_bytes`/`from_bytes` (big-endian export/import),
   `hash`.

5. **Crystal integration**: `to_json`/`from_json`, `inspect`, mixed arithmetic
   with `Int` types (don't force users to wrap everything in `BigInt.new`).

Each of these gets tested by fuzz-comparing against stdlib `BigInt`:

```crystal
# For every operation we implement:
100_000.times do
  a_str = random_decimal_string(max_digits: 200)
  b_str = random_decimal_string(max_digits: 200)
  ours_a = BigNumber::BigInt.new(a_str)
  ours_b = BigNumber::BigInt.new(b_str)
  stdlib_a = ::BigInt.new(a_str)
  stdlib_b = ::BigInt.new(b_str)

  # If these ever disagree, we have a bug. Stop and fix it.
  raise "add" unless (ours_a + ours_b).to_s == (stdlib_a + stdlib_b).to_s
  raise "mul" unless (ours_a * ours_b).to_s == (stdlib_a * stdlib_b).to_s
  raise "div" unless ours_a // ours_b == ... # etc
end
```

---

## Step 3: Make It Fast

**Goal: Within 2-3x of libgmp for common operations. Faster than libgmp for
single-limb fast paths.**

Performance work is driven by the benchmark, not by a checklist. Measure first.
Fix the slowest thing. Repeat.

Likely wins, roughly in order of impact:

- **Single-limb fast paths**: If both operands fit in one UInt64, skip the
  limb-array machinery entirely. Add is just `a &+ b` with overflow check.
  Multiply is just `UInt128`. This should beat libgmp because we avoid FFI overhead.

- **Karatsuba multiplication**: For numbers above ~30 limbs. Classical algorithm,
  well-documented everywhere. Splits the multiply into three half-sized multiplies.
  ~O(n^1.585) vs O(n^2).

- **Faster base conversion**: `to_s` and `from_s` with divide-and-conquer
  instead of repeated single-limb division.

- **Toom-Cook 3-way**: For numbers above ~100 limbs. Only implement if the
  benchmark says Karatsuba isn't enough for our target sizes.

- **Burnikel-Ziegler division**: Faster division for large operands. Only
  implement if division shows up as a bottleneck.

- **Memory reuse**: Avoid allocating new limb arrays on every operation.
  Consider an explicit `result` parameter pattern for hot loops, or a
  thread-local scratch buffer for intermediate results in multiply/divide.

Things NOT to do:
- Assembly. If Crystal's LLVM backend doesn't generate the instruction we want,
  file a Crystal issue. Don't hand-write asm.
- FFI to GMP "just for the hard parts." Either we're native or we're not.
- Allocator tricks before profiling proves GC is the bottleneck.

---

## Step 4: BigRational

**Goal: Exact rational arithmetic, auto-canonicalized.**

Only start this after BigInt is correct, complete, and reasonably fast.

```crystal
struct BigNumber::BigRational
  @num : BigNumber::BigInt  # numerator (any sign)
  @den : BigNumber::BigInt  # denominator (always > 0)
end
```

Implement: `+`, `-`, `*`, `/`, `<=>`, `abs`, `neg`, `inv`, `to_f64`, `to_s`.
Every mutation canonicalizes (divide num and den by their GCD).

This is ~500 lines. It's just BigInt arithmetic with GCD calls. Don't overthink it.

---

## Step 5: BigFloat (if needed)

Arbitrary-precision floating point. Significantly harder than everything above
because of rounding semantics. Don't start this until someone actually needs it.
It's a separate project in terms of complexity.

---

## File Structure

Start with this. Split files when they get too big to navigate, not before.

```
big_number/
├── shard.yml
├── PLAN.md
├── src/
│   ├── big_number.cr           # require + version
│   └── big_number/
│       ├── big_int.cr          # the whole BigInt implementation
│       └── big_rational.cr     # only after BigInt is done
├── spec/
│   └── big_int_spec.cr         # tests
└── bench/
    └── sanity.cr               # continuous benchmark vs stdlib
```

If `big_int.cr` hits 3,000+ lines and you want to split it, split by what's
actually cohesive in the code, not by a predetermined taxonomy. Maybe the
division algorithm is 400 lines and deserves its own file. Maybe bitwise ops
and shifts are tightly coupled and stay together. Let the code decide.

---

## Testing

One principle: **every operation is fuzz-tested against Crystal's stdlib BigInt
from the moment it's implemented.**

Stdlib BigInt uses libgmp. libgmp is correct. If we disagree with it, we're
wrong. This gives us a perfect oracle for free.

Additional targeted tests:
- Edge cases: zero, one, negative one, `LIMB_MAX`, powers of two, alternating
  bit patterns
- Boundary conditions: operands that are exactly 1, 2, 3 limbs; results that
  gain or lose a limb
- Division: divisor larger than dividend, single-limb divisor, exact division,
  all three rounding modes
- String round-trip: `BigInt.new(x.to_s) == x` for all bases 2-36

---

## What Done Looks Like

1. `BigNumber::BigInt` is a drop-in replacement for `::BigInt` in Crystal programs
2. Zero C dependencies — `crystal build` with no system libraries
3. Within 2-3x of libgmp performance for numbers up to ~1000 limbs
4. Faster than libgmp for single-limb operations (no FFI overhead)
5. Fuzz-tested against libgmp with millions of random inputs
6. `BigNumber::BigRational` works for exact rational arithmetic

That's it. No 10-phase plan. No architecture diagrams. Write the code.
