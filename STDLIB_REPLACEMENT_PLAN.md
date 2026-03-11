# Strategy A: Stdlib Drop-In Replacement Plan

Replace `require "big"` with `require "big_number/stdlib"` to eliminate GMP/libgmp.

## The Problem

Crystal's `require "big"` pulls in `@[Link("gmp")]` via `lib_gmp.cr`. Even if you
never call a GMP function, the linker requires libgmp installed. We provide a pure
Crystal alternative that needs zero native dependencies.

## The Approach: Wrapper Structs with Inheritance

Simple `alias BigInt = BigNumber::BigInt` won't work because stdlib has
`BigInt < Int`, `BigFloat < Float`, `BigRational < Number`. Without proper
inheritance, `is_a?(Int)` fails and hundreds of inherited methods are missing.

Instead: define top-level structs that inherit correctly and delegate to the
`BigNumber::*` inner types. LLVM optimizes away single-field struct wrappers.

## Consumer Usage

```yaml
# shard.yml
dependencies:
  big_number:
    github: jack/big_number
```

```crystal
# Replace:
require "big"
# With:
require "big_number/stdlib"

# Everything works the same — no GMP linked
x = BigInt.new("123456789" * 100)
x.is_a?(Int)  # => true
x * x          # pure Crystal
```

---

## Phase 1: Fill API Gaps in BigNumber::BigInt

File: `src/big_number/big_int.cr`

### Missing methods to add:

- [x] `sign : Int32` — return -1, 0, or 1
- [x] `from_digits(digits : Enumerable(Int), base : Int = 10) : self` — class method
- [x] `<=>(other : Float::Primitive) : Int32?` — return nil for NaN, uses binary float decomposition
- [x] `to_big_f : BigFloat` — conversion to BigNumber::BigFloat
- [x] `to_big_r : BigRational` — conversion to BigNumber::BigRational

### Fixes for stdlib compatibility:

- [x] `to_i128!` / `to_u128!` — now uses `to_i128_internal`/`to_u128_internal` (reads 2 limbs)
- [x] `to_i128_internal` — fixed overflow for Int128::MIN using wrapping subtraction
- [x] `next_power_of_two` — returns 1 for values <= 0 (stdlib behavior)
- [x] `bit_length` — already correct (returns 1 for zero, matching `sizeinbase(2)`)
- [x] STDERR debug output — already removed from `dc_to_s` / `dc_to_s_recurse`

### Methods present but with behavioral differences to audit:

- `clone` — stdlib returns `self` (immutable GMP); ours copies (mutable pointer).
  For the wrapper, `clone` should return self since wrapper is value-type.
- `gcd(other : Int)` — stdlib returns `Int`, ours returns `Int64`. May need widening.
- `factor_by` — verify signature matches stdlib

### Helper added:

- `BigNumber.float_to_bigint(f : Float64) : BigInt` — decomposes IEEE 754 binary
  representation to avoid precision loss in float-to-bigint conversion

---

## Phase 2: Fill API Gaps in BigNumber::BigRational

File: `src/big_number/big_rational.cr`

### Missing methods to add:

- [x] `<=>(other : Float::Primitive) : Int32?` — NaN/infinity handling
- [x] `floor : BigRational`
- [x] `ceil : BigRational`
- [x] `trunc : BigRational`
- [x] `round_away : BigRational`
- [x] `round_even : BigRational`
- [x] `>>(other : Int) : BigRational` — divide by 2^n
- [x] `<<(other : Int) : BigRational` — multiply by 2^n
- [x] `//(other : BigRational) : BigRational` — floored division
- [x] `//(other : Int) : BigRational` — floored division
- [x] `//(other : BigInt) : BigRational` — floored division
- [x] `%(other : BigRational) : BigRational` — floored modulo
- [x] `%(other : Int) : BigRational` — floored modulo
- [x] `%(other : BigInt) : BigRational` — floored modulo
- [x] `tdiv(other : BigRational|Int|BigInt)` — truncated division
- [x] `remainder(other : BigRational|Int|BigInt)` — truncated remainder
- [x] `to_f32 : Float32`, `to_f32!`, `to_f64!`, `to_f!`
- [x] `to_i : Int32` and `to_i8..to_i64`, `to_u8..to_u64` (via to_f64)
- [x] `to_big_i : BigInt` — truncate to integer via tdiv
- [x] `to_big_f : BigFloat` — via BigFloat division
- [x] `to_s(base : Int)` and `to_s(io, base)` — base-N string conversion
- [x] `sign : Int32` — delegates to numerator.sign

