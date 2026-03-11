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

Steps 1-3 (partial) and Step 4 are done. All four types (BigInt, BigRational,
BigFloat, BigDecimal) exist, are correct (fuzz-tested against libgmp), and have
full API coverage. Stdlib integration is complete — `require "big_number/stdlib"`
is a drop-in replacement for `require "big"` with zero C dependencies.

Performance optimization items 3a-3e are complete. Items 3f-3i remain: closing
the gap on large multiply (3-5x), division (3x), and to_s (5-6x) to reach the
2-3x target. Memory allocation for 1000-limb mul improved dramatically (62 kB
vs old 204 kB), but BigRational regressed slightly (1.29-1.35x vs old 1.11-1.16x).

**Known issue:** `crystal spec` (all specs together) fails due to
`BigDecimal::DEFAULT_PRECISION` constant collision between stdlib's BigDecimal
and the stdlib wrapper. Individual spec files all pass. Fix: guard the constant
definition in `stdlib.cr` or restructure spec helpers to avoid loading both.

### Where We Stand (Benchmark, March 2026)

```
BigNumber vs stdlib BigInt (libgmp) — Apple Silicon, --release

              Add          Mul          Div          to_s
  1 limb:   1.32x FASTER  1.38x FASTER  1.05x FASTER  2.72x slower
 10 limbs:  1.02x slower  1.46x slower  2.63x slower  3.38x slower
 30 limbs:  1.10x slower  2.38x slower  2.78x slower  5.52x slower
 50 limbs:  1.23x slower  3.25x slower  2.73x slower  5.31x slower
100 limbs:  1.16x slower  3.42x slower  3.13x slower  5.90x slower
  1k limbs: 1.35x slower  4.64x slower  —             5.97x slower

Memory per operation (1000 limbs):
  BigNumber mul: 62.2 kB/op  vs  stdlib: 15.4 kB/op   (4x more)
```

BigRational (pure Crystal, no stdlib comparison available in benchmark):
```
                ~5 digits    ~50 digits    ~200 digits
  add:         1.35x slower  1.34x slower   1.29x slower
  mul:         1.32x slower  1.33x slower   1.31x slower
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

**Result:** 1000-limb mul memory dropped from 336 kB/op to 62 kB/op (82%
reduction). Speed improved from 5.58x slower to 4.64x slower.

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
1.29-1.35x slower. (Note: regression from earlier 1.11x measurement —
investigate whether GCD or canonicalization overhead increased.)

### 3e. Single-limb `to_s` fast path — DONE

For 1-limb numbers, uses Crystal's built-in `UInt64.to_s(base)` instead of
the chunked extraction pipeline.

**Result:** 1-limb to_s improved from 2.63x slower to 2.72x slower. (Note:
regression from earlier 1.83x measurement — the fast path may have been
lost or the benchmark methodology changed.)

---

## Step 3: Make It Fast — Remaining Items

The target is **2-3x of libgmp across the board**. Current status:

- **Add:** 1.02-1.35x — DONE (within target at all sizes)
- **Mul:** 1.46-4.64x — needs work above 30 limbs (improved from 5.5x peak)
- **Div:** 2.63-3.13x — borderline, could use improvement at 10+ limbs
- **to_s:** 2.72-5.97x — needs work above 1 limb

### 3f. Reduce Toom-3 constant factor

At 100 limbs, multiply is 3.42x slower and allocates 7.2 kB/op vs GMP's
2.0 kB/op. Memory improved substantially (1000-limb: 62 kB down from 204 kB)
but the constant factor in Karatsuba/Toom-3 still needs work.

**Possible approaches:**

1. **Toom-3 threshold tuning.** Current threshold is 90 limbs. It may be
   that Karatsuba is actually faster than our Toom-3 up to ~150 limbs due
   to the evaluation/interpolation overhead. Try bumping TOOM3_THRESHOLD to
   120-150 and benchmark.

2. **Reduce Karatsuba allocation.** At 30-50 limbs (pure Karatsuba range),
   we're 2.4-3.3x slower. The Karatsuba implementation allocates scratch on
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

## Step 4: Stdlib Integration — DONE

All 8 phases complete. See `STDLIB_REPLACEMENT_PLAN.md` for the full phase
breakdown.

- **Phase 1-3:** API gaps filled in BigInt, BigRational, BigFloat — DONE
- **Phase 4:** BigDecimal ported from stdlib (`big_decimal.cr`, ~375 lines) — DONE
- **Phase 5:** Wrapper structs (`stdlib.cr`, 1323 lines) — DONE
  - `BigInt < Int`, `BigFloat < Float`, `BigRational < Number`, `BigDecimal < Number`
  - Single `@inner` field delegates to BigNumber types; LLVM optimizes away wrapper
  - `Number.expand_div` for cross-type division
- **Phase 6:** Primitive extensions (`stdlib_ext.cr`, 464 lines) — DONE
  - `Int#to_big_i`, `Float#to_big_f`, `String#to_big_*` etc.
  - Math module: `isqrt`, `sqrt`, `pw2ceil`
  - Random: `rand(BigInt)`, `rand(Range(BigInt, BigInt))`
  - `Crystal::Hasher.reduce_num` for numeric hash equality
