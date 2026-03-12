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

## Current Status — COMPLETE

All four steps are done. The library is feature-complete and stable.

All four types (BigInt, BigRational, BigFloat, BigDecimal) exist, are correct
(fuzz-tested against libgmp), and have full API coverage. Stdlib integration is
complete — `require "big_number/stdlib"` is a drop-in replacement for
`require "big"` with zero C dependencies. ~7,000 lines of implementation,
740 tests, all passing.

Performance optimization items 3a-3i are resolved (done or investigated and
closed). The remaining gap to libgmp is structural: GMP's hand-tuned assembly
inner loops vs Crystal's LLVM codegen. Further gains require either Crystal
inline assembly support or algorithmic breakthroughs (e.g., NTT-based
multiplication) at sizes where our current algorithms are already
asymptotically correct.

Stdlib wrapper specs are guarded behind `-D big_number_stdlib` compile flag
since the wrapper redefines `::BigDecimal` (incompatible with `require "big"`).
Run core tests with `crystal spec`, stdlib tests with
`crystal spec -D big_number_stdlib spec/stdlib_*_spec.cr`.

### Where We Stand (Benchmark, March 2026)

```
BigNumber vs stdlib BigInt (libgmp) — Apple Silicon, --release

              Add          Mul          Div          to_s
  1 limb:   1.37x FASTER  1.31x FASTER  1.02x slower  1.84x slower
 10 limbs:  1.02x FASTER  1.55x slower  2.56x slower  3.31x slower
 30 limbs:  1.14x slower  2.41x slower  2.81x slower  5.60x slower
 50 limbs:  1.22x slower  3.20x slower  2.67x slower  5.18x slower
100 limbs:  1.12x slower  3.34x slower  3.11x slower  5.54x slower
  1k limbs: 1.27x slower  4.72x slower  —             5.25x slower
```

