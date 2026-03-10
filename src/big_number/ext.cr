struct Int
  def to_big_f(*, precision : Int32 = BigNumber::BigFloat.default_precision) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self, precision: precision)
  end

  def to_big_r : BigNumber::BigRational
    BigNumber::BigRational.new(self)
  end

  def +(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self) + other
  end

  def -(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self) - other
  end

  def *(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self) * other
  end

  def /(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self) / other
  end

  def <=>(other : BigNumber::BigFloat) : Int32
    -(other <=> self)
  end

  def ==(other : BigNumber::BigFloat) : Bool
    other == self
  end

  def +(other : BigNumber::BigRational) : BigNumber::BigRational
    BigNumber::BigRational.new(self) + other
  end

  def -(other : BigNumber::BigRational) : BigNumber::BigRational
    BigNumber::BigRational.new(self) - other
  end

  def *(other : BigNumber::BigRational) : BigNumber::BigRational
    BigNumber::BigRational.new(self) * other
  end

  def /(other : BigNumber::BigRational) : BigNumber::BigRational
    BigNumber::BigRational.new(self) / other
  end

  def <=>(other : BigNumber::BigRational) : Int32
    -(other <=> self)
  end

  def ==(other : BigNumber::BigRational) : Bool
    other == self
  end

  def +(other : BigNumber::BigInt) : BigNumber::BigInt
    BigNumber::BigInt.new(self) + other
  end

  def &+(other : BigNumber::BigInt) : BigNumber::BigInt
    self + other
  end

  def -(other : BigNumber::BigInt) : BigNumber::BigInt
    BigNumber::BigInt.new(self) - other
  end

  def &-(other : BigNumber::BigInt) : BigNumber::BigInt
    self - other
  end

  def *(other : BigNumber::BigInt) : BigNumber::BigInt
    BigNumber::BigInt.new(self) * other
  end

  def &*(other : BigNumber::BigInt) : BigNumber::BigInt
    self * other
  end

  def %(other : BigNumber::BigInt) : BigNumber::BigInt
    BigNumber::BigInt.new(self) % other
  end

  def <=>(other : BigNumber::BigInt) : Int32
    -(other <=> self)
  end

  def ==(other : BigNumber::BigInt) : Bool
    other == self
  end

  def gcd(other : BigNumber::BigInt) : Int
    BigNumber::BigInt.new(self).gcd(other).to_i64
  end

  def lcm(other : BigNumber::BigInt) : BigNumber::BigInt
    BigNumber::BigInt.new(self).lcm(other)
  end

  def to_big_i : BigNumber::BigInt
    BigNumber::BigInt.new(self)
  end
end

struct Float
  def to_big_f(*, precision : Int32 = BigNumber::BigFloat.default_precision) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self.to_f64, precision: precision)
  end

  def +(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self.to_f64) + other
  end

  def -(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self.to_f64) - other
  end

  def *(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self.to_f64) * other
  end

  def /(other : BigNumber::BigFloat) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self.to_f64) / other
  end

  def <=>(other : BigNumber::BigFloat) : Int32?
    return nil if nan?
    -(other <=> self)
  end

  def to_big_r : BigNumber::BigRational
    BigNumber::BigRational.new(self)
  end

  def <=>(other : BigNumber::BigInt) : Int32?
    return nil if nan?
    BigNumber::BigInt.new(self) <=> other
  end

  def to_big_i : BigNumber::BigInt
    BigNumber::BigInt.new(self)
  end
end

class String
  def to_big_f(*, precision : Int32 = BigNumber::BigFloat.default_precision) : BigNumber::BigFloat
    BigNumber::BigFloat.new(self, precision: precision)
  end

  def to_big_i(base : Int32 = 10) : BigNumber::BigInt
    BigNumber::BigInt.new(self, base)
  end

  def to_big_r : BigNumber::BigRational
    BigNumber::BigRational.new(self)
  end
end

module BigNumber
  struct BigInt
    def initialize(num : Float::Primitive)
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
      raise ArgumentError.new("Non-finite float") unless num.finite?
      return if num == 0
      neg = num < 0
      # Truncate toward zero
      mag = neg ? (-num).to_u128 : num.to_u128
      set_from_unsigned(mag)
      @size = -@size if neg
    end

    def initialize(other : BigInt)
      if other.zero?
        @limbs = Pointer(Limb).null
        @alloc = 0
        @size = 0
      else
        n = other.abs_size
        @alloc = n
        @limbs = Pointer(Limb).malloc(n)
        @limbs.copy_from(other.@limbs, n)
        @size = other.@size
      end
    end
  end
end
