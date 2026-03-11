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
(fuzz-tested against libgmp), and have full API coverage. Step 3 is in progress:
Karatsuba and Toom-3 are implemented, D&C base conversion exists, and the first
round of optimization (3a-3e) is complete.

### Where We Stand (Benchmark, March 2025)

```
BigNumber vs stdlib BigInt (libgmp) — Apple Silicon, --release

              Add          Mul          Div          to_s
  1 limb:   1.32x FASTER  1.35x FASTER  1.05x slower  1.83x slower
 10 limbs:  1.04x FASTER  1.51x slower  2.68x slower  3.53x slower
 30 limbs:  1.11x slower  2.53x slower  2.73x slower  5.48x slower
 50 limbs:  1.27x slower  3.38x slower  2.71x slower  5.57x slower
100 limbs:  1.28x slower  5.53x slower  3.22x slower  5.89x slower
  1k limbs: 1.34x slower  4.76x slower  —             5.86x slower

Memory per operation (1000 limbs):
  BigNumber mul: 204 kB/op   vs  stdlib: 15.4 kB/op   (13x more)
```

BigRational (pure Crystal, no stdlib comparison available in benchmark):
```
                ~5 digits    ~50 digits    ~200 digits
  add:         1.11x slower  1.12x slower   1.12x slower
  mul:         1.16x slower  1.14x slower   1.14x slower
  div:         fastest       fastest        fastest
```

---

## Step 3: Make It Fast — Completed Items

### 3a. Reduce allocation pressure in hot paths — DONE

- `pow_mod`: iterates exponent bits directly via `bit()` instead of
  allocating/shifting a BigInt copy each iteration
- `prime?`: pre-computes `self_minus_1` and `two` once, uses allocation-free
  small-number checks, avoids `BigInt.new(1)` comparisons in inner loop
- `factorial`: uses `result * i` (Int fast path with `limbs_mul_1`) instead
  of `result * BigInt.new(i)` — one allocation per iteration instead of two
- `divmod`: uses `q - 1` instead of `q - BigInt.new(1)`
- `~` (NOT): uses `self.abs - 1` instead of `self.abs - BigInt.new(1)`
- `>>` for negatives: uses `result - 1` instead of `result - BigInt.new(1)`
- `<=>(Int)`: compares directly against the integer's magnitude without
  allocating a temporary BigInt
- `==(Int)`: compares limbs directly without allocation

### 3b. Fix Toom-3 allocation blowup — DONE (partial)

Moved heap allocations in `toom3_eval_at2` (2 temp buffers) and
`toom3_interpolate` (c2, t, tmp8 buffers) into the pre-allocated scratch
buffer. Updated scratch layout:

```
[w0 | w1 | wm1 | w2 | winf | ea | eb | interp_c2 | interp_t | interp_tmp | recursive_scratch]
```

Increased `toom3_scratch_size` from `20n+512` to `24n+512` to cover the
additional carved-out regions.

**Result:** 1000-limb mul memory dropped from 336 kB/op to 204 kB/op (39%
reduction). Speed improved from 5.58x slower to 4.76x slower (15%).

**Still TODO:** Simplify interpolation to use fixed-size buffers instead of
tracking individual sizes (eliminates the `Math.max(c3n, tn)` guards). This
is a correctness-hardening change, not a performance change.

### 3c. Fix `to_f64` precision for large numbers — DONE

Now uses top 2 limbs with proper exponent scaling (`2.0 ** ((n-2)*64)`)
instead of accumulating all limbs through a Float64. Correct rounding for
any number of limbs.

### 3d. Binary GCD (Stein's algorithm) — DONE

Replaced Euclidean GCD (division per iteration) with binary GCD using only
shifts and subtractions. ~20 lines. Directly sped up all BigRational
operations since canonicalization calls GCD.

**Result:** BigRational operations improved from 1.26-1.39x slower to
1.11-1.16x slower (near parity with stdlib).

### 3e. Single-limb `to_s` fast path — DONE

For 1-limb numbers, uses Crystal's built-in `UInt64.to_s(base)` instead of
the chunked extraction pipeline.

**Result:** 1-limb to_s improved from 2.63x slower to 1.83x slower (32%
faster).

---

## Step 3: Make It Fast — Remaining Items

The target is **2-3x of libgmp across the board**. Current status:

