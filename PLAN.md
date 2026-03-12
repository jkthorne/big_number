# BigNumber

Pure Crystal arbitrary-precision arithmetic. No C, no FFI, no GMP.

## What This Is

A clean-room replacement for Crystal's `require "big"` that compiles with zero
system library dependencies. Four types — `BigInt`, `BigRational`, `BigFloat`,
`BigDecimal` — all fuzz-tested against libgmp, with a drop-in stdlib wrapper.

7,408 lines of implementation. 740 tests. All passing.

## Design

### Representation

```crystal
struct BigNumber::BigInt
  @limbs : Pointer(UInt64)  # least-significant first
  @alloc : Int32            # capacity (limbs)
  @size  : Int32            # used limbs; negative = negative number; 0 = zero
end
```

Sign-magnitude. UInt64 limbs. Crystal's `UInt128` for widening multiply.
LLVM intrinsics for CLZ/CTZ. ARM64 inline assembly where it matters.

### Algorithm Selection

| Operation | Small | Medium | Large |
|-----------|-------|--------|-------|
| **Multiply** | Schoolbook (< 48 limbs) | Karatsuba (48–24,999) | NTT Goldilocks (>= 25,000) |
| **Divide** | Knuth Algorithm D (< 80) | Burnikel-Ziegler (>= 80) | — |
| **to_s** | Native UInt64 (1 limb) | Chunked extraction (2–50) | D&C with cached powers (> 50) |
| **GCD** | Binary GCD (Stein's) | — | — |
| **sqrt/root** | Newton's method | — | — |
| **pow_mod** | Square-and-multiply (small/even mod) | Montgomery REDC (odd, >= 2 limbs) | — |
| **Primality** | Deterministic Miller-Rabin (to 3.3 x 10^24) | — | — |

Toom-Cook 3-way is implemented but effectively disabled (threshold 10,000) —
Karatsuba uniformly wins at practical sizes due to Toom-3's evaluation/interpolation
overhead.

### Platform Optimizations

ARM64 inline assembly for the six hot inner-loop functions:

| Function | Instructions/limb | vs UInt128 fallback |
|----------|-------------------|---------------------|
| `limbs_add` | 1-2 (`adds`/`adc`) | ~1.5x faster |
| `limbs_sub` | 2-3 (`subs`/`cset`/`cinc`) | ~1.5x faster |
| `limbs_add_1` | 1-2 (`adds`/`adc`) | ~1.4x faster |
| `limbs_mul_1` | ~4 (`mul`/`umulh`/`adds`/`adc`) | ~1.4x faster |
| `limbs_addmul_1` | ~6 | ~1.6x faster |
| `limbs_submul_1` | ~6 | ~1.4x faster |

Dispatch: `{% if flag?(:aarch64) %}` with UInt128 fallback for x86-64 and others.

## Performance vs libgmp

Apple Silicon, `--release`. Ratio > 1 means slower than GMP.

```
              Add       Mul       Div       to_s
  1 limb:    0.77x     0.77x     0.98x     1.95x
 10 limbs:   0.98x     1.35x     2.54x     3.36x
 30 limbs:   1.07x     1.74x     2.47x     5.62x
 50 limbs:   1.12x     2.62x     2.36x     5.16x
100 limbs:   1.09x     2.62x     2.62x     5.37x
  1k limbs:  1.18x     3.21x      —        4.58x

BigRational:  ~1.1x add, ~1.2x mul, fastest div (all sizes)
```

**Where we win:** Single-limb arithmetic (no FFI overhead), addition at all
sizes, BigRational division.

**Where GMP wins:** Multiplication above ~30 limbs (hand-tuned asm with loop
unrolling), base conversion (bottlenecked by division), division above ~10 limbs.

## Source Layout

```
src/
├── big_number.cr                  # require + VERSION (10 lines)
└── big_number/
    ├── limb.cr                    # Limb/SignedLimb aliases, LimbArena (31 lines)
    ├── big_int.cr                 # BigInt core (3,249 lines)
    ├── big_rational.cr            # BigRational (474 lines)
    ├── big_float.cr               # BigFloat (945 lines)
    ├── big_decimal.cr             # BigDecimal (592 lines)
    ├── ext.cr                     # Legacy stdlib type extensions (202 lines)
    ├── stdlib.cr                  # Drop-in wrapper structs (1,323 lines)
    ├── stdlib_ext.cr              # Primitive extensions, Math, Random (464 lines)
    ├── stdlib_json.cr             # JSON serialization (92 lines)
    └── stdlib_yaml.cr             # YAML deserialization (26 lines)

spec/
├── big_number_spec.cr             # BigInt (327 examples)
├── big_float_spec.cr              # BigFloat (108 examples)
├── big_rational_spec.cr           # BigRational (83 examples)
├── stdlib_smoke_spec.cr           # Wrapper structs (41 examples)
├── stdlib_ext_spec.cr             # Extensions (69 examples)
├── stdlib_json_yaml_spec.cr       # Serialization (32 examples)
└── stdlib_compat_spec.cr          # Full compatibility (271 examples)

bench/
└── sanity.cr                      # Benchmark vs libgmp
```

## Testing

```bash
crystal spec                                                    # 327 core tests
crystal spec -D big_number_stdlib spec/stdlib_*_spec.cr         # 413 stdlib tests
```

The two sets cannot compile together — the stdlib wrapper redefines `::BigDecimal`.

Every arithmetic operation is fuzz-tested against Crystal's stdlib BigInt (libgmp)
as a correctness oracle. 1,000+ random input pairs per operation. Additional
targeted coverage:

- Edge values: zero, one, -1, `LIMB_MAX`, powers of two
- Algorithm boundaries: operands at exact threshold sizes (48, 80, 25000 limbs)
- Division edge cases: divisor > dividend, single-limb divisor, exact division
- String round-trips: `BigInt.new(x.to_s(base), base) == x` for bases 2–36
- Stdlib compatibility: type hierarchy, cross-type arithmetic, hash equality
- Serialization: JSON/YAML round-trips, object key support

## Clean-Room Policy

This is a clean-room implementation of well-known algorithms from textbooks.
We do not read, copy, or translate GMP or mini-gmp source code.

**References** (algorithms only):
- Knuth, *The Art of Computer Programming*, Vol 2
- *Handbook of Applied Cryptography*, Chapter 14
- GMP manual (algorithm descriptions, not source)
- Wikipedia: Karatsuba, Toom-Cook, Burnikel-Ziegler, NTT, Montgomery

## Development History

1. **Core arithmetic** — BigInt with full operator set, string conversion,
   number theory (`gcd`, `prime?`, `pow_mod`, `sqrt`, `factorial`)
2. **Additional types** — BigRational (binary GCD), BigFloat (Newton's method),
   BigDecimal (ported from stdlib)
3. **Performance** — allocation reduction, threshold tuning (Karatsuba 48,
   Toom-3 disabled), D&C `to_s` with cached powers, branch-free inner loops
4. **Stdlib drop-in** — wrapper structs, primitive extensions, Math/Random,
   numeric hash equality, JSON/YAML serialization
5. **Advanced optimizations** — ARM64 inline asm (6 functions, 1.4–1.6x each),
   LimbArena for Burnikel-Ziegler, Montgomery REDC, NTT multiplication

## Future Work

### Performance — Closing the GMP Gap

| Area | Current gap | Approach | Expected impact |
|------|-------------|----------|-----------------|
| **Mul (large)** | 2.6–3.2x | x86-64 inline asm + 4x loop unrolling | ~1.5x improvement |
| **Div (large)** | 2.4–2.6x | x86-64 asm for `submul_1`/`addmul_1` | ~1.3x improvement |
| **to_s** | 3.4–5.6x | Subquadratic base conversion (scaled remainder trees) | ~2x improvement |
| **NTT** | Untested vs GMP | Goldilocks mulmod fast path (no u128 division) | Better constant factor |

### Features

- **x86-64 inline assembly** — `mul`/`adc`/`sbb` equivalents of the ARM64 paths
- **Barrett reduction** — for repeated modular reduction with same modulus
- **Shard publication** — publish to shards.info for public consumption