---

## Phase 3: Fill API Gaps in BigNumber::BigFloat

File: `src/big_number/big_float.cr`

### Missing methods to add:

- [x] `nan? : Bool` — always false
- [x] `infinite? : Int32?` — always nil
- [x] `integer? : Bool` — checks fractional bits in mantissa
- [x] `round_even : self` — round ties to even
- [x] `round_away : self` — round ties away from zero
- [x] `to_f32 : Float32`, `to_f32!`, `to_f64!`, `to_f!`
- [x] All `to_i*` and `to_u*` methods (checked and unchecked) — via to_big_i delegation
- [x] `sign_i32 : Int32` — added as `sign_i32` to avoid conflict with existing `sign : Int8` getter
- [x] `to_i`, `to_i!`, `to_u`, `to_u!` convenience methods
- [x] `**(other : BigInt)` — binary exponentiation by BigInt

---

## Phase 4: Port BigDecimal

File: `src/big_number/big_decimal.cr` — NEW

Stdlib's `BigDecimal` uses only `BigInt` arithmetic internally — no direct GMP calls.
Port the stdlib implementation, replacing `::BigInt` with `BigNumber::BigInt`.

Source reference: Crystal stdlib `src/big/big_decimal.cr`

Key things to port:
- [x] `BigDecimal` struct with `@value : BigNumber::BigInt` and `@scale : UInt64`
- [x] Arithmetic: `+`, `-`, `*`, `/`
- [x] Comparison with all numeric types
- [x] `to_s`, `to_f64`, `to_big_i`, `to_big_r`, `to_big_f`
- [x] String parsing constructor
- [x] Rounding modes

---

## Phase 5: Create the Bridge — `stdlib.cr` ✅

File: `src/big_number/stdlib.cr` — DONE

- [x] Forward declarations (`BigInt < Int`, `BigFloat < Float`, `BigRational < Number`, `BigDecimal < Number`)
- [x] `BigInt` wrapper — full delegation of all constructors, arithmetic, bitwise, number theory, conversion, serialization
- [x] `BigFloat` wrapper — full delegation including precision management, rounding, arithmetic with all types
- [x] `BigRational` wrapper — full delegation including floor/ceil/trunc, shifts, cross-type arithmetic
- [x] `BigDecimal` wrapper — full delegation including scaling, division with precision
- [x] `Number.expand_div` for cross-type division (Big×Big and Big×Primitive)
- [x] `InvalidBigDecimalException` re-exported at top level
- [x] `clone` returns `self` (wrapper is value-type)
- [x] `hash` delegates to inner type
- [x] All 41 smoke tests pass + existing 327 tests unaffected

### Abstract methods required by parent classes:

**`Int` requires:**
- `self.zero : self`
- `self.new(value)` for various types
- Arithmetic operators
- `<=>` with numeric types

**`Float` requires:**
- `nan? : Bool`
- `infinite? : Int32?`
- Various arithmetic

**`Number` requires:**
- `<=>` with self
- Arithmetic operators

### Key design notes:

- Forward declarations at top of file (like stdlib's `big.cr` does)
- LLVM should optimize away the single-field wrapper struct
- `to_unsafe` is intentionally NOT provided (no GMP pointer exists)
- All conversions between Big types go through the inner representations

---

## Phase 6: Extensions — `stdlib_ext.cr` ✅

File: `src/big_number/stdlib_ext.cr` — DONE

### Primitive type extensions (returning top-level types):

- [x] `Int#to_big_i : BigInt`
- [x] `Int#to_big_f : BigFloat`
- [x] `Int#to_big_r : BigRational`
- [x] `Int#to_big_d : BigDecimal`
- [x] `Float#to_big_i : BigInt`
- [x] `Float#to_big_f : BigFloat`
- [x] `Float#to_big_d : BigDecimal`
- [x] `String#to_big_i : BigInt`
- [x] `String#to_big_f : BigFloat`
- [x] `String#to_big_r : BigRational`
- [x] `String#to_big_d : BigDecimal`

### Math module:

- [x] `Math.isqrt(value : BigInt) : BigInt` — integer square root
- [x] `Math.sqrt(value : BigInt) : BigFloat` — via to_big_f + Newton's method
- [x] `Math.sqrt(value : BigFloat) : BigFloat` — Newton's method
- [x] `Math.sqrt(value : BigRational) : BigFloat` — via to_big_f
- [x] `Math.pw2ceil(v : BigInt) : BigInt` — smallest power of 2 >= v

### Random:

- [x] `Random#rand(max : BigInt) : BigInt` — random in [0, max)
- [x] `Random#rand(range : Range(BigInt, BigInt)) : BigInt`

### Hasher (numeric hash equality):

- [x] `Crystal::Hasher.reduce_num(BigInt)` — modular reduction
- [x] `Crystal::Hasher.reduce_num(BigFloat)` — Mersenne prime 2^e rotation
- [x] `Crystal::Hasher.reduce_num(BigRational)` — modular inverse via extended GCD
- [x] `Crystal::Hasher.reduce_num(BigDecimal)` — modular exponentiation for 10^scale
- [x] All wrapper `hash` methods updated to use `hasher.number(self)`

### Arithmetic interop (Int/Float vs Big types):

- [x] `Int#+(other : BigInt)`, `-`, `*`, `%`, `<=>`, `==`, `&+`, `&-`, `&*`, `gcd`, `lcm`
- [x] `Int#+(other : BigRational)`, `-`, `*`, `/`, `<=>`
- [x] `Int#<=>(other : BigFloat)`, `-(other : BigFloat)`, `/(other : BigFloat)`
- [x] `Number#+(other : BigFloat)`, `-`, `*`, `/`, `to_big_f`
- [x] `Float#<=>(other : BigInt|BigFloat|BigRational)` with NaN handling
- [x] `Float#to_big_i`, `to_big_f`, `to_big_r`, `to_big_d`, `fdiv`
- [x] `Number.expand_div` for all primitive Int/Float types × all Big types
- [x] `BigFloat#<=>(other : BigRational)` cross-type comparison

### Tests: `spec/stdlib_ext_spec.cr` — 69 tests, all passing

---

## Phase 7: Serialization ✅

File: `src/big_number/stdlib_json.cr` — DONE
File: `src/big_number/stdlib_yaml.cr` — DONE

Mirror stdlib's `big/json.cr` and `big/yaml.cr`:

- [x] `JSON::Builder#number(BigDecimal)` for decimal output
- [x] `BigInt#to_json`, `BigInt.new(pull : JSON::PullParser)`, `from_json_object_key?`, `to_json_object_key`
- [x] `BigFloat#to_json`, `BigFloat.new(pull : JSON::PullParser)`, `from_json_object_key?`, `to_json_object_key`
- [x] `BigDecimal#to_json`, `BigDecimal.new(pull : JSON::PullParser)`, `from_json_object_key?`, `to_json_object_key`
- [x] `BigInt.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)`
- [x] `BigFloat.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)`
- [x] `BigDecimal.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)`

### Tests: `spec/stdlib_json_yaml_spec.cr` — 32 tests, all passing

---

## Phase 8: Compatibility Tests ✅

File: `spec/stdlib_compat_spec.cr` — DONE

- [x] Type hierarchy: `BigInt < Int`, `BigFloat < Float`, `BigRational < Number`, `BigDecimal < Number`
- [x] `BigInt.new(42).is_a?(Int)` => true
- [x] `BigInt.new(42).is_a?(Number)` => true
- [x] `BigFloat.new(1.5).is_a?(Float)` => true
- [x] `BigRational.new(1, 3).is_a?(Number)` => true
- [x] BigInt: constructors, predicates, arithmetic, comparison, bitwise, number theory, conversions, large numbers
- [x] BigFloat: constructors, predicates, arithmetic, comparison, rounding, conversions
- [x] BigRational: constructors, predicates, arithmetic, comparison, rounding, conversions
- [x] BigDecimal: constructors, predicates, arithmetic, comparison, rounding, conversions
- [x] Cross-type arithmetic (BigInt×BigFloat, BigInt×BigRational, Int×BigInt, Float×BigInt, etc.)
- [x] Cross-type conversions (round-trip: BigInt→BigFloat→BigRational→BigInt)
- [x] Primitive extensions: `to_big_i`, `to_big_f`, `to_big_r`, `to_big_d` on Int, Float, String
- [x] Math.isqrt, Math.sqrt (BigInt, BigFloat, BigRational), Math.pw2ceil
- [x] Random.rand(BigInt), Random.rand(Range(BigInt, BigInt))
- [x] Hash equality: `BigInt.new(42).hash == 42.hash` and cross-type hash consistency
- [x] JSON serialization: round-trip for BigInt, BigFloat, BigDecimal + object keys
- [x] YAML deserialization: BigInt, BigFloat, BigDecimal
- [x] Edge cases: zero, one identity, very large/small numbers, precision preservation
- [x] No GMP dependency: test file compiles and runs without libgmp

### Tests: `spec/stdlib_compat_spec.cr` — 271 tests, all passing

---

## Execution Order

| Step | Phase | File(s) | Depends On |
|------|-------|---------|------------|
| 1    | 1     | `big_int.cr` — add missing methods, fix compat | — |
| 2    | 2     | `big_rational.cr` — add missing methods | — |
| 3    | 3     | `big_float.cr` — add missing methods | — |
| 4    | 4     | `big_decimal.cr` — port from stdlib | Step 1 |
| 5    | 5     | `stdlib.cr` — wrapper structs with inheritance | Steps 1-4 |
| 6    | 6     | `stdlib_ext.cr` — primitive extensions, Math, Random | Step 5 |
| 7    | 7     | `json.cr`, `yaml.cr` — serialization | Step 5 |
| 8    | 8     | `stdlib_compat_spec.cr` — full test suite | Steps 5-7 |

Steps 1-3 can be done in parallel. Step 4 depends only on Step 1.
Steps 5-6 are the core bridge and depend on all prior work.

---

## Known Limitations

- **`to_unsafe : LibGMP::MPZ`** — Cannot provide. No GMP pointer exists.
  C bindings that expect `LibGMP::MPZ` will not work. Document as intentional.
- **Performance** — Within 2-3x of GMP for large numbers. Faster for single-limb
  ops (no FFI overhead). Acceptable trade-off for zero native dependencies.
- **BigDecimal** — Medium port effort. Can defer initially if needed.
- **`primitive_si_ui_check` / `primitive_ui_check` macros** — Stdlib macros reference
  `LibGMP` types. Must redefine using `Int64`/`UInt64` equivalents.

---

## What Done Looks Like

1. `require "big_number/stdlib"` provides `BigInt`, `BigFloat`, `BigRational`, `BigDecimal`
2. All four types inherit correctly (`BigInt < Int`, `BigFloat < Float`, etc.)
3. Zero C dependencies — `crystal build` with no system libraries
4. Every stdlib BigInt/BigFloat/BigRational method works identically
5. `is_a?(Int)`, `is_a?(Number)` checks pass
6. JSON/YAML serialization works
7. Math, Random, Hasher integrations work
8. Full compatibility test suite passes
