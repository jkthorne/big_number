# Extensions for primitive types, Math, Random, and Crystal::Hasher
# to complete the stdlib drop-in replacement.
#
# This file is required by stdlib.cr and should not be required directly.

# ==========================================================================
# Primitive type conversions
# ==========================================================================

struct Int
  include Comparable(BigInt)
  include Comparable(BigRational)

  def to_big_i : BigInt
    BigInt.new(self)
  end

  def to_big_f : BigFloat
    BigFloat.new(self)
  end

  def to_big_r : BigRational
    BigRational.new(self, 1)
  end

  def to_big_d : BigDecimal
    BigDecimal.new(self)
  end

  # --- Arithmetic with BigInt ---

  def +(other : BigInt) : BigInt
    other + self
  end

  def &+(other : BigInt) : BigInt
    self + other
  end

  def -(other : BigInt) : BigInt
    BigInt.new(self) - other
  end

  def &-(other : BigInt) : BigInt
    self - other
  end

  def *(other : BigInt) : BigInt
    other * self
  end

  def &*(other : BigInt) : BigInt
    self * other
  end

  def %(other : BigInt) : BigInt
    BigInt.new(self) % other
  end

  def <=>(other : BigInt) : Int32
    -(other <=> self)
  end

  def ==(other : BigInt) : Bool
    other == self
  end

  def gcd(other : BigInt) : Int
    other.gcd(self)
  end

  def lcm(other : BigInt) : BigInt
    other.lcm(self)
  end

  # --- Arithmetic with BigRational ---

  def +(other : BigRational) : BigRational
    other + self
  end

  def -(other : BigRational) : BigRational
    self.to_big_r - other
  end

  def *(other : BigRational) : BigRational
    other * self
  end

  def /(other : BigRational)
    self.to_big_r / other
  end

  def <=>(other : BigRational) : Int32
    -(other <=> self)
  end

  # --- Arithmetic with BigFloat ---

  def <=>(other : BigFloat) : Int32
    -(other <=> self)
  end

  def -(other : BigFloat) : BigFloat
    BigFloat.new(self) - other
  end

  def /(other : BigFloat) : BigFloat
    BigFloat.new(self) / other
  end
end

struct Number
  include Comparable(BigFloat)

  def +(other : BigFloat)
    other + self
  end

  def -(other : BigFloat)
    to_big_f - other
  end

  def *(other : BigFloat) : BigFloat
    other * self
  end

  def /(other : BigFloat) : BigFloat
    to_big_f / other
  end

  def to_big_f : BigFloat
    BigFloat.new(self)
  end
end

struct Float
  include Comparable(BigInt)
  include Comparable(BigRational)

  def to_big_i : BigInt
    BigInt.new(self)
  end

  def to_big_f : BigFloat
    BigFloat.new(self.to_f64)
  end

  def to_big_r : BigRational
    BigRational.new(self)
  end

  def to_big_d : BigDecimal
    BigDecimal.new(self)
  end

  def <=>(other : BigInt)
    cmp = other <=> self
    -cmp if cmp
  end

  def <=>(other : BigFloat)
    cmp = other <=> self
    -cmp if cmp
  end

  def <=>(other : BigRational)
    cmp = other <=> self
    -cmp if cmp
  end

  def fdiv(other : BigInt | BigFloat | BigDecimal | BigRational) : self
    self.class.new(self / other)
  end
end

class String
  def to_big_i(base : Int32 = 10) : BigInt
    BigInt.new(self, base)
  end

  def to_big_f : BigFloat
    BigFloat.new(self)
  end

  def to_big_r : BigRational
    BigRational.new(self)
  end

  def to_big_d : BigDecimal
    BigDecimal.new(self)
  end
end

# ==========================================================================
# Cross-type comparison additions
# ==========================================================================

struct BigFloat
  def <=>(other : BigRational)
    -(other <=> self)
  end
end

# ==========================================================================
# Generic Number constructor for BigFloat
# ==========================================================================

struct BigFloat
  def initialize(num : Number)
    @inner = BigNumber::BigFloat.new(num.to_f64)
  end
end

# ==========================================================================
# Number.expand_div for each primitive type
# ==========================================================================

{% for type in [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128] %}
  struct {{type}}
    Number.expand_div [BigInt], BigFloat
    Number.expand_div [BigDecimal], BigDecimal
    Number.expand_div [BigRational], BigRational
  end
{% end %}

struct Float32
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct Float64
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

# ==========================================================================
# Math module
# ==========================================================================

module Math
  def isqrt(value : BigInt) : BigInt
    value.sqrt
  end

  def sqrt(value : BigInt) : BigFloat
    sqrt(value.to_big_f)
  end

  def sqrt(value : BigFloat) : BigFloat
    raise ArgumentError.new("Square root of negative number") if value.negative?
    return BigFloat.new(0) if value.zero?

    # Newton's method: x_{n+1} = (x + value/x) / 2
    f64 = value.to_f64
    x = if f64.finite? && f64 > 0
          BigFloat.new(Math.sqrt(f64))
        else
          # For extreme values, start with a rough estimate
          BigFloat.new(1)
        end

    two = BigFloat.new(2)
    100.times do
      next_x = (x + value / x) / two
      break if next_x == x
      x = next_x
    end
    x
  end

  def sqrt(value : BigRational) : BigFloat
    sqrt(value.to_big_f)
  end

  def pw2ceil(v : BigInt) : BigInt
    v.next_power_of_two
  end
