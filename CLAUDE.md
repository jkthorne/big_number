# CLAUDE.md

## Project Overview

Pure Crystal arbitrary-precision arithmetic library — zero C dependencies, no FFI, no GMP. Clean-room implementation of `BigInt`, `BigRational`, `BigFloat`, and `BigDecimal`.

## Commands

```bash
crystal spec                              # Run all tests
crystal spec spec/big_number_spec.cr      # Run BigInt tests
crystal spec spec/big_float_spec.cr       # Run BigFloat tests
crystal spec spec/big_rational_spec.cr    # Run BigRational tests
crystal spec spec/stdlib_smoke_spec.cr    # Run stdlib wrapper tests
crystal spec spec/stdlib_ext_spec.cr      # Run stdlib extensions tests
crystal spec spec/stdlib_json_yaml_spec.cr # Run serialization tests
crystal spec spec/stdlib_compat_spec.cr   # Run full compatibility tests
crystal run bench/sanity.cr --release     # Benchmark vs stdlib BigInt (libgmp)
bench/sanity_bin 2>&1                     # Run precompiled benchmark
```

## Architecture

### Types

- `BigNumber::BigInt` — Arbitrary-precision integers, sign-magnitude with 64-bit limbs
- `BigNumber::BigRational` — Exact rational arithmetic, auto-canonicalized via binary GCD
- `BigNumber::BigFloat` — Arbitrary-precision floating point, configurable precision (default 128 bits)
- `BigNumber::BigDecimal` — Fixed-scale decimal arithmetic (ported from stdlib)

### Key Algorithms

| Algorithm | Operation | Threshold |
|-----------|-----------|-----------|
| Schoolbook | Multiplication | < 32 limbs |
| Karatsuba | Multiplication | 32-89 limbs |
| Toom-Cook 3-way | Multiplication | >= 90 limbs |
| Knuth Algorithm D | Division | All sizes |
| Divide-and-conquer | Base conversion (to_s) | > 50 limbs |
| Binary GCD (Stein's) | GCD | All sizes |
| Newton's method | sqrt, root(n) | All sizes |
| Miller-Rabin | Primality testing | Deterministic to 3.3e24 |

### Source Layout

- `src/big_number.cr` — Main require file + VERSION constant
- `src/big_number/limb.cr` — Type aliases (`Limb = UInt64`, `SignedLimb = Int64`)
- `src/big_number/big_int.cr` — Core BigInt (~2550 lines)
- `src/big_number/big_rational.cr` — Rational arithmetic
- `src/big_number/big_float.cr` — Floating point
- `src/big_number/big_decimal.cr` — Decimal arithmetic
- `src/big_number/ext.cr` — Legacy stdlib type extensions
- `src/big_number/stdlib.cr` — Wrapper structs for stdlib replacement (`BigInt < Int`, etc.)
- `src/big_number/stdlib_ext.cr` — Primitive extensions, Math module, Random, Hasher
- `src/big_number/stdlib_json.cr` — JSON serialization
- `src/big_number/stdlib_yaml.cr` — YAML deserialization

### Stdlib Replacement

Complete drop-in stdlib replacement via `require "big_number/stdlib"`:
- Wrapper structs: `BigInt < Int`, `BigFloat < Float`, `BigRational < Number`, `BigDecimal < Number`
- Primitive extensions: `Int#to_big_i`, `String#to_big_f`, etc.
- Math module: `isqrt`, `sqrt`, `pw2ceil`
- Random: `rand(BigInt)`, `rand(Range(BigInt, BigInt))`
- Numeric hash equality: `BigInt.new(42).hash == 42.hash`
- JSON/YAML serialization

### Testing Strategy

Tests fuzz-compare every operation against Crystal's stdlib BigInt (libgmp) as an oracle. If we disagree with libgmp, we're wrong.

## Notes

- Requires Crystal >= 1.19.1
- No external dependencies
- See `PLAN.md` for roadmap and `STDLIB_REPLACEMENT_PLAN.md` for stdlib integration plans
