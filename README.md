# big_number

Pure Crystal arbitrary-precision arithmetic -- zero C dependencies, no FFI, no GMP.

A clean-room implementation of `BigInt`, `BigRational`, `BigFloat`, and `BigDecimal` built entirely in Crystal using well-known algorithms from Knuth and the Handbook of Applied Cryptography.

## Features

**BigInt** -- Arbitrary-precision integers with sign-magnitude representation using 64-bit limbs.

- Full arithmetic: `+`, `-`, `*`, `//`, `%`, `divmod`, `**`
- Adaptive multiplication: schoolbook, Karatsuba (48+ limbs), NTT (25,000+ limbs)
- Division: Knuth Algorithm D (small), Burnikel-Ziegler (80+ limbs)
- ARM64 inline assembly for inner loops with UInt128 fallback
- Bitwise operations with two's complement semantics: `&`, `|`, `^`, `~`, `<<`, `>>`
- Number theory: `gcd` (binary), `lcm`, `prime?` (Miller-Rabin), `pow_mod` (Montgomery), `sqrt`, `root(n)`, `factorial`
- Divide-and-conquer base conversion for fast `to_s` on large numbers
- Binary import/export: `to_bytes`, `from_bytes`
- Full set of checked conversions: `to_i8` through `to_u128`, `to_f64`

**BigRational** -- Exact rational arithmetic, auto-canonicalized via GCD.

- Arithmetic: `+`, `-`, `*`, `/`, `**`
- Constructed from integers, floats, strings (`"3/4"`), or BigInt pairs
- Fully comparable with BigRational, BigInt, and Int types

**BigFloat** -- Arbitrary-precision floating point with configurable precision.

- Arithmetic: `+`, `-`, `*`, `/`, `**`
- Rounding: `floor`, `ceil`, `trunc`, `round`
- Constructed from integers, floats, rationals, or strings (`"1.23e-4"`)
- Default precision of 128 bits, configurable per-value or globally

**BigDecimal** -- Fixed-scale decimal arithmetic, ported from Crystal's stdlib.

- Arithmetic: `+`, `-`, `*`, `/`
- Configurable scale for precision control
- Constructed from integers, floats, or strings (`"1.23"`)
- Exact decimal representation (no floating-point rounding)

**Standard library extensions** -- Seamless interop with Crystal's built-in numeric types via `to_big_i`, `to_big_f`, `to_big_r`, `to_big_d`, and mixed-type arithmetic operators.

## Stdlib Drop-In Replacement

You can use `big_number` as a drop-in replacement for Crystal's `require "big"` to eliminate the libgmp/GMP dependency entirely. Just swap one require line:

```crystal
# Replace:
require "big"
# With:
require "big_number/stdlib"

# Everything works the same -- no GMP linked
x = BigInt.new("123456789" * 100)
x.is_a?(Int)  # => true
x * x          # pure Crystal
```

This provides top-level `BigInt`, `BigFloat`, `BigRational`, and `BigDecimal` types that inherit correctly (`BigInt < Int`, `BigFloat < Float`, etc.) so `is_a?` checks, method dispatch, and all stdlib-compatible APIs work as expected.

### What's included

- **Full API compatibility** -- constructors, arithmetic, comparison, bitwise, number theory, conversions, rounding
- **Primitive extensions** -- `42.to_big_i`, `"1.5".to_big_f`, `0.5.to_big_r`, `"1.23".to_big_d`
- **Cross-type arithmetic** -- `Int + BigInt`, `Float <=> BigRational`, `Number / BigDecimal`, etc.
- **Math module** -- `Math.isqrt`, `Math.sqrt`, `Math.pw2ceil` for Big types
- **Random** -- `Random#rand(BigInt)`, `Random#rand(Range(BigInt, BigInt))`
- **Numeric hash equality** -- `BigInt.new(42).hash == 42.hash`
- **JSON/YAML serialization** -- `to_json`, `from_json`, `from_yaml` for BigInt, BigFloat, BigDecimal

```crystal
require "big_number/stdlib"
require "big_number/stdlib_json"  # optional: JSON support
require "big_number/stdlib_yaml"  # optional: YAML support
```

### Limitations

