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

## Current Status

Steps 1-2 are done. BigInt, BigRational, and BigFloat all exist, are correct
(fuzz-tested against libgmp), and have full API coverage. Step 3 is partially
done: Karatsuba and Toom-3 are implemented, D&C base conversion exists.

### Where We Stand (Benchmark, March 2025)

```
BigNumber vs stdlib BigInt (libgmp) — Apple Silicon, --release

              Add          Mul          Div          to_s
  1 limb:   1.38x FASTER  1.33x FASTER  1.05x slower  2.63x slower
 10 limbs:  ~even         1.47x slower  2.66x slower  3.36x slower
 30 limbs:  ~even         2.36x slower  2.72x slower  5.45x slower
 50 limbs:  1.24x slower  3.24x slower  2.76x slower  5.38x slower
100 limbs:  1.18x slower  4.83x slower  3.14x slower  5.88x slower
  1k limbs: 1.34x slower  5.58x slower  —             5.89x slower

Memory per operation (100 limbs):
  BigNumber mul: 24.6 kB/op   vs  stdlib: 2.0 kB/op   (12x more)
  BigNumber div:  2.2 kB/op   vs  stdlib: 0.4 kB/op   ( 5x more)
```

**Diagnosis:** Add is competitive. Everything else has two problems:

1. **Allocation overhead.** Every operation allocates a new result. Internal
   helpers (Toom-3 interpolation, pow_mod, gcd, prime?) allocate temporaries
   in loops. At 100 limbs, our multiply allocates 24.6 kB/op vs GMP's 2.0 kB.
   The GC isn't free. The allocations aren't free. The copies aren't free.

2. **Algorithm constants.** Toom-3 is doing too much work per recursion level
   (extra allocations in eval/interpolation, size-tracking complexity, temp
   buffers inside hot functions). Division uses only Knuth Algorithm D — fine
   for small divisors, but Burnikel-Ziegler would help at 100+ limbs.
   to_s D&C has overhead we haven't profiled yet.

The target is **2-3x of libgmp across the board**. We're there for add and
small multiply. We need to close the gap on mul (especially 100+ limbs),
div, and to_s.

---

## Step 3 (continued): Make It Fast

Work items in priority order. Each one gets benchmarked before and after.
If it doesn't move the numbers, revert it.

### 3a. Reduce allocation pressure in hot paths

This is the single biggest win available. The low-level `limbs_*` functions
already operate on pre-allocated buffers. The problem is every public method
wraps results in new heap allocations, and compound operations (pow_mod, gcd,
prime?, factorial, root, sqrt) chain those allocations in loops.

**Concrete changes:**

1. **Cache small constants.** `BigInt.new(0)`, `BigInt.new(1)`, `BigInt.new(2)`,
   `BigInt.new(3)` are constructed over and over — in prime?, pow_mod, comparisons,
   everywhere. Create class-level constants (`ZERO`, `ONE`, `TWO`, `THREE`) and
   return those from the constructor when the value matches. These are effectively
   immutable since BigInt operations return new instances.

2. **Rewrite pow_mod to use pre-allocated scratch.** Current code does
   `result = (result * base) % mod` in a loop — that's 3 allocations per bit
   of the exponent (multiply result, mod result, new base). Instead: allocate
   result, base, and a tmp buffer up front, and do the multiply+mod in-place.
   Also: stop comparing against `BigInt.new(0)` and `BigInt.new(1)` every
   iteration — use `zero?` and check `abs_size == 1 && limbs[0] == 1`.

3. **Rewrite prime? to stop allocating.** It creates `BigInt.new(1)`,
   `BigInt.new(2)`, `BigInt.new(3)`, `self - BigInt.new(1)` repeatedly.
   Compute `self_minus_1` once. Use the cached constants. Use `pow_mod`
   (which we just fixed).

4. **Rewrite `**` (exponentiation) with a pre-allocated accumulator.**
   Current: `result = result * base` and `base = base * base` in a loop.
   Each iteration creates two new BigInts and orphans two old ones.

5. **Rewrite factorial with in-place multiply.** Current code does
   `result = result * BigInt.new(i)` — two allocations per iteration.
   Use `limbs_mul_1` directly into a growing buffer. Factorial of a single
   limb value doesn't need BigInt wrapping for the multiplier.

