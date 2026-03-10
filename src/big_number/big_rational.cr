module BigNumber
  struct BigRational
    include Comparable(BigRational)
    include Comparable(Int)
    include Comparable(BigInt)

    getter numerator : BigInt
    getter denominator : BigInt

    def initialize(@numerator : BigInt, @denominator : BigInt)
      canonicalize!
    end

    def initialize(num : Int, den : Int)
      @numerator = BigInt.new(num)
      @denominator = BigInt.new(den)
      canonicalize!
    end

    def initialize(value : BigInt)
      @numerator = value.clone
      @denominator = BigInt.new(1)
    end

    def initialize(value : Int)
      @numerator = BigInt.new(value)
      @denominator = BigInt.new(1)
    end

    def initialize(value : Float)
      raise ArgumentError.new("Non-finite float") unless value.finite?
      if value == 0.0
        @numerator = BigInt.new(0)
        @denominator = BigInt.new(1)
        return
      end

      # Decompose float into exact rational representation
      # value = mantissa * 2^exponent where mantissa is an integer
      neg = value < 0
      f = neg ? -value : value

      # Extract mantissa and exponent via frexp-style decomposition
      # Float64 has 52-bit mantissa; value = significand * 2^exp where 0.5 <= significand < 1
      # We need the integer mantissa: multiply by 2^53 and adjust exponent
      bits = value.unsafe_as(UInt64)
      exponent = ((bits >> 52) & 0x7FF).to_i32 - 1023 - 52
      mantissa = (bits & 0x000FFFFFFFFFFFFF_u64) | 0x0010000000000000_u64

      @numerator = BigInt.new(mantissa)
      if exponent >= 0
        @numerator = @numerator << exponent
        @denominator = BigInt.new(1)
      else
        @denominator = BigInt.new(1) << (-exponent)
      end

      @numerator = -@numerator if neg
      canonicalize!
    end

    def initialize(str : String)
      if str.includes?('/')
        parts = str.split('/', 2)
        @numerator = BigInt.new(parts[0].strip)
        @denominator = BigInt.new(parts[1].strip)
        canonicalize!
      else
        @numerator = BigInt.new(str.strip)
        @denominator = BigInt.new(1)
      end
    end

    # --- Arithmetic ---

    def +(other : BigRational) : BigRational
      # a/b + c/d = (a*d + c*b) / (b*d)
      BigRational.new(
        @numerator * other.denominator + other.numerator * @denominator,
        @denominator * other.denominator
      )
    end

    def +(other : Int) : BigRational
      self + BigRational.new(other)
    end

    def +(other : BigInt) : BigRational
      self + BigRational.new(other)
    end

    def -(other : BigRational) : BigRational
      BigRational.new(
        @numerator * other.denominator - other.numerator * @denominator,
        @denominator * other.denominator
      )
    end

    def -(other : Int) : BigRational
      self - BigRational.new(other)
    end

    def -(other : BigInt) : BigRational
      self - BigRational.new(other)
    end

    def - : BigRational
      BigRational.new(-@numerator, @denominator.clone)
    end

    def *(other : BigRational) : BigRational
      BigRational.new(
        @numerator * other.numerator,
        @denominator * other.denominator
      )
    end

    def *(other : Int) : BigRational
      self * BigRational.new(other)
    end

    def *(other : BigInt) : BigRational
      self * BigRational.new(other)
    end

    def /(other : BigRational) : BigRational
      raise DivisionByZeroError.new if other.numerator.zero?
      BigRational.new(
        @numerator * other.denominator,
        @denominator * other.numerator
      )
    end

    def /(other : Int) : BigRational
      self / BigRational.new(other)
    end

    def /(other : BigInt) : BigRational
      self / BigRational.new(other)
    end

    def **(exponent : Int) : BigRational
      if exponent == 0
        return BigRational.new(1)
      elsif exponent < 0
        inv ** (-exponent)
      elsif exponent == 1
        clone
      else
        # Binary exponentiation
        result = BigRational.new(1)
        base = clone
        exp = exponent
        while exp > 0
          result = result * base if exp.odd?
          base = base * base
          exp >>= 1
        end
        result
      end
    end

    # --- Comparison ---

    def <=>(other : BigRational) : Int32
      # a/b <=> c/d  =>  a*d <=> c*b (denominators always positive)
      left = @numerator * other.denominator
      right = other.numerator * @denominator
      left <=> right
    end

    def <=>(other : Int) : Int32
      self <=> BigRational.new(other)
    end

    def <=>(other : BigInt) : Int32
      self <=> BigRational.new(other)
    end

    def ==(other : BigRational) : Bool
      @numerator == other.numerator && @denominator == other.denominator
    end

    def ==(other : Int) : Bool
      @denominator == BigInt.new(1) && @numerator == BigInt.new(other)
    end

    def ==(other : BigInt) : Bool
      @denominator == BigInt.new(1) && @numerator == other
    end

    # --- Predicates ---

    def zero? : Bool
      @numerator.zero?
    end

    def positive? : Bool
      @numerator.positive?
    end

    def negative? : Bool
      @numerator.negative?
    end

    def integer? : Bool
      @denominator == BigInt.new(1)
    end

    # --- Unary / misc ---

    def abs : BigRational
      BigRational.new(@numerator.abs, @denominator.clone)
    end

    def inv : BigRational
      raise DivisionByZeroError.new if @numerator.zero?
      BigRational.new(@denominator.clone, @numerator.clone)
    end

    # --- Conversions ---

    def to_f64 : Float64
      @numerator.to_f64 / @denominator.to_f64
    end

    def to_f : Float64
      to_f64
    end

    def to_s : String
      String.build { |io| to_s(io) }
    end

    def to_s(io : IO) : Nil
      if @denominator == BigInt.new(1)
        @numerator.to_s(io)
      else
        @numerator.to_s(io)
        io << '/'
        @denominator.to_s(io)
      end
    end

    def inspect(io : IO) : Nil
      to_s(io)
    end

    def to_big_r : BigRational
      self
    end

    def hash(hasher)
      hasher = @numerator.hash(hasher)
      hasher = @denominator.hash(hasher)
      hasher
    end

    def clone : BigRational
      BigRational.new(@numerator.clone, @denominator.clone)
    end

    # --- Private ---

    private def canonicalize!
      raise DivisionByZeroError.new if @denominator.zero?

      # Handle zero numerator
      if @numerator.zero?
        @denominator = BigInt.new(1)
        return
      end

      g = @numerator.abs.gcd(@denominator.abs)
      unless g == BigInt.new(1)
        @numerator = @numerator // g
        @denominator = @denominator // g
      end

      # Ensure denominator is positive
      if @denominator.negative?
        @numerator = -@numerator
        @denominator = -@denominator
      end
    end
  end
end
