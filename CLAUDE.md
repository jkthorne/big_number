# CLAUDE.md

## Project Overview

Pure Crystal arbitrary-precision arithmetic library — zero C dependencies, no FFI, no GMP. Clean-room implementation of `BigInt`, `BigRational`, `BigFloat`, and `BigDecimal`.

## Commands

```bash
crystal spec                          # Run all tests
crystal spec spec/big_number_spec.cr  # Run BigInt tests
crystal spec spec/big_float_spec.cr   # Run BigFloat tests
crystal spec spec/big_rational_spec.cr # Run BigRational tests
crystal run bench/sanity.cr --release # Benchmark vs stdlib BigInt (libgmp)
bench/sanity_bin 2>&1                 # Run precompiled benchmark
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
| Karatsuba | Multiplication | 32-90 limbs |
| Toom-Cook 3-way | Multiplication | > 90 limbs |
| Knuth Algorithm D | Division | All sizes |
| Divide-and-conquer | Base conversion (to_s) | > 50 limbs |
| Newton's method | sqrt, root(n) | All sizes |
| Miller-Rabin | Primality testing | Deterministic to 3.3e24 |

### Source Layout

- `src/big_number.cr` — Main require file + stdlib extensions
- `src/big_number/` — Implementation modules

### Testing Strategy

Tests fuzz-compare every operation against Crystal's stdlib BigInt (libgmp) as an oracle. If we disagree with libgmp, we're wrong.

## Notes

- Requires Crystal >= 1.19.1
- No external dependencies
- See `PLAN.md` for roadmap and `STDLIB_REPLACEMENT_PLAN.md` for stdlib integration plans