6. **Rewrite gcd to avoid allocating the remainder.** Current code does
   `a, b = b, a % b` — allocates a new BigInt for `a % b` each iteration.
   See also 3d below (binary GCD eliminates division entirely).

7. **Rewrite sqrt/root Newton loops.** Each iteration does division,
   addition, and shift, each allocating. Pre-allocate scratch.

**Expected impact:** 2-4x improvement on compound operations (prime?, pow_mod,
factorial). Modest improvement on single-operation benchmarks because the
per-operation allocation cost is a smaller fraction of total work.

### 3b. Fix Toom-3 allocation blowup

At 100 limbs, mul allocates 24.6 kB/op. At 1000 limbs, 336 kB/op. Most of
this is Toom-3. The current implementation allocates inside the hot path:

- `toom3_eval_at2` calls `Pointer(Limb).malloc` twice (for 2*a1 and 4*a2 temps)
- `toom3_interpolate` allocates two `maxn`-sized temp buffers plus a `tmp8`
  buffer for 8*winf
- Each recursive call through `toom3_mul_recurse` re-dispatches and may allocate
  its own scratch

**Concrete changes:**

1. **Move all Toom-3 temporaries into the scratch buffer.** The scratch buffer
   is already allocated at the top-level `limbs_mul` call with
   `toom3_scratch_size(an)` space. eval_at2's temp buffers, interpolation's
   c2/t/tmp8 buffers — all of these should be carved out of scratch, not
   heap-allocated. This requires laying out the scratch buffer explicitly:

   ```
   scratch layout for toom3:
   [w0 | w1 | wm1 | w2 | winf | ea | eb | interp_c2 | interp_t | interp_tmp8 | recursive_scratch]
   ```

   Increase `toom3_scratch_size` to cover the interpolation temps.

2. **Simplify interpolation by using fixed-size buffers.** Stop tracking
   individual sizes during the 6-step interpolation sequence. All coefficient
   buffers are at most `2*k+4` limbs. Zero-initialize them to that size, do the
   arithmetic, trim sizes only at the end before recomposition. This eliminates
   all the `c3n = Math.max(c3n, tn) if tn > c3n` guards and the associated
   bugs (which required 5 commits to fix). A few extra zero-limb operations
   cost nothing compared to the recursive multiplies.

