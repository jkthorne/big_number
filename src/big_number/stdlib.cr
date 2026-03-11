# Drop-in replacement for `require "big"` — zero native dependencies.
#
# Usage:
#   require "big_number/stdlib"
#
# Provides top-level BigInt, BigFloat, BigRational, BigDecimal that inherit
# correctly from Int, Float, Number — just like Crystal's stdlib versions,
# but backed by pure-Crystal BigNumber implementations (no GMP/libgmp).

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

# ==========================================================================
# BigInt — wraps BigNumber::BigInt, inherits from Int
# ==========================================================================
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

  def initialize
    @inner = BigNumber::BigInt.new
  end

  def initialize(str : String, base : Int32 = 10)
    @inner = BigNumber::BigInt.new(str, base)
  end

  def self.new(num : Int::Primitive) : self
    new(BigNumber::BigInt.new(num))
  end

  def initialize(num : Float::Primitive)
    @inner = BigNumber::BigInt.new(num)
  end

  def self.new(num : BigFloat) : self
    new(num.inner.to_big_i)
  end

  def self.new(num : BigDecimal) : self
    new(num.inner.to_big_i)
  end

  def self.new(num : BigRational) : self
    new(num.inner.to_big_i)
  end

  def self.new(num : BigInt) : self
    num
  end

  def self.from_digits(digits : Enumerable(Int), base : Int = 10) : self
    new(BigNumber::BigInt.from_digits(digits, base))
  end

  def self.from_bytes(bytes : Bytes, big_endian : Bool = true) : self
    new(BigNumber::BigInt.from_bytes(bytes, big_endian))
  end

  # --- Predicates & accessors ---

  delegate :zero?, :negative?, :positive?, :even?, :odd?, :abs_size, :bit_length, :sign, to: @inner

  # --- Comparison ---

  def <=>(other : BigInt) : Int32
    @inner <=> other.inner
  end

  def <=>(other : Int) : Int32
    @inner <=> other
  end

  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  def ==(other : BigInt) : Bool
    @inner == other.inner
  end

  def ==(other : Int) : Bool
    @inner == other
  end

  # --- Unary ---

  def - : BigInt
    BigInt.new(-@inner)
  end

  def abs : BigInt
    BigInt.new(@inner.abs)
  end

  # --- Arithmetic ---

  def +(other : BigInt) : BigInt
    BigInt.new(@inner + other.inner)
  end

  def +(other : Int) : BigInt
    BigInt.new(@inner + other)
  end

  def &+(other) : BigInt
    self + other
  end

  def -(other : BigInt) : BigInt
    BigInt.new(@inner - other.inner)
  end

  def -(other : Int) : BigInt
    BigInt.new(@inner - other)
  end

  def &-(other) : BigInt
    self - other
  end

  def *(other : BigInt) : BigInt
    BigInt.new(@inner * other.inner)
  end

  def *(other : Int) : BigInt
    BigInt.new(@inner * other)
  end

  def &*(other) : BigInt
    self * other
  end

  # Cross-type division via Number.expand_div
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational

  # --- Floor division & modulo ---

  def //(other : BigInt) : BigInt
    BigInt.new(@inner // other.inner)
  end

  def //(other : Int) : BigInt
    BigInt.new(@inner // other)
  end

  def %(other : BigInt) : BigInt
    BigInt.new(@inner % other.inner)
  end

  def %(other : Int) : BigInt
    BigInt.new(@inner % other)
  end

  def divmod(number : BigInt) : {BigInt, BigInt}
    q, r = @inner.divmod(number.inner)
    {BigInt.new(q), BigInt.new(r)}
  end

  def divmod(number : Int) : {BigInt, BigInt}
    q, r = @inner.divmod(number)
    {BigInt.new(q), BigInt.new(r)}
  end

  def tdiv(other : BigInt) : BigInt
    BigInt.new(@inner.tdiv(other.inner))
  end

  def tdiv(other : Int) : BigInt
    BigInt.new(@inner.tdiv(other))
  end

  def remainder(other : BigInt) : BigInt
    BigInt.new(@inner.remainder(other.inner))
  end

  def remainder(other : Int) : BigInt
    BigInt.new(@inner.remainder(other))
  end

  # --- Unsafe division variants ---

  def unsafe_floored_div(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_floored_div(other.inner))
  end

  def unsafe_floored_div(other : Int) : BigInt
    BigInt.new(@inner.unsafe_floored_div(other))
  end

  def unsafe_floored_mod(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_floored_mod(other.inner))
  end

  def unsafe_floored_mod(other : Int) : BigInt
    BigInt.new(@inner.unsafe_floored_mod(other))
  end

  def unsafe_truncated_div(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_truncated_div(other.inner))
  end

  def unsafe_truncated_div(other : Int) : BigInt
    BigInt.new(@inner.unsafe_truncated_div(other))
  end

  def unsafe_truncated_mod(other : BigInt) : BigInt
    BigInt.new(@inner.unsafe_truncated_mod(other.inner))
  end

  def unsafe_truncated_mod(other : Int) : BigInt
    BigInt.new(@inner.unsafe_truncated_mod(other))
  end

  def unsafe_floored_divmod(number : BigInt) : {BigInt, BigInt}
    q, r = @inner.unsafe_floored_divmod(number.inner)
    {BigInt.new(q), BigInt.new(r)}
  end

  def unsafe_floored_divmod(number : Int) : {BigInt, BigInt}
    q, r = @inner.unsafe_floored_divmod(number)
    {BigInt.new(q), BigInt.new(r)}
  end

  def unsafe_truncated_divmod(number : BigInt) : {BigInt, BigInt}
    q, r = @inner.unsafe_truncated_divmod(number.inner)
    {BigInt.new(q), BigInt.new(r)}
  end

  def unsafe_truncated_divmod(number : Int) : {BigInt, BigInt}
    q, r = @inner.unsafe_truncated_divmod(number)
    {BigInt.new(q), BigInt.new(r)}
  end

  # --- Exponentiation ---

  def **(other : Int) : BigInt
    BigInt.new(@inner ** other)
  end

  def pow_mod(exp : BigInt, mod : BigInt) : BigInt
    BigInt.new(@inner.pow_mod(exp.inner, mod.inner))
  end

  def pow_mod(exp : Int, mod : BigInt) : BigInt
    BigInt.new(@inner.pow_mod(exp, mod.inner))
  end

  def pow_mod(exp : BigInt | Int, mod : Int) : BigInt
    e = exp.is_a?(BigInt) ? exp.inner : exp
    BigInt.new(@inner.pow_mod(e, mod))
  end

  # --- Bitwise ---

  def ~ : BigInt
    BigInt.new(~@inner)
  end

  def <<(count : Int) : BigInt
    BigInt.new(@inner << count)
  end

  def >>(count : Int) : BigInt
    BigInt.new(@inner >> count)
  end

  def unsafe_shr(count : Int) : self
    self >> count
  end

  def bit(index : Int) : Int32
    @inner.bit(index)
  end

  delegate :popcount, :trailing_zeros_count, to: @inner

  def &(other : BigInt) : BigInt
    BigInt.new(@inner & other.inner)
  end

  def &(other : Int) : BigInt
    BigInt.new(@inner & other)
  end

  def |(other : BigInt) : BigInt
    BigInt.new(@inner | other.inner)
  end

  def |(other : Int) : BigInt
    BigInt.new(@inner | other)
  end

  def ^(other : BigInt) : BigInt
    BigInt.new(@inner ^ other.inner)
  end

  def ^(other : Int) : BigInt
    BigInt.new(@inner ^ other)
  end

  # --- Number theory ---

  def gcd(other : BigInt) : BigInt
    BigInt.new(@inner.gcd(other.inner))
  end

  def gcd(other : Int) : Int
    @inner.gcd(other)
  end

  def lcm(other : BigInt) : BigInt
    BigInt.new(@inner.lcm(other.inner))
  end

  def lcm(other : Int) : BigInt
    BigInt.new(@inner.lcm(other))
  end

  def factorial : BigInt
    BigInt.new(@inner.factorial)
  end

  def divisible_by?(number : BigInt) : Bool
    @inner.divisible_by?(number.inner)
  end

  def divisible_by?(number : Int) : Bool
    @inner.divisible_by?(number)
  end

  delegate :prime?, to: @inner

  # --- Roots & powers ---

  def sqrt : BigInt
    BigInt.new(@inner.sqrt)
  end

  def root(n : Int) : BigInt
    BigInt.new(@inner.root(n))
  end

  def next_power_of_two : BigInt
    BigInt.new(@inner.next_power_of_two)
  end

  # :nodoc:
  def factor_by(number : Int) : {BigInt, UInt64}
    result, count = @inner.factor_by(number)
    {BigInt.new(result), count}
  end

  # --- Conversion ---

  delegate :to_i, :to_i!, :to_u, :to_u!, to: @inner
  delegate :to_i8, :to_i8!, :to_i16, :to_i16!, :to_i32, :to_i32!, :to_i64, :to_i64!, to: @inner
  delegate :to_u8, :to_u8!, :to_u16, :to_u16!, :to_u32, :to_u32!, :to_u64, :to_u64!, to: @inner
  delegate :to_i128, :to_i128!, :to_u128, :to_u128!, to: @inner
  delegate :to_f, :to_f32, :to_f64, :to_f!, :to_f32!, :to_f64!, to: @inner

  def to_big_i : BigInt
    self
  end

  def to_big_f : BigFloat
    BigFloat.new(@inner.to_big_f)
  end

  def to_big_r : BigRational
    BigRational.new(@inner.to_big_r)
  end

  def to_big_d : BigDecimal
    BigDecimal.new(@inner.to_big_d)
  end

  # --- Serialization ---

  def to_s : String
    @inner.to_s
  end

  def to_s(base : Int = 10, *, precision : Int = 1, upcase : Bool = false) : String
    @inner.to_s(base, precision: precision, upcase: upcase)
  end

  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  def to_s(io : IO, base : Int = 10, *, precision : Int = 1, upcase : Bool = false) : Nil
    @inner.to_s(io, base, precision: precision, upcase: upcase)
  end

  def inspect(io : IO) : Nil
    @inner.inspect(io)
  end

  def to_bytes(big_endian : Bool = true) : Bytes
    @inner.to_bytes(big_endian)
  end

  def digits(base : Int = 10) : Array(Int32)
    @inner.digits(base)
  end

  # --- Misc ---

  def clone : BigInt
    self
  end

  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end
end

# ==========================================================================
# BigFloat — wraps BigNumber::BigFloat, inherits from Float
# ==========================================================================
struct BigFloat < Float
  include Comparable(Int)
  include Comparable(BigFloat)
  include Comparable(Float)

  # :nodoc:
  getter inner : BigNumber::BigFloat

  # :nodoc:
  def initialize(@inner : BigNumber::BigFloat)
  end

  def initialize
    @inner = BigNumber::BigFloat.new
  end

  def initialize(str : String)
    @inner = BigNumber::BigFloat.new(str)
  end

  def initialize(num : Int)
    @inner = BigNumber::BigFloat.new(num)
  end

  def initialize(num : BigInt)
    @inner = BigNumber::BigFloat.new(num.inner)
  end

  def initialize(num : Float::Primitive)
    @inner = BigNumber::BigFloat.new(num)
  end

  def initialize(num : BigRational)
    @inner = BigNumber::BigFloat.new(num.inner)
  end

  def initialize(num : BigFloat)
    @inner = num.inner
  end

  def self.new(num : BigFloat) : self
    num
  end

  def self.new(num : BigDecimal) : self
    new(num.inner.to_big_f)
  end

  def initialize(*, precision : Int32)
    @inner = BigNumber::BigFloat.new(precision: precision)
  end

  def initialize(num : Int, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(num, precision: precision)
  end

  def initialize(num : BigInt, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(num.inner, precision: precision)
  end

  def initialize(num : Float::Primitive, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(num, precision: precision)
  end

  def initialize(str : String, *, precision : Int32)
    @inner = BigNumber::BigFloat.new(str, precision: precision)
  end

  def self.default_precision : Int32
    BigNumber::BigFloat.default_precision
  end

  def self.default_precision=(value : Int32) : Nil
    BigNumber::BigFloat.default_precision = value
  end

  # --- Predicates ---

  delegate :zero?, :positive?, :negative?, :precision, to: @inner

  def nan? : Bool
    false
  end

  def infinite? : Int32?
    nil
  end

  def integer? : Bool
    @inner.integer?
  end

  def sign : Int32
    @inner.sign_i32
  end

  # --- Accessors ---

  def mantissa : BigInt
    BigInt.new(@inner.mantissa)
  end

  delegate :exponent, to: @inner

  # --- Comparison ---

  def <=>(other : BigFloat) : Int32
    @inner <=> other.inner
  end

  def <=>(other : BigInt) : Int32
    @inner <=> other.inner
  end

  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  def <=>(other : Int) : Int32
    @inner <=> other
  end

  def ==(other : BigFloat) : Bool
    @inner == other.inner
  end

  def ==(other : BigInt) : Bool
    @inner == other.inner
  end

  def ==(other : Int) : Bool
    @inner == other
  end

  def ==(other : Float) : Bool
    @inner == other
  end

  # --- Unary ---

  def - : BigFloat
    BigFloat.new(-@inner)
  end

  def abs : BigFloat
    BigFloat.new(@inner.abs)
  end

  # --- Arithmetic ---

  def +(other : BigFloat) : BigFloat
    BigFloat.new(@inner + other.inner)
  end

  def +(other : BigInt) : BigFloat
    BigFloat.new(@inner + other.inner)
  end

  def +(other : Int) : BigFloat
    BigFloat.new(@inner + other)
  end

  def +(other : Float) : BigFloat
    BigFloat.new(@inner + other)
  end

  def -(other : BigFloat) : BigFloat
    BigFloat.new(@inner - other.inner)
  end

  def -(other : BigInt) : BigFloat
    BigFloat.new(@inner - other.inner)
  end

  def -(other : Int) : BigFloat
    BigFloat.new(@inner - other)
  end

  def -(other : Float) : BigFloat
    BigFloat.new(@inner - other)
  end

  def *(other : BigFloat) : BigFloat
    BigFloat.new(@inner * other.inner)
  end

  def *(other : BigInt) : BigFloat
    BigFloat.new(@inner * other.inner)
  end

  def *(other : Int) : BigFloat
    BigFloat.new(@inner * other)
  end

  def *(other : Float) : BigFloat
    BigFloat.new(@inner * other)
  end

  def /(other : BigFloat) : BigFloat
    BigFloat.new(@inner / other.inner)
  end

  def /(other : BigInt) : BigFloat
    BigFloat.new(@inner / other.inner)
  end

  def /(other : Int) : BigFloat
    BigFloat.new(@inner / other)
  end

  def /(other : Float) : BigFloat
    BigFloat.new(@inner / other)
  end

  # Cross-type division
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational

  # --- Exponentiation ---

  def **(other : Int) : BigFloat
    BigFloat.new(@inner ** other)
  end

  def **(other : BigInt) : BigFloat
    BigFloat.new(@inner ** other.inner)
  end

  # --- Rounding ---

  def ceil : BigFloat
    BigFloat.new(@inner.ceil)
  end

  def floor : BigFloat
    BigFloat.new(@inner.floor)
  end

  def trunc : BigFloat
    BigFloat.new(@inner.trunc)
  end

  def round_even : BigFloat
    BigFloat.new(@inner.round_even)
  end

  def round_away : BigFloat
    BigFloat.new(@inner.round_away)
  end

  # --- Conversion ---

  delegate :to_f64, :to_f32, :to_f, :to_f32!, :to_f64!, :to_f!, to: @inner
  delegate :to_i, :to_i!, :to_u, :to_u!, to: @inner
  delegate :to_i8, :to_i8!, :to_i16, :to_i16!, :to_i32, :to_i32!, :to_i64, :to_i64!, to: @inner
  delegate :to_u8, :to_u8!, :to_u16, :to_u16!, :to_u32, :to_u32!, :to_u64, :to_u64!, to: @inner

  def to_big_f : BigFloat
    self
  end

  def to_big_i : BigInt
    BigInt.new(@inner.to_big_i)
  end

  def to_big_r : BigRational
    BigRational.new(@inner.to_big_r)
  end

  # --- Serialization ---

  def to_s : String
    @inner.to_s
  end

  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  def inspect(io : IO) : Nil
    @inner.inspect(io)
  end

  # --- Misc ---

  def clone : BigFloat
    self
  end

  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end

  def fdiv(other : Number::Primitive) : self
    self.class.new(self / other)
  end
end

# ==========================================================================
# BigRational — wraps BigNumber::BigRational, inherits from Number
# ==========================================================================
struct BigRational < Number
  include Comparable(BigRational)
  include Comparable(Int)
  include Comparable(Float)

  # :nodoc:
  getter inner : BigNumber::BigRational

  # :nodoc:
  def initialize(@inner : BigNumber::BigRational)
  end

  def initialize(numerator : BigInt, denominator : BigInt)
    @inner = BigNumber::BigRational.new(numerator.inner, denominator.inner)
  end

  def initialize(numerator : Int, denominator : Int)
    num = numerator.is_a?(BigInt) ? numerator.inner : BigNumber::BigInt.new(numerator)
    den = denominator.is_a?(BigInt) ? denominator.inner : BigNumber::BigInt.new(denominator)
    @inner = BigNumber::BigRational.new(num, den)
  end

  def initialize(num : BigInt)
    @inner = BigNumber::BigRational.new(num.inner)
  end

  def initialize(num : Int)
    @inner = BigNumber::BigRational.new(num)
  end

  def self.new(num : Float::Primitive) : self
    new(BigNumber::BigRational.new(num))
  end

  def self.new(num : BigFloat) : self
    new(num.inner.to_big_r)
  end

  def self.new(num : BigRational) : self
    num
  end

  def self.new(num : BigDecimal) : self
    new(num.inner.to_big_r)
  end

  def initialize(str : String)
    @inner = BigNumber::BigRational.new(str)
  end

  # --- Accessors ---

  def numerator : BigInt
    BigInt.new(@inner.numerator)
  end

  def denominator : BigInt
    BigInt.new(@inner.denominator)
  end

  # --- Predicates ---

  delegate :zero?, :positive?, :negative?, :sign, to: @inner

  def integer? : Bool
    @inner.integer?
  end

  # --- Comparison ---

  def <=>(other : BigRational) : Int32
    @inner <=> other.inner
  end

  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  def <=>(other : BigFloat) : Int32
    # Convert BigFloat to BigRational for comparison
    @inner <=> other.inner.to_big_r
  end

  def <=>(other : BigInt) : Int32
    @inner <=> other.inner
  end

  def <=>(other : Int) : Int32
    @inner <=> other
  end

  def ==(other : BigRational) : Bool
    @inner == other.inner
  end

  def ==(other : Int) : Bool
    @inner == other
  end

  def ==(other : BigInt) : Bool
    @inner == other.inner
  end

  # --- Unary ---

  def - : BigRational
    BigRational.new(-@inner)
  end

  def abs : BigRational
    BigRational.new(@inner.abs)
  end

  def inv : BigRational
    BigRational.new(@inner.inv)
  end

  # --- Arithmetic ---

  def +(other : BigRational) : BigRational
    BigRational.new(@inner + other.inner)
  end

  def +(other : BigInt) : BigRational
    BigRational.new(@inner + other.inner)
  end

  def +(other : Int) : BigRational
    BigRational.new(@inner + other)
  end

  def -(other : BigRational) : BigRational
    BigRational.new(@inner - other.inner)
  end

  def -(other : BigInt) : BigRational
    BigRational.new(@inner - other.inner)
  end

  def -(other : Int) : BigRational
    BigRational.new(@inner - other)
  end

  def *(other : BigRational) : BigRational
    BigRational.new(@inner * other.inner)
  end

  def *(other : BigInt) : BigRational
    BigRational.new(@inner * other.inner)
  end

  def *(other : Int) : BigRational
    BigRational.new(@inner * other)
  end

  def /(other : BigRational) : BigRational
    BigRational.new(@inner / other.inner)
  end

  # Cross-type division
  Number.expand_div [BigInt, BigFloat, BigDecimal], BigRational

  # --- Floor division & modulo ---

  def //(other : BigRational) : BigRational
    BigRational.new(@inner // other.inner)
  end

  def //(other : BigInt) : BigRational
    BigRational.new(@inner // other.inner)
  end

  def //(other : Int) : BigRational
    BigRational.new(@inner // other)
  end

  def %(other : BigRational) : BigRational
    BigRational.new(@inner % other.inner)
  end

  def %(other : BigInt) : BigRational
    BigRational.new(@inner % other.inner)
  end

  def %(other : Int) : BigRational
    BigRational.new(@inner % other)
  end

  def tdiv(other : BigRational) : BigRational
    BigRational.new(@inner.tdiv(other.inner))
  end

  def tdiv(other : BigInt) : BigRational
    BigRational.new(@inner.tdiv(other.inner))
  end

  def tdiv(other : Int) : BigRational
    BigRational.new(@inner.tdiv(other))
  end

  def remainder(other : BigRational) : BigRational
    BigRational.new(@inner.remainder(other.inner))
  end

  def remainder(other : BigInt) : BigRational
    BigRational.new(@inner.remainder(other.inner))
  end

  def remainder(other : Int) : BigRational
    BigRational.new(@inner.remainder(other))
  end

  # --- Exponentiation ---

  def **(other : Int) : BigRational
    BigRational.new(@inner ** other)
  end

  # --- Shifts ---

  def >>(other : Int) : BigRational
    BigRational.new(@inner >> other)
  end

  def <<(other : Int) : BigRational
    BigRational.new(@inner << other)
  end

  # --- Rounding ---

  def ceil : BigRational
    BigRational.new(@inner.ceil)
  end

  def floor : BigRational
    BigRational.new(@inner.floor)
  end

  def trunc : BigRational
    BigRational.new(@inner.trunc)
  end

  def round_away : BigRational
    BigRational.new(@inner.round_away)
  end

  def round_even : BigRational
    BigRational.new(@inner.round_even)
  end

  # --- Conversion ---

  delegate :to_f, :to_f32, :to_f64, :to_f!, :to_f32!, :to_f64!, to: @inner
  delegate :to_i, :to_i8, :to_i16, :to_i32, :to_i64, to: @inner
  delegate :to_u8, :to_u16, :to_u32, :to_u64, to: @inner

  def to_big_r : BigRational
    self
  end

  def to_big_i : BigInt
    BigInt.new(@inner.to_big_i)
  end

  def to_big_f : BigFloat
    BigFloat.new(@inner.to_big_f)
  end

  def to_big_d : BigDecimal
    BigDecimal.new(@inner.to_big_d)
  end

  # --- Serialization ---

  def to_s : String
    @inner.to_s
  end

  def to_s(base : Int = 10) : String
    @inner.to_s(base)
  end

  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  def to_s(io : IO, base : Int) : Nil
    @inner.to_s(io, base)
  end

  def inspect : String
    to_s
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  # --- Misc ---

  def clone : BigRational
    self
  end

  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end
end

# ==========================================================================
# BigDecimal — wraps BigNumber::BigDecimal, inherits from Number
# ==========================================================================
struct BigDecimal < Number
  include Comparable(Int)
  include Comparable(Float)
  include Comparable(BigRational)
  include Comparable(BigDecimal)

  DEFAULT_PRECISION = 100_u64

  # :nodoc:
  getter inner : BigNumber::BigDecimal

  # :nodoc:
  def initialize(@inner : BigNumber::BigDecimal)
  end

  def initialize(value : BigInt, scale : UInt64)
    @inner = BigNumber::BigDecimal.new(value.inner, scale)
  end

  def initialize(num : Int = 0, scale : Int = 0)
    @inner = BigNumber::BigDecimal.new(num, scale)
  end

  def initialize(num : BigInt, scale : Int = 0)
    @inner = BigNumber::BigDecimal.new(num.inner, scale)
  end

  def initialize(str : String)
    @inner = BigNumber::BigDecimal.new(str)
  end

  def self.new(num : Float) : self
    raise ArgumentError.new "Can only construct from a finite number" unless num.finite?
    new(num.to_s)
  end

  def self.new(num : BigRational) : self
    new(num.inner.to_big_d)
  end

  def self.new(num : BigDecimal) : self
    num
  end

  # --- Accessors ---

  def value : BigInt
    BigInt.new(@inner.value)
  end

  delegate :scale, to: @inner

  # --- Predicates ---

  delegate :zero?, :positive?, :negative?, :sign, :integer?, to: @inner

  # --- Comparison ---

  def <=>(other : BigDecimal) : Int32
    @inner <=> other.inner
  end

  def <=>(other : BigRational) : Int32
    @inner <=> other.inner
  end

  def <=>(other : Float::Primitive) : Int32?
    @inner <=> other
  end

  def <=>(other : Int) : Int32
    @inner <=> other
  end

  def ==(other : BigDecimal) : Bool
    @inner == other.inner
  end

  # --- Unary ---

  def - : BigDecimal
    BigDecimal.new(-@inner)
  end

  # --- Arithmetic ---

  def +(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner + other.inner)
  end

  def +(other : BigInt) : BigDecimal
    BigDecimal.new(@inner + other.inner)
  end

  def +(other : Int) : BigDecimal
    BigDecimal.new(@inner + other)
  end

  def -(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner - other.inner)
  end

  def -(other : BigInt) : BigDecimal
    BigDecimal.new(@inner - other.inner)
  end

  def -(other : Int) : BigDecimal
    BigDecimal.new(@inner - other)
  end

  def *(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner * other.inner)
  end

  def *(other : BigInt) : BigDecimal
    BigDecimal.new(@inner * other.inner)
  end

  def *(other : Int) : BigDecimal
    BigDecimal.new(@inner * other)
  end

  def %(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner % other.inner)
  end

  def %(other : Int) : BigDecimal
    BigDecimal.new(@inner % other)
  end

  def /(other : BigDecimal) : BigDecimal
    BigDecimal.new(@inner / other.inner)
  end

  def /(other : BigInt) : BigDecimal
    BigDecimal.new(@inner / other.inner)
  end

  def /(other : Int) : BigDecimal
    BigDecimal.new(@inner / other)
  end

  def div(other : BigDecimal, precision : Int = DEFAULT_PRECISION) : BigDecimal
    BigDecimal.new(@inner.div(other.inner, precision))
  end

  # --- Exponentiation ---

  def **(other : Int) : BigDecimal
    BigDecimal.new(@inner ** other)
  end

  # --- Rounding ---

  def ceil : BigDecimal
    BigDecimal.new(@inner.ceil)
  end

  def floor : BigDecimal
    BigDecimal.new(@inner.floor)
  end

  def trunc : BigDecimal
    BigDecimal.new(@inner.trunc)
  end

  def round_even : BigDecimal
    BigDecimal.new(@inner.round_even)
  end

  def round_away : BigDecimal
    BigDecimal.new(@inner.round_away)
  end

  # --- Scaling ---

  def scale_to(new_scale : BigDecimal) : BigDecimal
    BigDecimal.new(@inner.scale_to(new_scale.inner))
  end

  # --- Conversion ---

  delegate :to_f64, :to_f32, :to_f, :to_f!, :to_f32!, :to_f64!, to: @inner
  delegate :to_i, :to_i!, :to_u, :to_u!, to: @inner
  delegate :to_i8, :to_i8!, :to_i16, :to_i16!, :to_i32, :to_i32!, :to_i64, :to_i64!, to: @inner
  delegate :to_u8, :to_u8!, :to_u16, :to_u16!, :to_u32, :to_u32!, :to_u64, :to_u64!, to: @inner

  def to_big_d : BigDecimal
    self
  end

  def to_big_i : BigInt
    BigInt.new(@inner.to_big_i)
  end

  def to_big_f : BigFloat
    BigFloat.new(@inner.to_big_f)
  end

  def to_big_r : BigRational
    BigRational.new(@inner.to_big_r)
  end

  # --- Serialization ---

  def to_s : String
    @inner.to_s
  end

  def to_s(io : IO) : Nil
    @inner.to_s(io)
  end

  def inspect : String
    @inner.inspect
  end

  def inspect(io : IO) : Nil
    @inner.inspect(io)
  end

  # --- Misc ---

  def clone : BigDecimal
    self
  end

  def hash(hasher)
    hasher = @inner.hash(hasher)
    hasher
  end
end

# ==========================================================================
# Number.expand_div for primitive types (enables Int / BigInt → BigFloat etc.)
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

require "./stdlib_ext"