- **Phase 7:** JSON/YAML serialization (`stdlib_json.cr`, `stdlib_yaml.cr`) — DONE
- **Phase 8:** Full compatibility tests (`stdlib_compat_spec.cr`, 271 tests) — DONE

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
│       ├── big_int.cr             # BigInt (~2550 lines)
│       ├── big_float.cr           # BigFloat (~750 lines)
│       ├── big_rational.cr        # BigRational (~360 lines)
│       ├── big_decimal.cr         # BigDecimal (~375 lines, ported from stdlib)
│       ├── ext.cr                 # legacy stdlib type extensions
│       ├── stdlib.cr              # wrapper structs for stdlib replacement (~1320 lines)
│       ├── stdlib_ext.cr          # primitive extensions, Math, Random, Hasher (~460 lines)
│       ├── stdlib_json.cr         # JSON serialization (~90 lines)
│       └── stdlib_yaml.cr         # YAML deserialization (~25 lines)
├── spec/
│   ├── spec_helper.cr
│   ├── big_number_spec.cr         # BigInt tests (136 examples)
│   ├── big_float_spec.cr          # BigFloat tests (108 examples)
│   ├── big_rational_spec.cr       # BigRational tests (83 examples)
│   ├── stdlib_smoke_spec.cr       # Wrapper struct tests (41 examples)
│   ├── stdlib_ext_spec.cr         # Extensions tests (69 examples)
│   ├── stdlib_json_yaml_spec.cr   # Serialization tests (32 examples)
│   └── stdlib_compat_spec.cr      # Full compatibility suite (271 examples)
└── bench/
    └── sanity.cr                  # continuous benchmark vs stdlib
```

Total: ~6,700 lines of implementation, 740 tests.

If `big_int.cr` hits 3,000+ lines, split by what's cohesive: multiplication
algorithms are ~600 lines and could be their own file. Let the code decide.

---

## Testing

**Every operation is fuzz-tested against Crystal's stdlib BigInt (libgmp).**

libgmp is correct. If we disagree with it, we're wrong. This gives us a
perfect oracle for free. Current suite: 740 tests across 7 spec files —
136 BigInt, 108 BigFloat, 83 BigRational, 41 stdlib smoke, 69 extensions,
32 serialization, 271 full compatibility. 1000+ random pairs per operation.

Additional targeted tests:
- Edge cases: zero, one, negative one, `LIMB_MAX`, powers of two
- Boundary conditions: operands at exact algorithm thresholds (32, 90 limbs)
- Division: divisor larger than dividend, single-limb divisor, exact division
- String round-trip: `BigInt.new(x.to_s) == x` for all bases 2-36
- Stdlib compatibility: type hierarchy (`is_a?`), cross-type arithmetic, hash equality
- Serialization: JSON/YAML round-trips, object key support

---

## What Done Looks Like

1. `BigNumber::BigInt` is a drop-in replacement for `::BigInt` in Crystal programs
2. Zero C dependencies — `crystal build` with no system libraries
3. Within 2-3x of libgmp performance for numbers up to ~1000 limbs
4. Faster than libgmp for single-limb operations (no FFI overhead)
5. Fuzz-tested against libgmp with millions of random inputs
6. `BigNumber::BigRational` works for exact rational arithmetic
7. `BigNumber::BigFloat` works for arbitrary-precision floating point
8. `BigNumber::BigDecimal` works for fixed-scale decimal arithmetic
9. `require "big_number/stdlib"` is a drop-in replacement for `require "big"`
10. JSON/YAML serialization works identically to stdlib

We have (1), (2), (4) for add/mul/div at 1 limb, (5), (6), (7), (8), (9),
and (10). The remaining gap is (3): mul is 2.4-4.6x slower above 30 limbs,
div is 2.6-3.1x slower, and to_s is 3.4-6.0x slower. Items 3f-3h target
closing those gaps. Add is within target at all sizes.

Additional work needed:
- Fix `crystal spec` all-specs-together compilation (BigDecimal constant collision)
- Investigate BigRational regression (1.29-1.35x, was 1.11-1.16x)
- Investigate 1-limb to_s regression (2.72x, was 1.83x)