3. **Remove the symbol-dispatch in bitwise ops.** The `case op when :and`
   check per limb in a loop is unnecessary branching. Inline the loop body
   into `&`, `|`, `^` directly. Factor out the two's complement
   conversion/reconversion (that's the shared part), not the operation.

**Expected impact:** 2-3x reduction in memory per multiply operation at 100+
limbs. Marginal speed improvement from eliminating malloc/GC overhead in the
recursive calls.

### 3c. Fix `to_f64` precision for large numbers

Current `to_f64` accumulates all limbs into a Float64 via a loop:
```crystal
result = result * (UInt64::MAX.to_f64 + 1.0) + @limbs[i].to_f64
```

For numbers with more than 2 limbs (~128 bits), the lower limbs get rounded
away during accumulation but the intermediate multiplies also lose precision.
The correct approach: extract the top 2 limbs (128 bits of magnitude),
construct the float from those using the proper exponent, round correctly.
This is what GMP does. It's ~15 lines.

### 3d. Binary GCD (Stein's algorithm)

Current GCD is Euclidean: `a, b = b, a % b`. Each iteration does a full
BigInt division. Binary GCD uses only shifts and subtractions:

```
while b != 0:
  if a < b: swap a, b
  a -= b
  if a == 0: break
  a >>= trailing_zeros(a)
```

Plus an initial `k = min(trailing_zeros(a), trailing_zeros(b))` extraction
and a final `result <<= k`.

For medium numbers (10-100 limbs) this is faster because subtraction is O(n)
vs division which is O(n*m). For very large numbers (1000+ limbs), Lehmer's
half-GCD would be better, but binary GCD is the easy win and it's ~40 lines.

This directly speeds up every BigRational operation since canonicalization
calls GCD.

**Expected impact:** 2-3x faster GCD for numbers in the 10-100 limb range.

### 3e. Single-limb `to_s` fast path

At 1 limb, our `to_s` is 2.63x slower than libgmp despite having no FFI.
The overhead is the chunked extraction machinery plus `String.build` plus
the `IO` abstraction. For a number that fits in a UInt64, we should just call
Crystal's built-in integer-to-string conversion and prepend a minus sign if
needed. That's one method call vs the whole `simple_to_s` pipeline.

### 3f. Burnikel-Ziegler division (stretch goal)

Division is 2.7-3.1x slower across all sizes. Knuth Algorithm D is O(n*m)
and there's not much fat to trim in the implementation. Burnikel-Ziegler
is a divide-and-conquer division that reduces large divisions to multiplications
(which we've already optimized). It helps when the divisor is large (100+
limbs). For small divisors, Algorithm D is already fine.

Only implement this if, after 3a-3e, division is still the bottleneck. The
algorithm is well-documented but fiddly to get right.

### 3g. Profile and fix `to_s` D&C overhead

At 100+ limbs, to_s is nearly 6x slower. The D&C base conversion should be
O(n*log²n) vs schoolbook O(n²), so the algorithm is right. The constant factor
is probably allocation: we're creating BigInts for the power table, doing
`tdiv_rem` which allocates quotient and remainder, and recursing. Profile it.
The power table should be computed once and reused. The recursive splits
should work on raw limb arrays where possible.

---

## Step 4: Stdlib Integration

See `STDLIB_REPLACEMENT_PLAN.md` for the full phase breakdown. Don't start
this until Step 3 is done and we're within 2-3x of libgmp on all benchmarks.

Summary:
- Phase 4: Port BigDecimal (uses BigInt internally, no GMP calls)
- Phase 5: Wrapper structs (`BigInt < Int`, `BigFloat < Float`, etc.)
- Phase 6: Primitive type extensions (Int#to_big_i, etc.)
- Phase 7: JSON/YAML serialization
- Phase 8: Compatibility tests

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

---

## File Structure

```
big_number/
├── shard.yml
├── PLAN.md
├── CLAUDE.md
├── STDLIB_REPLACEMENT_PLAN.md
├── src/
│   ├── big_number.cr              # require + version
│   └── big_number/
│       ├── limb.cr                # type aliases
│       ├── big_int.cr             # BigInt (~2450 lines)
│       ├── big_float.cr           # BigFloat (~945 lines)
│       ├── big_rational.cr        # BigRational (~470 lines)
│       └── ext.cr                 # stdlib type extensions
├── spec/
│   ├── spec_helper.cr
│   ├── big_number_spec.cr         # BigInt tests (327+ tests)
│   ├── big_float_spec.cr          # BigFloat tests
│   └── big_rational_spec.cr       # BigRational tests
└── bench/
    └── sanity.cr                  # continuous benchmark vs stdlib
```

If `big_int.cr` hits 3,000+ lines, split by what's cohesive: multiplication
algorithms are ~600 lines and could be their own file. Let the code decide.

---

## Testing

**Every operation is fuzz-tested against Crystal's stdlib BigInt (libgmp).**

libgmp is correct. If we disagree with it, we're wrong. This gives us a
perfect oracle for free. Current suite: 327+ BigInt tests, 120+ BigFloat
tests, 50+ BigRational tests, with 1000+ random pairs per operation.

Additional targeted tests:
- Edge cases: zero, one, negative one, `LIMB_MAX`, powers of two
- Boundary conditions: operands at exact algorithm thresholds (32, 90 limbs)
- Division: divisor larger than dividend, single-limb divisor, exact division
- String round-trip: `BigInt.new(x.to_s) == x` for all bases 2-36

---

## What Done Looks Like

1. `BigNumber::BigInt` is a drop-in replacement for `::BigInt` in Crystal programs
2. Zero C dependencies — `crystal build` with no system libraries
3. Within 2-3x of libgmp performance for numbers up to ~1000 limbs
4. Faster than libgmp for single-limb operations (no FFI overhead)
5. Fuzz-tested against libgmp with millions of random inputs
6. `BigNumber::BigRational` works for exact rational arithmetic
7. `BigNumber::BigFloat` works for arbitrary-precision floating point

We're at (1), (2), (4 for add/mul), (5), (6), and (7). The remaining gap
is (3): we're 3-6x slower on mul/div/to_s at 100+ limbs. Step 3a-3g
closes that gap. Then Step 4 makes it a real stdlib replacement.