end

# ==========================================================================
# Random
# ==========================================================================

module Random
  private def rand_int(max : BigInt) : BigInt
    unless max > 0
      raise ArgumentError.new "Invalid bound for rand: #{max}"
    end

    rand_max = BigInt.new(1) << (sizeof(typeof(next_u)) * 8)
    needed_parts = 1
    while rand_max < max && rand_max > 0
      rand_max <<= sizeof(typeof(next_u)) * 8
      needed_parts += 1
    end

    limit = rand_max // max * max

    loop do
      result = BigInt.new(next_u)
      (needed_parts - 1).times do
        result <<= sizeof(typeof(next_u)) * 8
        result |= BigInt.new(next_u)
      end

      if result < limit
        return result % max
      end
    end
  end

  private def rand_range(range : Range(BigInt, BigInt)) : BigInt
    span = range.end - range.begin
    unless range.excludes_end?
      span += 1
    end
    unless span > 0
      raise ArgumentError.new "Invalid range for rand: #{range}"
    end
    range.begin + rand_int(span)
  end
end

# ==========================================================================
# Crystal::Hasher — numeric hash equality
# ==========================================================================

# :nodoc:
struct Crystal::Hasher
  # Helper: reduce a BigNumber::BigInt mod HASH_MODULUS
  private def self.reduce_inner_bigint(value : BigNumber::BigInt) : UInt64
    modulus = BigNumber::BigInt.new(HASH_MODULUS)
    rem = value.remainder(modulus)
    v = rem.abs.to_u64!
    value.negative? ? &-v : v
  end

  # Modular inverse of a mod m using iterative extended GCD
  private def self.mod_inverse_u64(a : UInt64, m : UInt64) : UInt64
    return 0_u64 if a == 0
    old_r, r = a.to_i64!, m.to_i64!
    old_s, s = 1_i64, 0_i64

    while r != 0
      q = old_r // r
      old_r, r = r, old_r &- q &* r
      old_s, s = s, old_s &- q &* s
    end

    ((old_s % m.to_i64!) + m.to_i64!).to_u64! % m
  end

  # Modular exponentiation: base^exp mod m
  private def self.mod_pow_u64(base : UInt64, exp : UInt64, m : UInt64) : UInt64
    result = 1_u64
    base = base % m
    e = exp
    while e > 0
      if e.odd?
        result = UInt64.mulmod(result, base, m)
      end
      e >>= 1
      base = UInt64.mulmod(base, base, m) if e > 0
    end
    result
  end

  def self.reduce_num(value : ::BigInt) : UInt64
    reduce_inner_bigint(value.inner)
  end

  def self.reduce_num(value : ::BigFloat) : UInt64
    inner = value.inner
    return 0_u64 if inner.zero?

    m = inner.mantissa  # BigNumber::BigInt
    e = inner.exponent  # Int64

    m_mod = reduce_inner_bigint(m.abs)

    # 2^(e mod HASH_BITS) mod HASH_MODULUS
    # Crystal's % on Int is floored, so negative e gives positive result
    exp_mod = (e % HASH_BITS).to_i32
    pow2 = 1_u64 << exp_mod

    x = UInt64.mulmod(m_mod, pow2, HASH_MODULUS.to_u64!)

    inner.negative? ? &-x : x
  end

  def self.reduce_num(value : ::BigRational) : UInt64
    inner = value.inner
    return 0_u64 if inner.zero?

    den_abs = inner.denominator.abs
    modulus = BigNumber::BigInt.new(HASH_MODULUS)
    den_mod = den_abs.remainder(modulus).to_u64!

    if den_mod == 0
      # Denominator is a multiple of HASH_MODULUS — treat as infinity
      return value >= 0 ? HASH_INF_PLUS : HASH_INF_MINUS
    end

    inv = mod_inverse_u64(den_mod, HASH_MODULUS.to_u64!)
    num_hash = reduce_inner_bigint(inner.numerator.abs)

    UInt64.mulmod(num_hash, inv, HASH_MODULUS.to_u64!) &* value.sign
  end

  def self.reduce_num(value : ::BigDecimal) : UInt64
    inner = value.inner
    return 0_u64 if inner.zero?

    v = inner.value  # BigNumber::BigInt (unscaled integer)
    s = inner.scale  # UInt64

    v_mod = reduce_inner_bigint(v.abs)

    if s == 0
      return v.negative? ? &-v_mod : v_mod
    end

    # Divide by 10^s mod HASH_MODULUS
    ten_pow_s = mod_pow_u64(10_u64, s, HASH_MODULUS.to_u64!)
    inv_ten = mod_inverse_u64(ten_pow_s, HASH_MODULUS.to_u64!)

    x = UInt64.mulmod(v_mod, inv_ten, HASH_MODULUS.to_u64!)

    v.negative? ? &-x : x
  end
end

# ==========================================================================
# Update wrapper hash methods to use proper numeric hashing
# ==========================================================================

struct BigInt
  def hash(hasher)
    hasher.number(self)
  end
end

struct BigFloat
  def hash(hasher)
    hasher.number(self)
  end
end

struct BigRational
  def hash(hasher)
    hasher.number(self)
  end
end

struct BigDecimal
  def hash(hasher)
    hasher.number(self)
  end
end
