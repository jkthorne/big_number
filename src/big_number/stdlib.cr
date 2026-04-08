# Drop-in replacement for `require "big"` -- zero native dependencies.
#
# Provides top-level `BigInt`, `BigFloat`, `BigRational`, and `BigDecimal`
# that inherit correctly from `Int`, `Float`, and `Number` -- just like
# Crystal's stdlib versions, but backed by pure-Crystal `BigNumber`
# implementations (no GMP/libgmp).
#
# Usage:
#
# ```
# require "big_number/stdlib"
#
# x = BigInt.new("999999999999999999999")
# y = x ** 3
# ```

# Forward declarations (break circular dependencies, same pattern as stdlib big.cr)
struct BigInt < Int
end

struct BigFloat < Float
end

struct BigRational < Number
end

struct BigDecimal < Number
end

require "../big_number"

# Re-export the exception class at top level (stdlib defines it there)
class InvalidBigDecimalException < Exception
  def initialize(big_decimal_str : String, reason : String)
    super("Invalid BigDecimal: #{big_decimal_str} (#{reason})")
  end
end

# Arbitrary-precision integer, drop-in replacement for Crystal's stdlib `BigInt`.
#
# Wraps `BigNumber::BigInt` and inherits from `Int`, providing the same API
# as the GMP-backed stdlib version. All arithmetic, bitwise, comparison, and
# conversion operations are delegated to the pure-Crystal implementation.
#
# ```
# a = BigInt.new("123456789012345678901234567890")
# b = BigInt.new(42)
# a * b # => 5185185018518518513851851851380
# ```
struct BigInt < Int
  include Comparable(Int::Signed)
  include Comparable(Int::Unsigned)
  include Comparable(BigInt)
  include Comparable(Float)

  # :nodoc:
  getter inner : BigNumber::BigInt

  # :nodoc:
  def initialize(@inner : BigNumber::BigInt)
  end

  # Creates a `BigInt` with value zero.
  def initialize
    @inner = BigNumber::BigInt.new
  end

  # Creates a `BigInt` from a string in the given *base* (default 10).
  def initialize(str : String, base : Int32 = 10)
    @inner = BigNumber::BigInt.new(str, base)
  end

  # Creates a `BigInt` from a primitive integer.
  def self.new(num : Int::Primitive) : self
    new(BigNumber::BigInt.new(num))
  end

  # Creates a `BigInt` from a primitive float (truncates).
  def initialize(num : Float::Primitive)
    @inner = BigNumber::BigInt.new(num)
  end

  # Creates a `BigInt` from a `BigFloat` (truncates).
  def self.new(num : BigFloat) : self
    new(num.inner.to_big_i)
  end

  # Creates a `BigInt` from a `BigDecimal` (truncates).
  def self.new(num : BigDecimal) : self
    new(num.inner.to_big_i)
  end

  # Creates a `BigInt` from a `BigRational` (truncates).
  def self.new(num : BigRational) : self
    new(num.inner.to_big_i)
  end

  # Returns *num* (identity).
  def self.new(num : BigInt) : self
    num
  end

  # Creates a `BigInt` from an array of digit values in the given *base*.
  def self.from_digits(digits : Enumerable(Int), base : Int = 10) : self
    new(BigNumber::BigInt.from_digits(digits, base))
  end

  # Creates a `BigInt` from raw bytes in big-endian or little-endian order.
  def self.from_bytes(bytes : Bytes, big_endian : Bool = true) : self
    new(BigNumber::BigInt.from_bytes(bytes, big_endian))
  end

  # --- Predicates & accessors ---

  # Returns `true` if zero.
  # Returns `true` if negative.
  # Returns `true` if positive.
  # Returns `true` if even.
  # Returns `true` if odd.
  # Returns the number of limbs.
  # Returns the number of bits needed to represent the absolute value.
  # Returns the sign as -1, 0, or 1.
  delegate :zero?, :negative?, :positive?, :even?, :odd?, :abs_size, :bit_length, :sign, to: @inner

  # --- Comparison ---

  # Compares with another `BigInt`.
  def <=>(other : BigInt) : Int32
    @inner <=> other.inner
  end

  # Compares with a primitive `Int`.
  def <=>(other : Int) : Int32
    @inner <=> other
  end

  # Compares with a primitive `Float`. Returns `nil` if *other* is NaN.
  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  # Returns `true` if equal to *other*.
  def ==(other : BigInt) : Bool
    @inner == other.inner
  end

  # Returns `true` if equal to *other*.
  def ==(other : Int) : Bool
    @inner == other
  end

  # --- Unary ---

  # Returns the negation.
  def - : BigInt
    BigInt.new(-@inner)
  end

  # Returns the absolute value.
  def abs : BigInt
    BigInt.new(@inner.abs)
  end

  # --- Arithmetic ---

  # Returns the sum.
  def +(other : BigInt) : BigInt
    BigInt.new(@inner + other.inner)
  end

  # Returns the sum.
  def +(other : Int) : BigInt
    BigInt.new(@inner + other)
  end

  # Wrapping addition (same as `+` for `BigInt`).
  def &+(other) : BigInt
    self + other
  end

  # Returns the difference.
  def -(other : BigInt) : BigInt
    BigInt.new(@inner - other.inner)
  end

  # Returns the difference.
  def -(other : Int) : BigInt
    BigInt.new(@inner - other)
  end

  # Wrapping subtraction (same as `-` for `BigInt`).
  def &-(other) : BigInt
    self - other
  end

  # Returns the product.
  def *(other : BigInt) : BigInt
    BigInt.new(@inner * other.inner)
  end

  # Returns the product.
  def *(other : Int) : BigInt
    BigInt.new(@inner * other)
  end

  # Wrapping multiplication (same as `*` for `BigInt`).
  def &*(other) : BigInt
    self * other
  end

  # Cross-type division via Number.expand_div
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational

  # --- Floor division & modulo ---

  # Returns the floor division.
  def //(other : BigInt) : BigInt
    BigInt.new(@inner // other.inner)
  end

  # Returns the floor division.
  def //(other : Int) : BigInt
    BigInt.new(@inner // other)
  end

  # Returns the floored modulo.
  def %(other : BigInt) : BigInt
    BigInt.new(@inner % other.inner)
  end

  # Returns the floored modulo.
  def %(other : Int) : BigInt
    BigInt.new(@inner % other)
  end

  # Returns `{quotient, remainder}` using floored division.
  def divmod(number : BigInt) : {BigInt, BigInt}
    q, r = @inner.divmod(number.inner)
    {BigInt.new(q), BigInt.new(r)}
  end

  # Returns `{quotient, remainder}` using floored division.
  def divmod(number : Int) : {BigInt, BigInt}
    q, r = @inner.divmod(number)
    {BigInt.new(q), BigInt.new(r)}
  end

  # Returns the truncated division (rounds towards zero).
  def tdiv(other : BigInt) : BigInt
    BigInt.new(@inner.tdiv(other.inner))
  end

  # Returns the truncated division (rounds towards zero).
  def tdiv(other : Int) : BigInt
    BigInt.new(@inner.tdiv(other))
  end

  # Returns the truncated remainder (sign matches dividend).
  def remainder(other : BigInt) : BigInt
    BigInt.new(@inner.remainder(other.inner))
  end

  # Returns the truncated remainder (sign matches dividend).
  def remainder(other : Int) : BigInt
    BigInt.new(@inner.remainder(other))
  end

  # --- Unsafe division variants ---

  # Floored division without zero check.
  def unsafe_floored_div(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_floored_div(other.inner))
  end

  # Floored division without zero check.
  def unsafe_floored_div(other : Int) : BigInt
    BigInt.new(@inner.unsafe_floored_div(other))
  end

  # Floored modulo without zero check.
  def unsafe_floored_mod(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_floored_mod(other.inner))
  end

  # Floored modulo without zero check.
  def unsafe_floored_mod(other : Int) : BigInt
    BigInt.new(@inner.unsafe_floored_mod(other))
  end

  # Truncated division without zero check.
  def unsafe_truncated_div(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_truncated_div(other.inner))
  end

  # Truncated division without zero check.
  def unsafe_truncated_div(other : Int) : BigInt
    BigInt.new(@inner.unsafe_truncated_div(other))
  end

  # Truncated modulo without zero check.
  def unsafe_truncated_mod(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_truncated_mod(other.inner))
  end

  # Truncated modulo without zero check.
  def unsafe_truncated_mod(other : Int) : BigInt
    BigInt.new(@inner.unsafe_truncated_mod(other))
  end

  # Returns `{quotient, remainder}` using floored division, without zero check.
  def unsafe_floored_divmod(number : BigInt) : {BigInt, BigInt}
    q, r = @inner.unsafe_floored_divmod(number.inner)
    {BigInt.new(q), BigInt.new(r)}
  end

  # Returns `{quotient, remainder}` using floored division, without zero check.
  def unsafe_floored_divmod(number : Int) : {BigInt, BigInt}
    q, r = @inner.unsafe_floored_divmod(number)
    {BigInt.new(q), BigInt.new(r)}
  end

  # Returns `{quotient, remainder}` using truncated division, without zero check.
  def unsafe_truncated_divmod(number : BigInt) : {BigInt, BigInt}
    q, r = @inner.unsafe_truncated_divmod(number.inner)
    {BigInt.new(q), BigInt.new(r)}
  end

  # Returns `{quotient, remainder}` using truncated division, without zero check.
  def unsafe_truncated_divmod(number : Int) : {BigInt, BigInt}
    q, r = @inner.unsafe_truncated_divmod(number)
    {BigInt.new(q), BigInt.new(r)}
  end

  # --- Exponentiation ---

  # Returns `self` raised to the power *other*.
  def **(other : Int) : BigInt
    BigInt.new(@inner ** other)
  end

  # Returns `self ** exp mod mod` using Montgomery multiplication for odd moduli.
  def pow_mod(exp : BigInt, mod : BigInt) : BigInt
    BigInt.new(@inner.pow_mod(exp.inner, mod.inner))
  end

  # Returns `self ** exp mod mod`.
  def pow_mod(exp : Int, mod : BigInt) : BigInt
    BigInt.new(@inner.pow_mod(exp, mod.inner))
  end

  # Returns `self ** exp mod mod`.
  def pow_mod(exp : BigInt | Int, mod : Int) : BigInt
    e = exp.is_a?(BigInt) ? exp.inner : exp
    BigInt.new(@inner.pow_mod(e, mod))
  end

  # --- Bitwise ---

  # Returns the bitwise NOT (ones' complement).
  def ~ : BigInt
    BigInt.new(~@inner)
  end

  # Returns `self` shifted left by *count* bits.
  def <<(count : Int) : BigInt
    BigInt.new(@inner << count)
  end

  # Returns `self` shifted right by *count* bits.
  def >>(count : Int) : BigInt
    BigInt.new(@inner >> count)
  end

  # Unsafe right shift (same as `>>` for `BigInt`).
  def unsafe_shr(count : Int) : self
    self >> count
  end

  # Returns the bit at *index* (0 or 1).
  def bit(index : Int) : Int32
    @inner.bit(index)
  end

  # Returns the number of set bits (population count).
  # Returns the number of trailing zero bits.
  delegate :popcount, :trailing_zeros_count, to: @inner

  # Returns the bitwise AND.
  def &(other : BigInt) : BigInt
    BigInt.new(@inner & other.inner)
  end

  # Returns the bitwise AND.
  def &(other : Int) : BigInt
    BigInt.new(@inner & other)
  end

  # Returns the bitwise OR.
  def |(other : BigInt) : BigInt
    BigInt.new(@inner | other.inner)
  end

  # Returns the bitwise OR.
  def |(other : Int) : BigInt
    BigInt.new(@inner | other)
  end

  # Returns the bitwise XOR.
  def ^(other : BigInt) : BigInt
    BigInt.new(@inner ^ other.inner)
  end

  # Returns the bitwise XOR.
  def ^(other : Int) : BigInt
    BigInt.new(@inner ^ other)
  end

  # --- Number theory ---

  # Returns the greatest common divisor of `self` and *other*.
  def gcd(other : BigInt) : BigInt
    BigInt.new(@inner.gcd(other.inner))
  end

  # Returns the greatest common divisor of `self` and *other*.
  def gcd(other : Int) : Int
    @inner.gcd(other)
  end

  # Returns the least common multiple of `self` and *other*.
  def lcm(other : BigInt) : BigInt
    BigInt.new(@inner.lcm(other.inner))
  end

  # Returns the least common multiple of `self` and *other*.
  def lcm(other : Int) : BigInt
    BigInt.new(@inner.lcm(other))
  end

  # Returns `self!` (factorial). `self` must be non-negative.
  def factorial : BigInt
    BigInt.new(@inner.factorial)
  end

  # Returns `true` if `self` is evenly divisible by *number*.
  def divisible_by?(number : BigInt) : Bool
    @inner.divisible_by?(number.inner)
  end

  # Returns `true` if `self` is evenly divisible by *number*.
  def divisible_by?(number : Int) : Bool
    @inner.divisible_by?(number)
  end

  # Returns `true` if `self` is a probable prime (deterministic up to 3.3e24).
  delegate :prime?, to: @inner

  # --- Roots & powers ---

  # Returns the integer square root.
  def sqrt : BigInt
    BigInt.new(@inner.sqrt)
  end

  # Returns the integer *n*th root.
  def root(n : Int) : BigInt
    BigInt.new(@inner.root(n))
  end

  # Returns the smallest power of two greater than or equal to `self`.
  def next_power_of_two : BigInt
    BigInt.new(@inner.next_power_of_two)
  end

  # :nodoc:
  def factor_by(number : Int) : {BigInt, UInt64}
    result, count = @inner.factor_by(number)
    {BigInt.new(result), count}
  end

  # --- Conversion ---

  # Delegates integer conversion methods to the inner implementation.
  delegate :to_i, :to_i!, :to_u, :to_u!, to: @inner
  delegate :to_i8, :to_i8!, :to_i16, :to_i16!, :to_i32, :to_i32!, :to_i64, :to_i64!, to: @inner
  delegate :to_u8, :to_u8!, :to_u16, :to_u16!, :to_u32, :to_u32!, :to_u64, :to_u64!, to: @inner
  delegate :to_i128, :to_i128!, :to_u128, :to_u128!, to: @inner
  delegate :to_f, :to_f32, :to_f64, :to_f!, :to_f32!, :to_f64!, to: @inner

  # Returns `self`.
  def to_big_i : BigInt
    self
  end

  # Converts to `BigFloat`.
  def to_big_f : BigFloat
    BigFloat.new(@inner.to_big_f)
  end

  # Converts to `BigRational` (denominator = 1).
  def to_big_r : BigRational
    BigRational.new(@inner.to_big_r)
  end

  # Converts to `BigDecimal` (scale = 0).
  def to_big_d : BigDecimal
    BigDecimal.new(@inner.to_big_d)
  end

  # --- Serialization ---

  # Returns the base-10 string representation.
  def to_s : String
    @inner.to_s
  end

  # Returns the string representation in the given *base*.
  def to_s(base : Int = 10, *, precision : Int = 1, upcase : Bool = false) : String
    @inner.to_s(base, precision: precision, upcase: upcase)
  end

  # Writes the base-10 string representation to *io*.
  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  # Writes the string representation in the given *base* to *io*.
  def to_s(io : IO, base : Int = 10, *, precision : Int = 1, upcase : Bool = false) : Nil
    @inner.to_s(io, base, precision: precision, upcase: upcase)
  end

  # :nodoc:
  def inspect(io : IO) : Nil
    @inner.inspect(io)
  end

  # Returns the big-endian (default) or little-endian byte representation.
  def to_bytes(big_endian : Bool = true) : Bytes
    @inner.to_bytes(big_endian)
  end

  # Returns an array of digit values in the given *base* (least significant first).
  def digits(base : Int = 10) : Array(Int32)
    @inner.digits(base)
  end

  # --- Misc ---

  # Returns `self` (value type, no copy needed).
  def clone : BigInt
    self
  end

  # :nodoc:
  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end
end

# Arbitrary-precision floating point, drop-in replacement for Crystal's stdlib `BigFloat`.
#
# Wraps `BigNumber::BigFloat` and inherits from `Float`. Configurable precision
# (default 128 bits). All operations are delegated to the pure-Crystal implementation.
#
# ```
# f = BigFloat.new("3.14159265358979323846")
# f * 2 # => 6.28318530717958647692
# ```
struct BigFloat < Float
  include Comparable(Int)
  include Comparable(BigFloat)
  include Comparable(Float)

  # :nodoc:
  getter inner : BigNumber::BigFloat

  # :nodoc:
  def initialize(@inner : BigNumber::BigFloat)
  end

  # Creates a `BigFloat` with value zero.
  def initialize
    @inner = BigNumber::BigFloat.new
  end

  # Creates a `BigFloat` from a decimal string.
  def initialize(str : String)
    @inner = BigNumber::BigFloat.new(str)
  end

  # Creates a `BigFloat` from an `Int`.
  def initialize(num : Int)
    @inner = BigNumber::BigFloat.new(num)
  end

  # Creates a `BigFloat` from a `BigInt`.
  def initialize(num : BigInt)
    @inner = BigNumber::BigFloat.new(num.inner)
  end

  # Creates a `BigFloat` from a primitive `Float`.
  def initialize(num : Float::Primitive)
    @inner = BigNumber::BigFloat.new(num)
  end

  # Creates a `BigFloat` from a `BigRational`.
  def initialize(num : BigRational)
    @inner = BigNumber::BigFloat.new(num.inner)
  end

  # Creates a `BigFloat` from another `BigFloat` (copies inner).
  def initialize(num : BigFloat)
    @inner = num.inner
  end

  # Returns *num* (identity).
  def self.new(num : BigFloat) : self
    num
  end

  # Creates a `BigFloat` from a `BigDecimal`.
  def self.new(num : BigDecimal) : self
    new(num.inner.to_big_f)
  end

  # Creates a zero-valued `BigFloat` with the given *precision* in bits.
  def initialize(*, precision : Int32)
    @inner = BigNumber::BigFloat.new(precision: precision)
  end

  # Creates a `BigFloat` from an `Int` with the given *precision* in bits.
  def initialize(num : Int, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(num, precision: precision)
  end

  # Creates a `BigFloat` from a `BigInt` with the given *precision* in bits.
  def initialize(num : BigInt, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(num.inner, precision: precision)
  end

  # Creates a `BigFloat` from a primitive `Float` with the given *precision* in bits.
  def initialize(num : Float::Primitive, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(num, precision: precision)
  end

  # Creates a `BigFloat` from a string with the given *precision* in bits.
  def initialize(str : String, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(str, precision: precision)
  end

  # Returns the current default precision in bits.
  def self.default_precision : Int32
    BigNumber::BigFloat.default_precision
  end

  # Sets the default precision in bits for new `BigFloat` values.
  def self.default_precision=(value : Int32) : Nil
    BigNumber::BigFloat.default_precision = value
  end

  # --- Predicates ---

  # Delegates `zero?`, `positive?`, `negative?`, and `precision`.
  delegate :zero?, :positive?, :negative?, :precision, to: @inner

  # Always returns `false` (`BigFloat` cannot be NaN).
  def nan? : Bool
    false
  end

  # Always returns `nil` (`BigFloat` cannot be infinite).
  def infinite? : Int32?
    nil
  end

  # Returns `true` if the fractional part is zero.
  def integer? : Bool
    @inner.integer?
  end

  # Returns the sign as -1, 0, or 1.
  def sign : Int32
    @inner.sign_i32
  end

  # --- Accessors ---

  # Returns the mantissa as a `BigInt`.
  def mantissa : BigInt
    BigInt.new(@inner.mantissa)
  end

  # Returns the binary exponent.
  delegate :exponent, to: @inner

  # --- Comparison ---

  # Compares with another `BigFloat`.
  def <=>(other : BigFloat) : Int32
    @inner <=> other.inner
  end

  # Compares with a `BigInt`.
  def <=>(other : BigInt) : Int32
    @inner <=> other.inner
  end

  # Compares with a primitive `Float`. Returns `nil` if *other* is NaN.
  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  # Compares with a primitive `Int`.
  def <=>(other : Int) : Int32
    @inner <=> other
  end

  # Returns `true` if equal to *other*.
  def ==(other : BigFloat) : Bool
    @inner == other.inner
  end

  # Returns `true` if equal to *other*.
  def ==(other : BigInt) : Bool
    @inner == other.inner
  end

  # Returns `true` if equal to *other*.
  def ==(other : Int) : Bool
    @inner == other
  end

  # Returns `true` if equal to *other*.
  def ==(other : Float) : Bool
    @inner == other
  end

  # --- Unary ---

  # Returns the negation.
  def - : BigFloat
    BigFloat.new(-@inner)
  end

  # Returns the absolute value.
  def abs : BigFloat
    BigFloat.new(@inner.abs)
  end

  # --- Arithmetic ---

  # Returns the sum.
  def +(other : BigFloat) : BigFloat
    BigFloat.new(@inner + other.inner)
  end

  # Returns the sum.
  def +(other : BigInt) : BigFloat
    BigFloat.new(@inner + other.inner)
  end

  # Returns the sum.
  def +(other : Int) : BigFloat
    BigFloat.new(@inner + other)
  end

  # Returns the sum.
  def +(other : Float) : BigFloat
    BigFloat.new(@inner + other)
  end

  # Returns the difference.
  def -(other : BigFloat) : BigFloat
    BigFloat.new(@inner - other.inner)
  end

  # Returns the difference.
  def -(other : BigInt) : BigFloat
    BigFloat.new(@inner - other.inner)
  end

  # Returns the difference.
  def -(other : Int) : BigFloat
    BigFloat.new(@inner - other)
  end

  # Returns the difference.
  def -(other : Float) : BigFloat
    BigFloat.new(@inner - other)
  end

  # Returns the product.
  def *(other : BigFloat) : BigFloat
    BigFloat.new(@inner * other.inner)
  end

  # Returns the product.
  def *(other : BigInt) : BigFloat
    BigFloat.new(@inner * other.inner)
  end

  # Returns the product.
  def *(other : Int) : BigFloat
    BigFloat.new(@inner * other)
  end

  # Returns the product.
  def *(other : Float) : BigFloat
    BigFloat.new(@inner * other)
  end

  # Returns the quotient.
  def /(other : BigFloat) : BigFloat
    BigFloat.new(@inner / other.inner)
  end

  # Returns the quotient.
  def /(other : BigInt) : BigFloat
    BigFloat.new(@inner / other.inner)
  end

  # Returns the quotient.
  def /(other : Int) : BigFloat
    BigFloat.new(@inner / other)
  end

  # Returns the quotient.
  def /(other : Float) : BigFloat
    BigFloat.new(@inner / other)
  end

  # Cross-type division
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational

  # --- Exponentiation ---

  # Returns `self` raised to the power *other*.
  def **(other : Int) : BigFloat
    BigFloat.new(@inner ** other)
  end

  # Returns `self` raised to the power *other*.
  def **(other : BigInt) : BigFloat
    BigFloat.new(@inner ** other.inner)
  end

  # --- Rounding ---

  # Rounds towards positive infinity.
  def ceil : BigFloat
    BigFloat.new(@inner.ceil)
  end

  # Rounds towards negative infinity.
  def floor : BigFloat
    BigFloat.new(@inner.floor)
  end

  # Rounds towards zero.
  def trunc : BigFloat
    BigFloat.new(@inner.trunc)
  end

  # Rounds to nearest, ties to even.
  def round_even : BigFloat
    BigFloat.new(@inner.round_even)
  end

  # Rounds to nearest, ties away from zero.
  def round_away : BigFloat
    BigFloat.new(@inner.round_away)
  end

  # --- Conversion ---

  # Delegates float/int conversion methods to the inner implementation.
  delegate :to_f64, :to_f32, :to_f, :to_f32!, :to_f64!, :to_f!, to: @inner
  delegate :to_i, :to_i!, :to_u, :to_u!, to: @inner
  delegate :to_i8, :to_i8!, :to_i16, :to_i16!, :to_i32, :to_i32!, :to_i64, :to_i64!, to: @inner
  delegate :to_u8, :to_u8!, :to_u16, :to_u16!, :to_u32, :to_u32!, :to_u64, :to_u64!, to: @inner

  # Returns `self`.
  def to_big_f : BigFloat
    self
  end

  # Converts to `BigInt` (truncates).
  def to_big_i : BigInt
    BigInt.new(@inner.to_big_i)
  end

  # Converts to `BigRational`.
  def to_big_r : BigRational
    BigRational.new(@inner.to_big_r)
  end

  # --- Serialization ---

  # Returns the string representation.
  def to_s : String
    @inner.to_s
  end

  # Writes the string representation to *io*.
  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  # :nodoc:
  def inspect(io : IO) : Nil
    @inner.inspect(io)
  end

  # --- Misc ---

  # Returns `self` (value type, no copy needed).
  def clone : BigFloat
    self
  end

  # :nodoc:
  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end

  # Returns `self / other` as `BigFloat`.
  def fdiv(other : Number::Primitive) : self
    self.class.new(self / other)
  end
end

# Exact rational arithmetic, drop-in replacement for Crystal's stdlib `BigRational`.
#
# Wraps `BigNumber::BigRational` and inherits from `Number`. Automatically
# canonicalized (reduced to lowest terms) via binary GCD.
#
# ```
# r = BigRational.new(1, 3) + BigRational.new(1, 6)
# r # => 1/2
# ```
struct BigRational < Number
  include Comparable(BigRational)
  include Comparable(Int)
  include Comparable(Float)

  # :nodoc:
  getter inner : BigNumber::BigRational

  # :nodoc:
  def initialize(@inner : BigNumber::BigRational)
  end

  # Creates a `BigRational` from *numerator* and *denominator* `BigInt` values.
  def initialize(numerator : BigInt, denominator : BigInt)
    @inner = BigNumber::BigRational.new(numerator.inner, denominator.inner)
  end

  # Creates a `BigRational` from *numerator* and *denominator* integers.
  def initialize(numerator : Int, denominator : Int)
    num = numerator.is_a?(BigInt) ? numerator.inner : BigNumber::BigInt.new(numerator)
    den = denominator.is_a?(BigInt) ? denominator.inner : BigNumber::BigInt.new(denominator)
    @inner = BigNumber::BigRational.new(num, den)
  end

  # Creates a `BigRational` from a `BigInt` (denominator = 1).
  def initialize(num : BigInt)
    @inner = BigNumber::BigRational.new(num.inner)
  end

  # Creates a `BigRational` from an `Int` (denominator = 1).
  def initialize(num : Int)
    @inner = BigNumber::BigRational.new(num)
  end

  # Creates a `BigRational` from a primitive `Float`.
  def self.new(num : Float::Primitive) : self
    new(BigNumber::BigRational.new(num))
  end

  # Creates a `BigRational` from a `BigFloat`.
  def self.new(num : BigFloat) : self
    new(num.inner.to_big_r)
  end

  # Returns *num* (identity).
  def self.new(num : BigRational) : self
    num
  end

  # Creates a `BigRational` from a `BigDecimal`.
  def self.new(num : BigDecimal) : self
    new(num.inner.to_big_r)
  end

  # Creates a `BigRational` from a string of the form `"numerator/denominator"` or a decimal.
  def initialize(str : String)
    @inner = BigNumber::BigRational.new(str)
  end

  # --- Accessors ---

  # Returns the numerator as a `BigInt`.
  def numerator : BigInt
    BigInt.new(@inner.numerator)
  end

  # Returns the denominator as a `BigInt`.
  def denominator : BigInt
    BigInt.new(@inner.denominator)
  end

  # --- Predicates ---

  # Delegates `zero?`, `positive?`, `negative?`, and `sign`.
  delegate :zero?, :positive?, :negative?, :sign, to: @inner

  # Returns `true` if the denominator is 1.
  def integer? : Bool
    @inner.integer?
  end

  # --- Comparison ---

  # Compares with another `BigRational`.
  def <=>(other : BigRational) : Int32
    @inner <=> other.inner
  end

  # Compares with a primitive `Float`. Returns `nil` if *other* is NaN.
  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  # Compares with a `BigFloat`.
  def <=>(other : BigFloat) : Int32
    # Convert BigFloat to BigRational for comparison
    @inner <=> other.inner.to_big_r
  end

  # Compares with a `BigInt`.
  def <=>(other : BigInt) : Int32
    @inner <=> other.inner
  end

  # Compares with a primitive `Int`.
  def <=>(other : Int) : Int32
    @inner <=> other
  end

  # Returns `true` if equal to *other*.
  def ==(other : BigRational) : Bool
    @inner == other.inner
  end

  # Returns `true` if equal to *other*.
  def ==(other : Int) : Bool
    @inner == other
  end

  # Returns `true` if equal to *other*.
  def ==(other : BigInt) : Bool
    @inner == other.inner
  end

  # --- Unary ---

  # Returns the negation.
  def - : BigRational
    BigRational.new(-@inner)
  end

  # Returns the absolute value.
  def abs : BigRational
    BigRational.new(@inner.abs)
  end

  # Returns the multiplicative inverse (reciprocal).
  def inv : BigRational
    BigRational.new(@inner.inv)
  end

  # --- Arithmetic ---

  # Returns the sum.
  def +(other : BigRational) : BigRational
    BigRational.new(@inner + other.inner)
  end

  # Returns the sum.
  def +(other : BigInt) : BigRational
    BigRational.new(@inner + other.inner)
  end

  # Returns the sum.
  def +(other : Int) : BigRational
    BigRational.new(@inner + other)
  end

  # Returns the difference.
  def -(other : BigRational) : BigRational
    BigRational.new(@inner - other.inner)
  end

  # Returns the difference.
  def -(other : BigInt) : BigRational
    BigRational.new(@inner - other.inner)
  end

  # Returns the difference.
  def -(other : Int) : BigRational
    BigRational.new(@inner - other)
  end

  # Returns the product.
  def *(other : BigRational) : BigRational
    BigRational.new(@inner * other.inner)
  end

  # Returns the product.
  def *(other : BigInt) : BigRational
    BigRational.new(@inner * other.inner)
  end

  # Returns the product.
  def *(other : Int) : BigRational
    BigRational.new(@inner * other)
  end

  # Returns the quotient.
  def /(other : BigRational) : BigRational
    BigRational.new(@inner / other.inner)
  end

  # Cross-type division
  Number.expand_div [BigInt, BigFloat, BigDecimal], BigRational

  # --- Floor division & modulo ---

  # Returns the floor division.
  def //(other : BigRational) : BigRational
    BigRational.new(@inner // other.inner)
  end

  # Returns the floor division.
  def //(other : BigInt) : BigRational
    BigRational.new(@inner // other.inner)
  end

  # Returns the floor division.
  def //(other : Int) : BigRational
    BigRational.new(@inner // other)
  end

  # Returns the floored modulo.
  def %(other : BigRational) : BigRational
    BigRational.new(@inner % other.inner)
  end

  # Returns the floored modulo.
  def %(other : BigInt) : BigRational
    BigRational.new(@inner % other.inner)
  end

  # Returns the floored modulo.
  def %(other : Int) : BigRational
    BigRational.new(@inner % other)
  end

  # Returns the truncated division.
  def tdiv(other : BigRational) : BigRational
    BigRational.new(@inner.tdiv(other.inner))
  end

  # Returns the truncated division.
  def tdiv(other : BigInt) : BigRational
    BigRational.new(@inner.tdiv(other.inner))
  end

  # Returns the truncated division.
  def tdiv(other : Int) : BigRational
    BigRational.new(@inner.tdiv(other))
  end

  # Returns the truncated remainder.
  def remainder(other : BigRational) : BigRational
    BigRational.new(@inner.remainder(other.inner))
  end

  # Returns the truncated remainder.
  def remainder(other : BigInt) : BigRational
    BigRational.new(@inner.remainder(other.inner))
  end

  # Returns the truncated remainder.
  def remainder(other : Int) : BigRational
    BigRational.new(@inner.remainder(other))
  end

  # --- Exponentiation ---

  # Returns `self` raised to the power *other*.
  def **(other : Int) : BigRational
    BigRational.new(@inner ** other)
  end

  # --- Shifts ---

  # Returns `self / 2^other` (right shift).
  def >>(other : Int) : BigRational
    BigRational.new(@inner >> other)
  end

  # Returns `self * 2^other` (left shift).
  def <<(other : Int) : BigRational
    BigRational.new(@inner << other)
  end

  # --- Rounding ---

  # Rounds towards positive infinity.
  def ceil : BigRational
    BigRational.new(@inner.ceil)
  end

  # Rounds towards negative infinity.
  def floor : BigRational
    BigRational.new(@inner.floor)
  end

  # Rounds towards zero.
  def trunc : BigRational
    BigRational.new(@inner.trunc)
  end

  # Rounds to nearest, ties away from zero.
  def round_away : BigRational
    BigRational.new(@inner.round_away)
  end

  # Rounds to nearest, ties to even.
  def round_even : BigRational
    BigRational.new(@inner.round_even)
  end

  # --- Conversion ---

  # Delegates float/int conversion methods to the inner implementation.
  delegate :to_f, :to_f32, :to_f64, :to_f!, :to_f32!, :to_f64!, to: @inner
  delegate :to_i, :to_i8, :to_i16, :to_i32, :to_i64, to: @inner
  delegate :to_u8, :to_u16, :to_u32, :to_u64, to: @inner

  # Returns `self`.
  def to_big_r : BigRational
    self
  end

  # Converts to `BigInt` (truncates).
  def to_big_i : BigInt
    BigInt.new(@inner.to_big_i)
  end

  # Converts to `BigFloat`.
  def to_big_f : BigFloat
    BigFloat.new(@inner.to_big_f)
  end

  # Converts to `BigDecimal`.
  def to_big_d : BigDecimal
    BigDecimal.new(@inner.to_big_d)
  end

  # --- Serialization ---

  # Returns the string representation as `"numerator/denominator"`.
  def to_s : String
    @inner.to_s
  end

  # Returns the string representation in the given *base*.
  def to_s(base : Int = 10) : String
    @inner.to_s(base)
  end

  # Writes the string representation to *io*.
  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  # Writes the string representation in the given *base* to *io*.
  def to_s(io : IO, base : Int) : Nil
    @inner.to_s(io, base)
  end

  # :nodoc:
  def inspect : String
    to_s
  end

  # :nodoc:
  def inspect(io : IO) : Nil
    to_s(io)
  end

  # --- Misc ---

  # Returns `self` (value type, no copy needed).
  def clone : BigRational
    self
  end

  # :nodoc:
  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end
end

# Fixed-scale decimal arithmetic, drop-in replacement for Crystal's stdlib `BigDecimal`.
#
# Wraps `BigNumber::BigDecimal` and inherits from `Number`. Represented as
# an unscaled `BigInt` value and a `UInt64` scale.
#
# ```
# d = BigDecimal.new("0.1") + BigDecimal.new("0.2")
# d == BigDecimal.new("0.3") # => true (no floating-point error)
# ```
struct BigDecimal < Number
  include Comparable(Int)
  include Comparable(Float)
  include Comparable(BigRational)
  include Comparable(BigDecimal)

  # Default precision (number of decimal digits) used for division.
  DEFAULT_PRECISION = 100_u64

  # :nodoc:
  getter inner : BigNumber::BigDecimal

  # :nodoc:
  def initialize(@inner : BigNumber::BigDecimal)
  end

  # Creates a `BigDecimal` from a `BigInt` value and `UInt64` scale.
  def initialize(value : BigInt, scale : UInt64)
    @inner = BigNumber::BigDecimal.new(value.inner, scale)
  end

  # Creates a `BigDecimal` from an `Int` with an optional scale.
  def initialize(num : Int = 0, scale : Int = 0)
    @inner = BigNumber::BigDecimal.new(num, scale)
  end

  # Creates a `BigDecimal` from a `BigInt` with an optional scale.
  def initialize(num : BigInt, scale : Int = 0)
    @inner = BigNumber::BigDecimal.new(num.inner, scale)
  end

  # Creates a `BigDecimal` from a decimal string.
  def initialize(str : String)
    @inner = BigNumber::BigDecimal.new(str)
  end

  # Creates a `BigDecimal` from a `Float`.
  def self.new(num : Float) : self
    raise ArgumentError.new "Can only construct from a finite number" unless num.finite?
    new(num.to_s)
  end

  # Creates a `BigDecimal` from a `BigRational`.
  def self.new(num : BigRational) : self
    new(num.inner.to_big_d)
  end

  # Returns *num* (identity).
  def self.new(num : BigDecimal) : self
    num
  end

  # --- Accessors ---

  # Returns the unscaled `BigInt` value.
  def value : BigInt
    BigInt.new(@inner.value)
  end

  # Returns the scale.
  delegate :scale, to: @inner

  # --- Predicates ---

  # Delegates `zero?`, `positive?`, `negative?`, `sign`, and `integer?`.
  delegate :zero?, :positive?, :negative?, :sign, :integer?, to: @inner

  # --- Comparison ---

  # Compares with another `BigDecimal`.
  def <=>(other : BigDecimal) : Int32
    @inner <=> other.inner
  end

  # Compares with a `BigRational`.
  def <=>(other : BigRational) : Int32
    @inner <=> other.inner
  end

  # Compares with a primitive `Float`. Returns `nil` if *other* is NaN.
  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  # Compares with a primitive `Int`.
  def <=>(other : Int) : Int32
    @inner <=> other
  end

  # Returns `true` if equal to *other*.
  def ==(other : BigDecimal) : Bool
    @inner == other.inner
  end

  # --- Unary ---

  # Returns the negation.
  def - : BigDecimal
    BigDecimal.new(-@inner)
  end

  # --- Arithmetic ---

  # Returns the sum.
  def +(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner + other.inner)
  end

  # Returns the sum.
  def +(other : BigInt) : BigDecimal
    BigDecimal.new(@inner + other.inner)
  end

  # Returns the sum.
  def +(other : Int) : BigDecimal
    BigDecimal.new(@inner + other)
  end

  # Returns the difference.
  def -(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner - other.inner)
  end

  # Returns the difference.
  def -(other : BigInt) : BigDecimal
    BigDecimal.new(@inner - other.inner)
  end

  # Returns the difference.
  def -(other : Int) : BigDecimal
    BigDecimal.new(@inner - other)
  end

  # Returns the product.
  def *(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner * other.inner)
  end

  # Returns the product.
  def *(other : BigInt) : BigDecimal
    BigDecimal.new(@inner * other.inner)
  end

  # Returns the product.
  def *(other : Int) : BigDecimal
    BigDecimal.new(@inner * other)
  end

  # Returns the remainder.
  def %(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner % other.inner)
  end

  # Returns the remainder.
  def %(other : Int) : BigDecimal
    BigDecimal.new(@inner % other)
  end

  # Returns the quotient using `DEFAULT_PRECISION`.
  def /(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner / other.inner)
  end

  # Returns the quotient.
  def /(other : BigInt) : BigDecimal
    BigDecimal.new(@inner / other.inner)
  end

  # Returns the quotient.
  def /(other : Int) : BigDecimal
    BigDecimal.new(@inner / other)
  end

  # Divides with explicit decimal digit *precision*.
  def div(other : BigDecimal, precision : Int = DEFAULT_PRECISION) : BigDecimal
    BigDecimal.new(@inner.div(other.inner, precision))
  end

  # --- Exponentiation ---

  # Returns `self` raised to the power *other*.
  def **(other : Int) : BigDecimal
    BigDecimal.new(@inner ** other)
  end

  # --- Rounding ---

  # Rounds towards positive infinity.
  def ceil : BigDecimal
    BigDecimal.new(@inner.ceil)
  end

  # Rounds towards negative infinity.
  def floor : BigDecimal
    BigDecimal.new(@inner.floor)
  end

  # Rounds towards zero.
  def trunc : BigDecimal
    BigDecimal.new(@inner.trunc)
  end

  # Rounds to nearest, ties to even.
  def round_even : BigDecimal
    BigDecimal.new(@inner.round_even)
  end

  # Rounds to nearest, ties away from zero.
  def round_away : BigDecimal
    BigDecimal.new(@inner.round_away)
  end

  # --- Scaling ---

  # Returns a new `BigDecimal` scaled to match *new_scale*'s scale.
  def scale_to(new_scale : BigDecimal) : BigDecimal
    BigDecimal.new(@inner.scale_to(new_scale.inner))
  end

  # --- Conversion ---

  # Delegates float/int conversion methods to the inner implementation.
  delegate :to_f64, :to_f32, :to_f, :to_f!, :to_f32!, :to_f64!, to: @inner
  delegate :to_i, :to_i!, :to_u, :to_u!, to: @inner
  delegate :to_i8, :to_i8!, :to_i16, :to_i16!, :to_i32, :to_i32!, :to_i64, :to_i64!, to: @inner
  delegate :to_u8, :to_u8!, :to_u16, :to_u16!, :to_u32, :to_u32!, :to_u64, :to_u64!, to: @inner

  # Returns `self`.
  def to_big_d : BigDecimal
    self
  end

  # Converts to `BigInt` (truncates).
  def to_big_i : BigInt
    BigInt.new(@inner.to_big_i)
  end

  # Converts to `BigFloat`.
  def to_big_f : BigFloat
    BigFloat.new(@inner.to_big_f)
  end

  # Converts to `BigRational`.
  def to_big_r : BigRational
    BigRational.new(@inner.to_big_r)
  end

  # --- Serialization ---

  # Returns the string representation.
  def to_s : String
    @inner.to_s
  end

  # Writes the string representation to *io*.
  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  # :nodoc:
  def inspect : String
    @inner.inspect
  end

  # :nodoc:
  def inspect(io : IO) : Nil
    @inner.inspect(io)
  end

  # --- Misc ---

  # Returns `self` (value type, no copy needed).
  def clone : BigDecimal
    self
  end

  # :nodoc:
  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end
end

# ==========================================================================
# Number.expand_div for primitive types (enables Int / BigInt -> BigFloat etc.)
# ==========================================================================
struct BigInt
  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], BigFloat
  Number.expand_div [Float32, Float64], BigFloat
end

struct BigFloat
  Number.expand_div [Float32, Float64], BigFloat
end

struct BigDecimal
  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], BigDecimal
  Number.expand_div [Float32, Float64], BigDecimal
end

struct BigRational
  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], BigRational
  Number.expand_div [Float32, Float64], BigRational
end

# Allow BigNumber::BigInt.new to accept the stdlib wrapper BigInt.
module BigNumber
  struct BigInt
    def initialize(wrapper : ::BigInt)
      initialize(wrapper.inner)
    end
  end
end

require "./stdlib_ext"