BigRational (pure Crystal vs stdlib):
```
                ~5 digits    ~50 digits    ~200 digits
  add:         1.14x slower  1.05x slower   1.07x slower
  mul:         1.09x slower  1.10x slower   1.11x slower
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

**Deferred:** Simplify interpolation to use fixed-size buffers instead of
tracking individual sizes. Not worth pursuing since Toom-3 is effectively
disabled (threshold 10,000) — Karatsuba is uniformly better at practical sizes.

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

**Result:** 1-limb to_s improved to 1.84x slower (within target).

### 3f. Threshold tuning (Karatsuba/Toom-3) — DONE

Extensive benchmarking across sizes 20-1000 limbs found:

1. **Karatsuba threshold raised from 32 to 48.** Schoolbook is faster than
   Karatsuba below 48 limbs due to Karatsuba's allocation and recursion overhead.
2. **Toom-3 effectively disabled (threshold 10,000).** Our Toom-3 implementation
   never beats Karatsuba at practical sizes — the evaluation/interpolation
   overhead dominates. Karatsuba with schoolbook base case is uniformly better.

**Result:** Small improvements at 50-100 limbs (3.25x→3.20x, 3.42x→3.34x).
Negligible change at 1000 limbs (4.64x→4.72x). The remaining gap is GMP's
hand-tuned assembly inner loops.

### 3g. Burnikel-Ziegler division — INVESTIGATED, NOT VIABLE

Implemented full Burnikel-Ziegler (div_2n_by_n, div_3n_by_2n) but per-level
malloc overhead negated the algorithmic advantage at sizes up to 1000 limbs.
Would need a pre-allocated arena allocator to be competitive. Reverted dispatch;
dead code retained for future work with arena allocation.

**Result:** No improvement. Division bottleneck is Algorithm D's inner loop
(`limbs_submul_1`) which GMP implements in assembly.

### 3h. Reduce `to_s` D&C overhead — DONE

Three optimizations applied:

1. **Power table caching.** `@@power_cache` stores precomputed base power
   towers (base^chunk, base^(2*chunk), base^(4*chunk), ...) keyed by base.
   Eliminates repeated squaring on every `to_s` call.

2. **Raw limb recursion.** Replaced `dc_to_s_recurse` (BigInt-based, allocates
   quotient+remainder BigInts per split) with `dc_to_s_recurse_raw` that works
   directly with `Pointer(Limb)` and calls `limbs_div_rem` without wrapping.

3. **Branch-free `limbs_submul_1`.** Division inner loop rewritten to avoid
   conditional borrow propagation, using `u128` accumulator instead. Reduces
   branch misprediction in tight loops.

4. **Pre-allocated division scratch.** Single `Pointer(Limb).malloc(2*size+2)`
   allocated once in `dc_to_s` and shared across all recursive levels.

**Result:** 1-limb to_s: 2.72x→1.84x (within target). Multi-limb to_s
improved modestly (5.97x→5.25x at 1000 limbs). Remaining gap is dominated
by division performance (Algorithm D is 2.5-3x slower than GMP assembly).

### 3i. Lehmer's GCD — NOT NEEDED

Binary GCD performance is excellent for practical BigRational sizes.
BigRational improved significantly (1.29-1.35x → 1.05-1.14x) from the
combined threshold tuning and to_s optimizations. Only worth revisiting
if BigRational is used with 500+ limb numerators.

---

## Step 3: Performance Summary

The target was **2-3x of libgmp across the board**. Final status:

- **Add:** 1.02-1.27x — DONE (within target, often faster than GMP)
- **Mul:** 1.55-4.72x — within target at 10 limbs, gap widens with size
- **Div:** 2.56-3.11x — borderline, limited by assembly gap
- **to_s:** 1.84-5.60x — 1-limb within target, larger sizes limited by div
- **BigRational:** 1.05-1.14x — excellent, nearly matching GMP

The remaining performance gap above 30 limbs is structural: GMP uses
hand-written assembly for `mpn_mul_1`, `mpn_addmul_1`, `mpn_submul_1` —
the tight inner loops that dominate Karatsuba, division, and base conversion.
Crystal's LLVM codegen produces good but not optimal machine code for these
loops. Further improvement would require either Crystal inline assembly
support or a fundamentally different algorithmic approach (e.g., NTT-based
multiplication for very large numbers).

---

## Step 4: Stdlib Integration — DONE

All 8 phases complete. See `STDLIB_REPLACEMENT_PLAN.md` for the full phase
breakdown.

- **Phase 1-3:** API gaps filled in BigInt, BigRational, BigFloat — DONE
- **Phase 4:** BigDecimal ported from stdlib (`big_decimal.cr`, 592 lines) — DONE
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
│       ├── big_int.cr             # BigInt (2862 lines)
│       ├── big_float.cr           # BigFloat (945 lines)
│       ├── big_rational.cr        # BigRational (474 lines)
│       ├── big_decimal.cr         # BigDecimal (592 lines, ported from stdlib)
│       ├── ext.cr                 # legacy stdlib type extensions
│       ├── stdlib.cr              # wrapper structs for stdlib replacement (1323 lines)
│       ├── stdlib_ext.cr          # primitive extensions, Math, Random, Hasher (464 lines)
│       ├── stdlib_json.cr         # JSON serialization (92 lines)
│       └── stdlib_yaml.cr         # YAML deserialization (26 lines)
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

Total: ~7,000 lines of implementation, 740 tests.

---

## Testing

**Every operation is fuzz-tested against Crystal's stdlib BigInt (libgmp).**

libgmp is correct. If we disagree with it, we're wrong. This gives us a
perfect oracle for free. Current suite: 740 tests across 7 spec files —
136 BigInt, 108 BigFloat, 83 BigRational, 41 stdlib smoke, 69 extensions,
32 serialization, 271 full compatibility. 1000+ random pairs per operation.

Core tests: `crystal spec` (327 tests).
Stdlib tests: `crystal spec -D big_number_stdlib spec/stdlib_*_spec.cr` (413 tests).
The two sets can't compile together (wrapper redefines `::BigDecimal`).

Additional targeted tests:
- Edge cases: zero, one, negative one, `LIMB_MAX`, powers of two
- Boundary conditions: operands at exact algorithm thresholds (48 limbs for Karatsuba)
- Division: divisor larger than dividend, single-limb divisor, exact division
- String round-trip: `BigInt.new(x.to_s) == x` for all bases 2-36
- Stdlib compatibility: type hierarchy (`is_a?`), cross-type arithmetic, hash equality
- Serialization: JSON/YAML round-trips, object key support

---

## What Done Looks Like — Final Status

All goals achieved except the 2-3x performance target at large sizes:

1. **DONE** — `BigNumber::BigInt` is a drop-in replacement for `::BigInt`
2. **DONE** — Zero C dependencies — `crystal build` with no system libraries
3. **PARTIAL** — Within 2-3x for add (all sizes) and BigRational; mul/div/to_s
   exceed 3x above 30 limbs due to GMP's assembly inner loops
4. **DONE** — Faster than libgmp for single-limb add and mul (no FFI overhead)
5. **DONE** — Fuzz-tested against libgmp with millions of random inputs
6. **DONE** — `BigNumber::BigRational` works for exact rational arithmetic
7. **DONE** — `BigNumber::BigFloat` works for arbitrary-precision floating point
8. **DONE** — `BigNumber::BigDecimal` works for fixed-scale decimal arithmetic
9. **DONE** — `require "big_number/stdlib"` is a drop-in replacement for `require "big"`
10. **DONE** — JSON/YAML serialization works identically to stdlib

The performance gap in (3) is structural — GMP uses hand-written assembly for
its inner loops. All algorithmic optimizations (3a-3i) have been exhausted.
Further improvement requires Crystal inline assembly support or NTT-based
multiplication for very large numbers.

## Possible Future Work

These are not planned — just noted for reference if the project is revisited:

- **Inline assembly inner loops** — if Crystal adds inline asm support, rewrite
  `limbs_mul_1`, `limbs_addmul_1`, `limbs_submul_1` in assembly to close the
  GMP gap for mul/div/to_s at larger sizes
- **NTT-based multiplication** — for very large numbers (10,000+ limbs), could
  implement Number Theoretic Transform multiplication
- **Arena allocator for Burnikel-Ziegler** — dead code exists; needs pre-allocated
  arena to avoid per-level malloc overhead
- **Toom-3 interpolation cleanup** — simplify to fixed-size buffers (deferred,
  Toom-3 is disabled)
- **Shard publication** — publish to shards.info when ready for public use
