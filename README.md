# big_number

Pure Crystal arbitrary-precision arithmetic -- zero C dependencies, no FFI, no GMP.

A clean-room implementation of `BigInt`, `BigRational`, and `BigFloat` built entirely in Crystal using well-known algorithms from Knuth and the Handbook of Applied Cryptography.

## Features

**BigInt** -- Arbitrary-precision integers with sign-magnitude representation using 64-bit limbs.

- Full arithmetic: `+`, `-`, `*`, `//`, `%`, `divmod`, `**`
- Adaptive multiplication: schoolbook, Karatsuba (32+ limbs), and Toom-Cook 3-way (90+ limbs)
- Knuth Algorithm D division with single-limb fast paths
- Bitwise operations with two's complement semantics: `&`, `|`, `^`, `~`, `<<`, `>>`
- Number theory: `gcd`, `lcm`, `prime?` (Miller-Rabin), `pow_mod`, `sqrt`, `root(n)`, `factorial`
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

**Standard library extensions** -- Seamless interop with Crystal's built-in numeric types via `to_big_i`, `to_big_f`, `to_big_r`, and mixed-type arithmetic operators.

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
| Schoolbook | Multiplication | O(n*m) | < 32 limbs |
| Karatsuba | Multiplication | O(n^1.585) | 32--90 limbs |
| Toom-Cook 3-way | Multiplication | O(n^1.465) | > 90 limbs |
| Knuth Algorithm D | Division | O(n^2) | All sizes |
| Divide-and-conquer | Base conversion (`to_s`) | O(n*log^2 n) | > 50 limbs |
| Newton's method | `sqrt`, `root(n)` | Quadratic convergence | All sizes |
| Miller-Rabin | Primality testing | Deterministic to 3.3e24 | All sizes |
| Binary exponentiation | `**`, `pow_mod` | O(log exp) | All sizes |
| Euclidean | `gcd` | O(n) | All sizes |

## Benchmarks

The `bench/sanity.cr` benchmark compares against Crystal's stdlib `BigInt` (which wraps libgmp) at various operand sizes:

```
crystal run bench/sanity.cr --release
```

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