- **`to_unsafe`** is not provided -- there is no GMP pointer. C bindings that expect `LibGMP::MPZ` will not work.
- **Performance** is within 2-3x of GMP for large numbers. Faster for single-limb ops (no FFI overhead).

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  big_number:
    github: jkthorne/big_number
```

Then run `shards install`.

## Usage

```crystal
require "big_number"

# Arbitrary-precision integers
a = BigNumber::BigInt.new("123456789012345678901234567890")
b = BigNumber::BigInt.new(42)
puts a * b

# Rational arithmetic
r = BigNumber::BigRational.new(1, 3) + BigNumber::BigRational.new(1, 6)
puts r  # => 1/2

# Arbitrary-precision floats
f = BigNumber::BigFloat.new("3.14159265358979323846", precision: 256)
puts f * BigNumber::BigFloat.new(2)

# Conversions from standard types
puts 42.to_big_i
puts "99999999999999999999".to_big_i
puts 0.5.to_big_r
```

## Algorithms

| Algorithm | Operation | Complexity | Threshold |
|---|---|---|---|
| Schoolbook | Multiplication | O(n*m) | < 48 limbs |
| Karatsuba | Multiplication | O(n^1.585) | 48--24,999 limbs |
| NTT (Goldilocks prime) | Multiplication | O(n log n) | >= 25,000 limbs |
| Knuth Algorithm D | Division | O(n^2) | < 80 limbs |
| Burnikel-Ziegler | Division | O(n^1.585) | >= 80 limbs |
| Divide-and-conquer | Base conversion (`to_s`) | O(n*log^2 n) | > 50 limbs |
| Newton's method | `sqrt`, `root(n)` | Quadratic convergence | All sizes |
| Miller-Rabin | Primality testing | Deterministic to 3.3e24 | All sizes |
| Montgomery REDC | `pow_mod` (odd moduli) | O(n^2 * log exp) | >= 2 limbs |
| Binary exponentiation | `**`, `pow_mod` | O(log exp) | All sizes |
| Binary GCD (Stein's) | `gcd` | O(n^2) | All sizes |

## Performance

Compared against Crystal's stdlib `BigInt` (which wraps libgmp). Ratios show BigNumber time relative to stdlib -- lower is better, and values under 1.0x mean BigNumber is faster.

> **Last updated:** 2026-03-12 | Crystal 1.19.1 | Apple M-series | `crystal run bench/sanity.cr --release`

### BigInt

| Operation | 1 limb (19 dig) | 10 limbs (190 dig) | 50 limbs (950 dig) | 100 limbs (1.9k dig) | 1000 limbs (19k dig) |
|-----------|:---:|:---:|:---:|:---:|:---:|
| **add** | **0.77x** | **0.98x** | 1.12x | 1.09x | 1.18x |
| **mul** | **0.77x** | 1.35x | 2.62x | 2.62x | 3.21x |
| **div** | **0.98x** | 2.54x | 2.36x | 2.62x | -- |
| **to_s** | 1.95x | 3.36x | 5.16x | 5.37x | 4.58x |

**Key takeaways:**
- Single-limb arithmetic (numbers up to ~19 digits) is **faster than GMP** -- no FFI overhead
- Addition stays within 1.0-1.2x across all sizes (ARM64 inline asm)
- Multiplication within 2-3x up to 100 limbs; NTT kicks in at 25k+ limbs
- Division within 2-3x via Burnikel-Ziegler with arena allocator
- `to_s` base conversion is the widest gap -- limited by division performance

### BigRational

| Operation | 5 digits | 50 digits | 200 digits |
|-----------|:---:|:---:|:---:|
| **add** | 1.10x | 1.10x | 1.09x |
| **mul** | 1.16x | 1.17x | 1.16x |
| **div** | fastest | fastest | fastest |

### Reproducing

```
crystal run bench/sanity.cr --release
```

<!-- BENCH:UPDATE - To refresh these tables, run the benchmark above and update the ratios -->

## Development

```
crystal spec
```

Tests fuzz-compare every operation against Crystal's stdlib BigInt (libgmp) as an oracle. If we disagree with libgmp, we're wrong.

## Contributing

1. Fork it (<https://github.com/jkthorne/big_number/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jack Thorne](https://github.com/jkthorne) - creator and maintainer

## License

MIT
