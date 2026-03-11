module BigNumber
  class InvalidBigDecimalException < Exception
    def initialize(big_decimal_str : String, reason : String)
      super("Invalid BigDecimal: #{big_decimal_str} (#{reason})")
    end
  end

  struct BigDecimal
    include Comparable(BigDecimal)
    include Comparable(Int)
    include Comparable(Float)
    include Comparable(BigRational)

    private TWO  = 2
    private FIVE = 5
    private TEN  = 10

    private TWO_I  = BigInt.new(2)
    private FIVE_I = BigInt.new(5)
    private TEN_I  = BigInt.new(10)

    DEFAULT_PRECISION = 100_u64

    getter value : BigInt
    getter scale : UInt64

    # Creates a new `BigDecimal` from `Float`.
    def self.new(num : Float) : self
      raise ArgumentError.new "Can only construct from a finite number" unless num.finite?
      new(num.to_s)
    end

    # Creates a new `BigDecimal` from `BigRational`.
    def self.new(num : BigRational) : self
      num.numerator.to_big_d / num.denominator.to_big_d
    end

    # Returns *num*.
    def self.new(num : BigDecimal) : self
      num
    end

    # Creates a new `BigDecimal` from `BigInt` *value* and `UInt64` *scale*.
    def initialize(@value : BigInt, @scale : UInt64)
    end

    # Creates a new `BigDecimal` from `Int`.
    def initialize(num : Int = 0, scale : Int = 0)
      @value = BigInt.new(num)
      @scale = scale.to_u64
    end

    # Creates a new `BigDecimal` from `BigInt`.
    def initialize(num : BigInt, scale : Int = 0)
      @value = num
      @scale = scale.to_u64
    end

    # Creates a new `BigDecimal` from a `String`.
    def initialize(str : String)
      str = str.lchop('+')
      str = str.delete('_')

      raise InvalidBigDecimalException.new(str, "Zero size") if str.bytesize == 0

      decimal_index = nil
      exponent_index = nil
      input_length = str.bytesize

      str.each_char_with_index do |char, index|
        final_character = index == input_length - 1
        first_character = index == 0
        case char
        when '-'
          unless (first_character && !final_character) || (exponent_index == index - 1 && !final_character)
            raise InvalidBigDecimalException.new(str, "Unexpected '-' character")
          end
        when '+'
          if final_character || exponent_index != index - 1
            raise InvalidBigDecimalException.new(str, "Unexpected '+' character")
          end
        when '.'
          if decimal_index || exponent_index
            raise InvalidBigDecimalException.new(str, "Unexpected '.' character")
          end
          decimal_index = index
        when 'e', 'E'
          if first_character || final_character || exponent_index || decimal_index == index - 1
            raise InvalidBigDecimalException.new(str, "Unexpected #{char.inspect} character")
          end
          exponent_index = index
        when '0'..'9'
          # Pass
        else
          raise InvalidBigDecimalException.new(str, "Unexpected #{char.inspect} character")
        end
      end

      decimal_end_index = (exponent_index || input_length) - 1
      if decimal_index
        decimal_count = (decimal_end_index - decimal_index).to_u64

        value_str = String.build do |builder|
          builder.write(str.to_slice[0, decimal_index])
          builder.write(str.to_slice[decimal_index + 1, decimal_count])
        end
        @value = BigInt.new(value_str)
      else
        decimal_count = 0_u64
        @value = BigInt.new(str[0..decimal_end_index])
      end

      if exponent_index
        exponent_postfix = str[exponent_index + 1]
        case exponent_postfix
        when '+', '-'
          exponent_positive = exponent_postfix == '+'
          exponent = str[(exponent_index + 2)..-1].to_u64
        else
          exponent_positive = true
          exponent = str[(exponent_index + 1)..-1].to_u64
        end

        @scale = exponent
        if exponent_positive
          if @scale < decimal_count
            @scale = decimal_count - @scale
          else
            @scale -= decimal_count
            @value = @value * (TEN_I ** @scale)
            @scale = 0_u64
          end
        else
          @scale += decimal_count
        end
      else
        @scale = decimal_count
      end
    end

    # --- Arithmetic ---

    def - : BigDecimal
      BigDecimal.new(-@value, @scale)
    end

    def +(other : BigDecimal) : BigDecimal
      if @scale > other.scale
        scaled = other.scale_to(self)
        BigDecimal.new(@value + scaled.value, @scale)
      elsif @scale < other.scale
        scaled = scale_to(other)
        BigDecimal.new(scaled.value + other.value, other.scale)
      else
        BigDecimal.new(@value + other.value, @scale)
      end
    end

    def +(other : Int) : BigDecimal
      self + BigDecimal.new(other)
    end

    def +(other : BigInt) : BigDecimal
      self + BigDecimal.new(other)
    end

    def -(other : BigDecimal) : BigDecimal
      if @scale > other.scale
        scaled = other.scale_to(self)
        BigDecimal.new(@value - scaled.value, @scale)
      elsif @scale < other.scale
        scaled = scale_to(other)
        BigDecimal.new(scaled.value - other.value, other.scale)
      else
        BigDecimal.new(@value - other.value, @scale)
      end
    end

    def -(other : Int) : BigDecimal
      self - BigDecimal.new(other)
    end

    def -(other : BigInt) : BigDecimal
      self - BigDecimal.new(other)
    end

    def *(other : BigDecimal) : BigDecimal
      BigDecimal.new(@value * other.value, @scale + other.scale)
    end

    def *(other : Int) : BigDecimal
      self * BigDecimal.new(other)
    end

    def *(other : BigInt) : BigDecimal
      self * BigDecimal.new(other)
    end

    def %(other : BigDecimal) : BigDecimal
      if @scale > other.scale
        scaled = other.scale_to(self)
        BigDecimal.new(@value % scaled.value, @scale)
      elsif @scale < other.scale
        scaled = scale_to(other)
        BigDecimal.new(scaled.value % other.value, other.scale)
      else
        BigDecimal.new(@value % other.value, @scale)
      end
    end

    def %(other : Int) : BigDecimal
      self % BigDecimal.new(other)
    end

    def /(other : BigDecimal) : BigDecimal
      div other
    end

    def /(other : Int) : BigDecimal
      self / BigDecimal.new(other)
    end

    def /(other : BigInt) : BigDecimal
      self / BigDecimal.new(other)
    end

    def div(other : BigDecimal, precision : Int = DEFAULT_PRECISION) : BigDecimal
      check_division_by_zero other
      return self if @value.zero?
      other.factor_powers_of_ten

      numerator, denominator = @value, other.@value
      scale = if @scale >= other.scale
                @scale - other.scale
              else
                numerator = numerator * power_ten_to(other.scale - @scale)
                0_u64
              end

      quotient, remainder = numerator.divmod(denominator)
      if remainder.zero?
        return BigDecimal.new(normalize_quotient(other, quotient), scale)
      end

      denominator_reduced, denominator_exp2 = denominator.factor_by(TWO)

      case denominator_reduced
      when BigInt.new(1)
        denominator_exp5 = 0_u64
      when BigInt.new(5)
        denominator_reduced = denominator_reduced // FIVE_I
        denominator_exp5 = 1_u64
      when BigInt.new(25)
        denominator_reduced = denominator_reduced // FIVE_I // FIVE_I
        denominator_exp5 = 2_u64
      else
        denominator_reduced, denominator_exp5 = denominator_reduced.factor_by(FIVE)
      end

      if denominator_reduced != BigInt.new(1)
        scale_add = precision.to_u64
      elsif denominator_exp2 <= 1 && denominator_exp5 <= 1
        quotient = numerator * TEN_I // denominator
        return BigDecimal.new(normalize_quotient(other, quotient), scale + 1)
      else
        _, numerator_exp10 = remainder.factor_by(TEN)
        scale_add = {denominator_exp2, denominator_exp5}.max - numerator_exp10
        scale_add = precision.to_u64 if scale_add > precision
      end

      quotient = numerator * power_ten_to(scale_add) // denominator
      BigDecimal.new(normalize_quotient(other, quotient), scale + scale_add)
    end

    def **(other : Int) : BigDecimal
      return (to_big_r ** other).to_big_d if other < 0
      BigDecimal.new(@value ** other, @scale * other)
    end

    # --- Comparison ---

    def <=>(other : BigDecimal) : Int32
      if @scale > other.scale
        @value <=> other.scale_to(self).value
      elsif @scale < other.scale
        scale_to(other).value <=> other.value
      else
        @value <=> other.value
      end
    end

    def <=>(other : BigRational) : Int32
      if @scale == 0
        @value <=> other
      else
        @value * other.denominator <=> power_ten_to(@scale) * other.numerator
      end
    end

    def <=>(other : Float::Primitive) : Int32?
      return nil if other.nan?
      if sign = other.infinite?
        return -sign
      end
      self <=> BigDecimal.new(other)
    end

    def <=>(other : Int) : Int32
      self <=> BigDecimal.new(other)
    end

    def ==(other : BigDecimal) : Bool
      case @scale
      when .>(other.scale)
        scaled = other.value * power_ten_to(@scale - other.scale)
        @value == scaled
      when .<(other.scale)
        scaled = @value * power_ten_to(other.scale - @scale)
        scaled == other.value
      else
        @value == other.value
      end
    end

    # --- Predicates ---

    def zero? : Bool
      @value.zero?
    end

    def positive? : Bool
      @value.positive?
    end

    def negative? : Bool
      @value.negative?
    end

    def sign : Int32
      @value.sign
    end

    def integer? : Bool
      factor_powers_of_ten
      @scale == 0
    end

    # --- Scaling ---

    def scale_to(new_scale : BigDecimal) : BigDecimal
      in_scale(new_scale.scale)
    end

    private def in_scale(new_scale : UInt64) : BigDecimal
      if @value.zero?
        BigDecimal.new(BigInt.new(0), new_scale)
      elsif @scale > new_scale
        scale_diff = @scale - new_scale
        BigDecimal.new(@value // power_ten_to(scale_diff), new_scale)
      elsif @scale < new_scale
        scale_diff = new_scale - @scale
        BigDecimal.new(@value * power_ten_to(scale_diff), new_scale)
      else
        self
      end
    end

    # --- Rounding ---

    def ceil : BigDecimal
      round_impl { |rem| rem > BigInt.new(0) }
    end

    def floor : BigDecimal
      round_impl { |rem| rem < BigInt.new(0) }
    end

    def trunc : BigDecimal
      round_impl { false }
    end

    def round_even : BigDecimal
      round_impl do |rem, rem_range, mantissa|
        case rem.abs <=> rem_range // BigInt.new(2)
        when .<(0)
          false
        when .>(0)
          true
        else
          mantissa.odd?
        end
      end
    end

    def round_away : BigDecimal
      round_impl { |rem, rem_range| rem.abs >= rem_range // BigInt.new(2) }
    end

    private def round_impl(&)
      return self if @scale <= 0 || zero?

      multiplier = power_ten_to(@scale)
      mantissa, rem = @value.unsafe_truncated_divmod(multiplier)

      round_away = yield rem, multiplier, mantissa
      mantissa = mantissa + BigInt.new(sign) if round_away

      BigDecimal.new(mantissa, 0_u64)
    end

    # --- Conversions ---

    def to_s : String
      String.build { |io| to_s(io) }
    end

    def to_s(io : IO) : Nil
      factor_powers_of_ten

      str = @value.abs.to_s
      is_negative = @value.negative?

      io << '-' if is_negative

      if @scale == 0
        io << str
        io << ".0"
      elsif @scale >= str.size.to_u64
        # Value is less than 1: 0.00...digits
        io << "0."
        (@scale - str.size).times { io << '0' }
        # Strip trailing zeros
        stripped = str.rstrip('0')
        stripped = "0" if stripped.empty?
        io << stripped
      else
        # Insert decimal point
        point_pos = str.size - @scale.to_i32
        io << str[0...point_pos]
        io << '.'
        frac = str[point_pos..]
        stripped = frac.rstrip('0')
        stripped = "0" if stripped.empty?
        io << stripped
      end
    end

    def inspect(io : IO) : Nil
      to_s(io)
    end

    def inspect : String
      to_s
    end

    def to_big_i : BigInt
      trunc.value
    end

    def to_big_f(*, precision : Int32 = BigFloat.default_precision) : BigFloat
      BigFloat.new(to_s, precision: precision)
    end

    def to_big_d : BigDecimal
      self
    end

    def to_big_r : BigRational
      BigRational.new(@value, power_ten_to(@scale))
    end

    def to_i : Int32
      to_i32
    end

    def to_i! : Int32
      to_i32!
    end

    def to_u : UInt32
      to_u32
    end

    def to_u! : UInt32
      to_u32!
    end

    {% for info in [{Int8, "i8"}, {Int16, "i16"}, {Int32, "i32"}, {Int64, "i64"}] %}
      def to_{{info[1].id}} : {{info[0]}}
        to_big_i.to_{{info[1].id}}
      end

      def to_{{info[1].id}}! : {{info[0]}}
        to_big_i.to_{{info[1].id}}!
      end
    {% end %}

    private def to_big_u : BigInt
      raise OverflowError.new if negative?
      to_big_u!
    end

    private def to_big_u! : BigInt
      @value.abs // power_ten_to(@scale)
    end

    {% for info in [{UInt8, "u8"}, {UInt16, "u16"}, {UInt32, "u32"}, {UInt64, "u64"}] %}
      def to_{{info[1].id}} : {{info[0]}}
        to_big_u.to_{{info[1].id}}
      end

      def to_{{info[1].id}}! : {{info[0]}}
        to_big_u!.to_{{info[1].id}}!
      end
    {% end %}

    def to_f64 : Float64
      to_s.to_f64
    end

    def to_f32 : Float32
      to_f64.to_f32
    end

    def to_f : Float64
      to_f64
    end

    def to_f32! : Float32
      to_f64.to_f32!
    end

    def to_f64! : Float64
      to_f64
    end

    def to_f! : Float64
      to_f64!
    end

    def clone : BigDecimal
      self
    end

    def hash(hasher)
      hasher = @value.hash(hasher)
      hasher = @scale.hash(hasher)
      hasher
    end

    # --- Internal helpers ---

    def normalize_quotient(other : BigDecimal, quotient : BigInt) : BigInt
      if (@value.negative? && other.value.positive?) || (other.value.negative? && @value.positive?)
        -quotient.abs
      else
        quotient
      end
    end

    private def check_division_by_zero(bd : BigDecimal)
      raise DivisionByZeroError.new if bd.value.zero?
    end

    private def power_ten_to(x : Int) : BigInt
      TEN_I ** x
    end

    protected def mul_power_of_ten(exponent : Int) : BigDecimal
      if exponent <= @scale
        BigDecimal.new(@value, @scale - exponent)
      else
        BigDecimal.new(@value * power_ten_to(exponent - @scale), 0_u64)
      end
    end

    protected def factor_powers_of_ten : Nil
      if @scale > 0
        neg = @value.negative?
        reduced, exp = @value.factor_by(TEN)
        reduced = -reduced if neg
        if exp <= @scale
          @value = reduced
          @scale -= exp
        else
          @value = @value // power_ten_to(@scale)
          @scale = 0_u64
        end
      end
    end
  end
end