- **Add:** 1.04-1.34x — DONE (within target at all sizes)
- **Mul:** 1.51-5.53x — needs work above 30 limbs
- **Div:** 2.68-3.22x — borderline, could use improvement at 10+ limbs
- **to_s:** 1.83-5.89x — needs work above 10 limbs

### 3f. Reduce Toom-3 constant factor

At 100 limbs, multiply is 5.53x slower and allocates 24.6 kB/op vs GMP's
2.0 kB/op. The scratch buffer consolidation (3b) helped at 1000 limbs but
the 100-limb range is still dominated by per-recursion overhead.

**Possible approaches:**

1. **Toom-3 threshold tuning.** Current threshold is 90 limbs. It may be
   that Karatsuba is actually faster than our Toom-3 up to ~150 limbs due
   to the evaluation/interpolation overhead. Try bumping TOOM3_THRESHOLD to
   120-150 and benchmark.

2. **Reduce Karatsuba allocation.** At 30-50 limbs (pure Karatsuba range),
   we're 2.4-3.4x slower. The Karatsuba implementation allocates scratch on
   each top-level call. Check if the scratch is being reused properly through
   recursive calls. The `limbs_mul_karatsuba` scratch layout could be tighter.

3. **Schoolbook threshold tuning.** The crossover from schoolbook to Karatsuba
   is at 32 limbs. This may not be optimal — profile at 20, 24, 28, 32, 36,
   40 to find the real crossover.

### 3g. Burnikel-Ziegler division

Division is 2.7-3.2x slower across all sizes above 10 limbs. Knuth
Algorithm D is O(n*m) and the implementation is clean — there's not much fat
to trim. Burnikel-Ziegler is a divide-and-conquer division that reduces large
divisions to multiplications.

Implement if, after threshold tuning (3f), division is still >3x slower at
100+ limbs. The algorithm is well-documented but fiddly.

### 3h. Profile and fix `to_s` D&C overhead

At 30+ limbs, to_s is 5-6x slower. The D&C base conversion is O(n*log²n)
vs schoolbook O(n²), so the algorithm is right. The constant factor is
probably:

1. **Power table allocation.** `precompute_base_powers` creates an Array of
   BigInts via repeated squaring. Each squaring allocates a new BigInt. The
   table could be computed once and cached for a given base.

2. **Recursive split allocation.** `dc_to_s_recurse` calls `tdiv_rem` which
   allocates quotient and remainder BigInts on every split. For the recursion
   to be efficient, these should work on raw limb arrays.

3. **Digit buffer overhead.** The `est_digits` calculation over-estimates,
   and the buffer is zero-filled, then written right-to-left, then scanned
   for leading zeros. This is fine for correctness but may have cache effects.

Profile first. The power table caching is likely the biggest win since
`base^(chunk*2^i)` for base 10 is reusable across all to_s calls.

### 3i. Lehmer's GCD (stretch goal)

Binary GCD is O(n²) for large numbers (each subtraction is O(n), and there
are O(n*64) iterations). For numbers above ~500 limbs, Lehmer's GCD or
half-GCD would give O(n*log²n). Only implement if GCD shows up as a
bottleneck in profiling (e.g., BigRational with very large numerators).

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
│       ├── big_int.cr             # BigInt (~2500 lines)
│       ├── big_float.cr           # BigFloat (~945 lines)
│       ├── big_rational.cr        # BigRational (~470 lines)
│       └── ext.cr                 # stdlib type extensions
├── spec/
│   ├── spec_helper.cr
│   ├── big_number_spec.cr         # BigInt tests (136 examples)
│   ├── big_float_spec.cr          # BigFloat tests (108 examples)
│   └── big_rational_spec.cr       # BigRational tests (83 examples)
└── bench/
    └── sanity.cr                  # continuous benchmark vs stdlib
```

If `big_int.cr` hits 3,000+ lines, split by what's cohesive: multiplication
algorithms are ~600 lines and could be their own file. Let the code decide.

---

## Testing

**Every operation is fuzz-tested against Crystal's stdlib BigInt (libgmp).**

libgmp is correct. If we disagree with it, we're wrong. This gives us a
perfect oracle for free. Current suite: 136 BigInt tests, 108 BigFloat
tests, 83 BigRational tests, with 1000+ random pairs per operation.

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

We have (1), (2), (4) for add/mul, (5), (6), and (7). The remaining gap is
(3): mul is 2.5-5.5x slower above 30 limbs, div is ~3x slower, and to_s is
~5.5x slower. Items 3f-3h target closing those gaps. Add and BigRational are
essentially at parity.
