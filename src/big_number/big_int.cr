module BigNumber
  # Convert a finite float's truncated integer part to a BigInt.
  # Uses binary decomposition to avoid precision loss from string conversion.
  protected def self.float_to_bigint(f : Float64) : BigInt
    return BigInt.new(0) if f == 0.0
    neg = f < 0
    f = -f if neg
    # Decompose f = mantissa * 2^exponent
    # IEEE 754: 52-bit mantissa, 11-bit exponent
    bits = f.unsafe_as(UInt64)
    raw_exp = ((bits >> 52) & 0x7FF).to_i32
    mantissa = bits & ((1_u64 << 52) - 1)
    if raw_exp == 0
      # Denormalized
      exp = -1074
    else
      mantissa |= (1_u64 << 52) # implicit leading 1
      exp = raw_exp - 1023 - 52
    end
    result = BigInt.new(mantissa)
    if exp > 0
      result = result << exp
    elsif exp < 0
      result = result >> (-exp)
    end
    neg ? -result : result
  end

  struct BigInt
    include Comparable(BigInt)
    include Comparable(Int)

    @limbs : Pointer(Limb)
    @alloc : Int32
    @size : Int32 # positive = positive number, negative = negative number, 0 = zero

    # --- Construction ---

    def initialize
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
    end

    def initialize(value : Int8 | Int16 | Int32 | Int64 | Int128)
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
      if value == 0
        return
      end
      neg = value < 0
      # Get absolute value as UInt128 to handle Int64::MIN safely
      mag = neg ? (0_u128 &- value.to_u128!) : value.to_u128
      set_from_unsigned(mag)
      @size = -@size if neg
    end

    def initialize(value : UInt8 | UInt16 | UInt32 | UInt64 | UInt128)
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
      return if value == 0
      set_from_unsigned(value.to_u128)
    end

    def initialize(str : String, base : Int32 = 10)
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
      raise ArgumentError.new("Invalid base #{base}") unless 2 <= base <= 36
      raise ArgumentError.new("Empty string") if str.empty?

      i = 0
      neg = false
      if str[i] == '-'
        neg = true
        i += 1
      elsif str[i] == '+'
        i += 1
      end
      raise ArgumentError.new("No digits in #{str.inspect}") if i >= str.size

      # Skip leading zeros
      while i < str.size && str[i] == '0'
        i += 1
      end
      if i >= str.size
        # All zeros
        return
      end

      # Process digits: accumulate in chunks for efficiency.
      # We pick a chunk size so that base^chunk fits in a UInt64.
      chunk_size, chunk_base = BigInt.chunk_params(base)

      while i < str.size
        # Grab up to chunk_size digits
        chunk_end = Math.min(i + chunk_size, str.size)
        actual_chunk = chunk_end - i
        digit_val = 0_u64
        multiplier = 1_u64
        # Compute base^actual_chunk and the digit value
        actual_base = 1_u64
        j = i
        while j < chunk_end
          d = BigInt.char_to_digit(str[j], base)
          digit_val = digit_val &* base.to_u64 &+ d.to_u64
          actual_base = actual_base &* base.to_u64
          j += 1
        end
        # self = self * actual_base + digit_val
        n = abs_size
        if n == 0
          # First chunk: just set the value
          if digit_val != 0
            ensure_capacity(1)
            @limbs[0] = digit_val
            @size = 1
          end
        else
          ensure_capacity(n + 1)
          carry = BigInt.limbs_mul_1(@limbs, @limbs, n, actual_base)
          if digit_val != 0
            add_carry = BigInt.limbs_add_1(@limbs, @limbs, n, digit_val)
            carry = carry &+ add_carry
          end
          if carry != 0
            @limbs[n] = carry
            @size = n + 1
          end
        end
        i = chunk_end
      end

      @size = -@size if neg && @size != 0
    end

    def self.from_digits(digits : Enumerable(Int), base : Int = 10) : self
      raise ArgumentError.new("Invalid base #{base}") if base < 2
      result = BigInt.new(0)
      multiplier = BigInt.new(1)
      b = BigInt.new(base)
      digits.each do |digit|
        raise ArgumentError.new("Invalid digit #{digit}") if digit < 0
        raise ArgumentError.new("Invalid digit #{digit} for base #{base}") if digit >= base
        result = result + multiplier * BigInt.new(digit)
        multiplier = multiplier * b
      end
      result
    end

    # --- Accessors ---

    @[AlwaysInline]
    def abs_size : Int32
      @size < 0 ? -@size : @size
    end

    @[AlwaysInline]
    def zero? : Bool
      @size == 0
    end

    @[AlwaysInline]
    def negative? : Bool
      @size < 0
    end

    @[AlwaysInline]
    def positive? : Bool
      @size > 0
    end

    @[AlwaysInline]
    def even? : Bool
      zero? || (@limbs[0] & 1_u64) == 0
    end

    @[AlwaysInline]
    def odd? : Bool
      !zero? && (@limbs[0] & 1_u64) == 1
    end

    @[AlwaysInline]
    def sign : Int32
      @size < 0 ? -1 : (@size > 0 ? 1 : 0)
    end

    # --- Comparison ---

    def <=>(other : BigInt) : Int32
      # Different signs: negative < zero < positive
      if @size != other.@size
        sa = @size < 0 ? -1 : (@size > 0 ? 1 : 0)
        sb = other.@size < 0 ? -1 : (other.@size > 0 ? 1 : 0)
        return sa - sb if sa != sb
      end
      # Same sign. Compare magnitudes.
      an = abs_size
      bn = other.abs_size
      cmp = BigInt.limbs_cmp(@limbs, an, other.@limbs, bn)
      @size < 0 ? -cmp : cmp
    end

    def <=>(other : Int) : Int32
      # Fast path: avoid allocation for single/zero-limb comparisons
      other_neg = other < 0
      if negative? && !other_neg
        return -1
      elsif !negative? && other_neg
        return zero? && other == 0 ? 0 : (negative? ? -1 : 1)
      end
      # Same sign
      if other == 0
        return zero? ? 0 : (negative? ? -1 : 1)
      end
      mag = other_neg ? (0_u128 &- other.to_u128!) : other.to_u128
      lo = mag.to_u64!
      hi = (mag >> 64).to_u64!
      other_size = hi != 0 ? 2 : 1
      n = abs_size
      if n != other_size
        cmp = n > other_size ? 1 : -1
        return negative? ? -cmp : cmp
      end
      # Same number of limbs — compare from top
      if other_size == 2
        cmp = if @limbs[1] != hi
                @limbs[1] > hi ? 1 : -1
              elsif @limbs[0] != lo
                @limbs[0] > lo ? 1 : -1
              else
                0
              end
      else
        cmp = if @limbs[0] != lo
                @limbs[0] > lo ? 1 : -1
              else
                0
              end
      end
      negative? ? -cmp : cmp
    end

    def <=>(other : Float::Primitive) : Int32?
      return nil if other.nan?
      if other.infinite?
        return other > 0 ? -1 : 1
      end
      f = other.to_f64
      # Check if float has a fractional part
      trunc = LibM.trunc_f64(f)
      has_frac = f != trunc
      # Build BigInt from the integer part of the float via binary decomposition
      other_int = BigNumber.float_to_bigint(f)
      cmp = self <=> other_int
      if cmp != 0
        cmp < 0 ? -1 : 1
      elsif has_frac
        # self == integer part of other, but other has fractional part
        f > 0 ? -1 : 1
      else
        0
      end
    end

    def ==(other : BigInt) : Bool
      return false if @size != other.@size
      n = abs_size
      n.times do |i|
        return false if @limbs[i] != other.@limbs[i]
      end
      true
    end

    def ==(other : Int) : Bool
      # Fast path: avoid allocation for small comparisons
      if other == 0
        return zero?
      end
      neg = other < 0
      return false if neg != negative?
      mag = neg ? (0_u128 &- other.to_u128!) : other.to_u128
      lo = mag.to_u64!
      hi = (mag >> 64).to_u64!
      if hi != 0
        return false if abs_size != 2
        @limbs[0] == lo && @limbs[1] == hi
      else
        return false if abs_size != 1
        @limbs[0] == lo
      end
    end

    def hash(hasher)
      hasher = @size.hash(hasher)
      abs_size.times do |i|
        hasher = @limbs[i].hash(hasher)
      end
      hasher
    end

    # --- Unary ---

    def - : BigInt
      result = dup_value
      result.negate!
      result
    end

    def abs : BigInt
      result = dup_value
      result.abs!
      result
    end

    # --- Addition & Subtraction ---

    def +(other : BigInt) : BigInt
      return dup_value if other.zero?
      return other.dup_value if zero?

      # Single-limb fast path
      if @size.abs == 1 && other.@size.abs == 1
        a = @limbs[0].to_i128
        a = -a if @size < 0
        b = other.@limbs[0].to_i128
        b = -b if other.@size < 0
        return BigInt.new(a + b)
      end

      if (@size ^ other.@size) >= 0
        # Same sign: add magnitudes, keep sign
        add_magnitudes(other)
      else
        # Different signs: subtract magnitudes
        sub_magnitudes(other)
      end
    end

    def +(other : Int) : BigInt
      self + BigInt.new(other)
    end

    def -(other : BigInt) : BigInt
      return dup_value if other.zero?
      if zero?
        result = other.dup_value
        result.negate!
        return result
      end

      # Single-limb fast path
      if @size.abs == 1 && other.@size.abs == 1
        a = @limbs[0].to_i128
        a = -a if @size < 0
        b = other.@limbs[0].to_i128
        b = -b if other.@size < 0
        return BigInt.new(a - b)
      end

      if (@size ^ other.@size) < 0
        # Different signs: add magnitudes, keep self's sign
        add_magnitudes(other)
      else
        # Same sign: subtract magnitudes
        sub_magnitudes(other)
      end
    end

    def -(other : Int) : BigInt
      self - BigInt.new(other)
    end

    # --- Multiplication ---

    def *(other : BigInt) : BigInt
      return BigInt.new if zero? || other.zero?

      # Single-limb fast path: use UInt128 multiply
      if @size.abs == 1 && other.@size.abs == 1
        prod = @limbs[0].to_u128 &* other.@limbs[0].to_u128
        result = BigInt.new(capacity: 2)
        result.@limbs[0] = prod.to_u64!
        hi = (prod >> 64).to_u64!
        if hi != 0
          result.@limbs[1] = hi
          result.set_size(2)
        else
          result.set_size(1)
        end
        if (@size < 0) ^ (other.@size < 0)
          result.set_size(-result.@size)
        end
        return result
      end

      an = abs_size
      bn = other.abs_size
      rn = an + bn
      result = BigInt.new(capacity: rn)
      if an >= bn
        BigInt.limbs_mul(result.@limbs, @limbs, an, other.@limbs, bn)
      else
        BigInt.limbs_mul(result.@limbs, other.@limbs, bn, @limbs, an)
      end
      result.set_size(rn)
      result.normalize!
      # Sign: negative if exactly one operand is negative
      if (@size < 0) ^ (other.@size < 0)
        result.set_size(-result.@size)
      end
      result
    end

    def *(other : Int) : BigInt
      return BigInt.new if zero? || other == 0
      # Fast path: multiply by single limb without constructing a temporary BigInt
      neg = (negative?) ^ (other < 0)
      mag = other < 0 ? (0_u128 &- other.to_u128!) : other.to_u128
      lo = mag.to_u64!
      hi = (mag >> 64).to_u64!
      if hi == 0
        n = abs_size
        result = BigInt.new(capacity: n + 1)
        carry = BigInt.limbs_mul_1(result.@limbs, @limbs, n, lo)
        if carry != 0
          result.@limbs[n] = carry
          result.set_size(n + 1)
        else
          result.set_size(n)
        end
        result.set_size(-result.@size) if neg
        return result
      end
      self * BigInt.new(other)
    end

    # --- Division ---

    # Truncating division: quotient truncated toward zero, remainder same sign as dividend.
    def tdiv_rem(other : BigInt) : {BigInt, BigInt}
      raise DivisionByZeroError.new if other.zero?
      an = abs_size
      bn = other.abs_size
      cmp = BigInt.limbs_cmp(@limbs, an, other.@limbs, bn)
      if cmp == 0
        # |self| == |other|
        q = BigInt.new(1)
        if (@size < 0) ^ (other.@size < 0)
          q.set_size(-1)
        end
        return {q, BigInt.new}
      elsif cmp < 0
        # |self| < |other| => quotient is 0, remainder is self
        return {BigInt.new, dup_value}
      end

      # Single-limb divisor fast path
      if bn == 1
        q = BigInt.new(capacity: an)
        rem_limb = BigInt.limbs_div_rem_1(q.@limbs, @limbs, an, other.@limbs[0])
        q.set_size(an)
        q.normalize!
        r = BigInt.new
        if rem_limb != 0
          r = BigInt.new(capacity: 1)
          r.@limbs[0] = rem_limb
          r.set_size(1)
        end
        # Signs
        if (@size < 0) ^ (other.@size < 0)
          q.set_size(-q.@size)
        end
        if @size < 0
          r.set_size(-r.@size)
        end
        return {q, r}
      end

      # Multi-limb: Knuth Algorithm D
      qn = an - bn + 1
      q = BigInt.new(capacity: qn)
      r = BigInt.new(capacity: bn)
      scratch = Pointer(Limb).malloc(an + bn + 1)
      BigInt.limbs_div_rem(q.@limbs, r.@limbs, @limbs, an, other.@limbs, bn, scratch)
      q.set_size(qn)
      q.normalize!
      r.set_size(bn)
      r.normalize!
      # Signs
      if (@size < 0) ^ (other.@size < 0)
        q.set_size(-q.@size)
      end
      if @size < 0 && r.@size != 0
        r.set_size(-r.@size)
      end
      {q, r}
    end

    # Floor division and modulo (Crystal convention: result rounds toward -infinity)
    def divmod(other : BigInt) : {BigInt, BigInt}
      q, r = tdiv_rem(other)
      # If remainder is nonzero and signs of dividend and divisor differ, adjust
      if !r.zero? && ((@size < 0) ^ (other.@size < 0))
        q = q - 1
        r = r + other
      end
      {q, r}
    end

    def //(other : BigInt) : BigInt
      divmod(other)[0]
    end

    def //(other : Int) : BigInt
      self // BigInt.new(other)
    end

    def %(other : BigInt) : BigInt
      divmod(other)[1]
    end

    def %(other : Int) : BigInt
      self % BigInt.new(other)
    end

    def tdiv(other : BigInt) : BigInt
      tdiv_rem(other)[0]
    end

    def tmod(other : BigInt) : BigInt
      tdiv_rem(other)[1]
    end

    def remainder(other : BigInt) : BigInt
      tmod(other)
    end

    def remainder(other : Int) : BigInt
      tmod(BigInt.new(other))
    end

    # Wrapping ops — BigInt can't overflow, so these are identical to normal ops
    def &+(other) : BigInt
      self + other
    end

    def &-(other) : BigInt
      self - other
    end

    def &*(other) : BigInt
      self * other
    end

    # Unsafe division variants — same as safe versions for BigInt
    def unsafe_floored_div(other : BigInt) : BigInt
      self // other
    end

    def unsafe_floored_div(other : Int) : BigInt
      self // other
    end

    def unsafe_floored_mod(other : BigInt) : BigInt
      self % other
    end

    def unsafe_floored_mod(other : Int) : BigInt
      self % other
    end

    def unsafe_floored_divmod(other : BigInt) : {BigInt, BigInt}
      divmod(other)
    end

    def unsafe_floored_divmod(other : Int) : {BigInt, BigInt}
      divmod(BigInt.new(other))
    end

    def unsafe_truncated_div(other : BigInt) : BigInt
      tdiv(other)
    end

    def unsafe_truncated_div(other : Int) : BigInt
      tdiv(BigInt.new(other))
    end

    def unsafe_truncated_mod(other : BigInt) : BigInt
      tmod(other)
    end

    def unsafe_truncated_mod(other : Int) : BigInt
      tmod(BigInt.new(other))
    end

    def unsafe_truncated_divmod(other : BigInt) : {BigInt, BigInt}
      tdiv_rem(other)
    end

    def unsafe_truncated_divmod(other : Int) : {BigInt, BigInt}
      tdiv_rem(BigInt.new(other))
    end

    # --- Exponentiation ---

    def **(exp : Int) : BigInt
      raise ArgumentError.new("Negative exponent #{exp}") if exp < 0
      return BigInt.new(1) if exp == 0
      return dup_value if exp == 1
      return BigInt.new if zero?

      base = dup_value
      result = BigInt.new(1)
      e = exp.to_i64
      while e > 0
        if e.odd?
          result = result * base
        end
        e >>= 1
        base = base * base if e > 0
      end
      result
    end

    def pow_mod(exp : BigInt, mod : BigInt) : BigInt
      raise ArgumentError.new("Negative exponent") if exp.negative?
      raise ArgumentError.new("Modulus must be positive") if !mod.positive?
      return BigInt.new if mod.abs_size == 1 && mod.@limbs[0] == 1_u64
      result = self % mod
      if exp.zero?
        return BigInt.new(1) % mod
      end
      # Use the exponent's bit_length to iterate without allocating a copy
      base = result
      result = BigInt.new(1)
      bits = exp.bit_length
      i = 0
      while i < bits
        if exp.bit(i) == 1
          result = (result * base) % mod
        end
        i += 1
        base = (base * base) % mod if i < bits
      end
      result
    end

    def pow_mod(exp : Int, mod : BigInt) : BigInt
      pow_mod(BigInt.new(exp), mod)
    end

    def pow_mod(exp : BigInt | Int, mod : Int) : BigInt
      pow_mod(BigInt.new(exp), BigInt.new(mod))
    end

    # --- Bitwise Operations ---

    def ~ : BigInt
      # ~x = -(x + 1)
      if negative?
        # ~(-x) = x - 1
        self.abs - 1
      else
        # ~x = -(x + 1)
        -(self + 1)
      end
    end

    def <<(count : Int) : BigInt
      return self >> (-count) if count < 0
      return dup_value if count == 0
      return BigInt.new if zero?

      whole_limbs = count.to_i32 // 64
      bit_shift = count.to_i32 % 64

      n = abs_size
      new_size = n + whole_limbs + (bit_shift > 0 ? 1 : 0)
      result = BigInt.new(capacity: new_size)

      # Zero the bottom limbs
      whole_limbs.times { |i| result.@limbs[i] = 0_u64 }

      if bit_shift > 0
        carry = BigInt.limbs_lshift(result.@limbs + whole_limbs, @limbs, n, bit_shift)
        result.@limbs[whole_limbs + n] = carry
      else
        (result.@limbs + whole_limbs).copy_from(@limbs, n)
      end

      result.set_size(new_size)
      result.normalize!
      result.set_size(-result.@size) if negative?
      result
    end

    def >>(count : Int) : BigInt
      return self << (-count) if count < 0
      return dup_value if count == 0
      return BigInt.new if zero?

      whole_limbs = count.to_i32 // 64
      bit_shift = count.to_i32 % 64

      n = abs_size
      # If shifting away all limbs
      if whole_limbs >= n
        return negative? ? BigInt.new(-1) : BigInt.new
      end

      new_size = n - whole_limbs
      result = BigInt.new(capacity: new_size)

      if bit_shift > 0
        BigInt.limbs_rshift(result.@limbs, @limbs + whole_limbs, new_size, bit_shift)
      else
        result.@limbs.copy_from(@limbs + whole_limbs, new_size)
      end

      result.set_size(new_size)
      result.normalize!

      if negative?
        # Arithmetic right shift: if any shifted-out bits were set, subtract 1 from result
        # (equivalent to floor division by 2^count for negative numbers)
        lost_bits = false
        whole_limbs.times do |i|
          if @limbs[i] != 0
            lost_bits = true
            break
          end
        end
        if !lost_bits && bit_shift > 0
          mask = (1_u64 << bit_shift) &- 1
          lost_bits = (@limbs[whole_limbs] & mask) != 0
        end
        result.set_size(-result.@size) if result.@size != 0
        if lost_bits
          result = result - 1
        end
      end

      result
    end

    def unsafe_shr(count : Int) : self
      self >> count
    end

    def bit(index : Int) : Int32
      return 0 if index < 0
      limb_idx = index.to_i32 // 64
      bit_idx = index.to_i32 % 64

      if positive? || zero?
        return 0 if limb_idx >= abs_size
        (@limbs[limb_idx] >> bit_idx) & 1 == 1 ? 1 : 0
      else
        # Negative: two's complement is ~(|self| - 1)
        # bit of -x = 1 - bit_of(|x| - 1, index)
        # Compute (|self| - 1) bit without allocating a full BigInt
        # Walk limbs to find (magnitude - 1) at this position
        n = abs_size
        return 1 if limb_idx >= n # infinite sign extension

        # Compute the borrow chain for magnitude - 1
        borrow = 1_u64
        limb_val = 0_u64
        i = 0
        while i <= limb_idx
          diff = @limbs[i].to_u128 &- borrow.to_u128
          limb_val = diff.to_u64!
          borrow = (diff >> 127) != 0 ? 1_u64 : 0_u64
          i += 1
        end
        # bit of (|self| - 1) at this position
        orig_bit = (limb_val >> bit_idx) & 1
        # Complement it
        orig_bit == 1 ? 0 : 1
      end
    end

    def bit_length : Int32
      return 1 if zero?
      n = abs_size
      top = @limbs[n - 1]
      (n - 1) * 64 + (64 - top.leading_zeros_count.to_i32)
    end

    def popcount : Int
      return 0 if zero?
      # For negative numbers, two's complement has infinite 1-bits
      return UInt64::MAX if negative?
      count = 0
      abs_size.times { |i| count += @limbs[i].popcount }
      count
    end

    def trailing_zeros_count : Int
      return 0 if zero?
      n = abs_size
      i = 0
      while i < n
        if @limbs[i] != 0
          return i * 64 + @limbs[i].trailing_zeros_count.to_i32
        end
        i += 1
      end
      0
    end

    def &(other : BigInt) : BigInt
      bitwise_op(other, :and)
    end

    def &(other : Int) : BigInt
      self & BigInt.new(other)
    end

    def |(other : BigInt) : BigInt
      bitwise_op(other, :or)
    end

    def |(other : Int) : BigInt
      self | BigInt.new(other)
    end

    def ^(other : BigInt) : BigInt
      bitwise_op(other, :xor)
    end

    def ^(other : Int) : BigInt
      self ^ BigInt.new(other)
    end

    # --- Number Theory ---

    def gcd(other : BigInt) : BigInt
      a = self.abs
      b = other.abs
      return b if a.zero?
      return a if b.zero?

      # Binary GCD (Stein's algorithm): uses only shifts and subtractions
      a_shift = a.trailing_zeros_count.to_i32
      b_shift = b.trailing_zeros_count.to_i32
      k = Math.min(a_shift, b_shift)  # common factor of 2
      a = a >> a_shift
      b = b >> b_shift

      loop do
        # Both a and b are odd here
        cmp = a <=> b
        break if cmp == 0
        if cmp > 0
          a, b = b, a
        end
        # a <= b, both odd, so b - a is even and positive
        b = b - a
        break if b.zero?
        b = b >> b.trailing_zeros_count.to_i32
      end

      a << k
    end

    def gcd(other : Int) : Int
      gcd(BigInt.new(other)).to_i64
    end

    def lcm(other : BigInt) : BigInt
      return BigInt.new if zero? || other.zero?
      g = gcd(other)
      (self // g * other).abs
    end

    def lcm(other : Int) : BigInt
      lcm(BigInt.new(other))
    end

    def factorial : BigInt
      raise ArgumentError.new("Factorial of negative number") if negative?
      n = to_i64
      result = BigInt.new(1)
      i = 2_i64
      while i <= n
        result = result * i
        i += 1
      end
      result
    end

    def divisible_by?(number : BigInt) : Bool
      (self % number).zero?
    end

    def divisible_by?(number : Int) : Bool
      (self % number).zero?
    end

    def root(n : Int) : BigInt
      raise ArgumentError.new("Zeroth root is undefined") if n == 0
      if negative?
        raise ArgumentError.new("Even root of negative number") if n.even?
        return -((-self).root(n))
      end
      return BigInt.new if zero?
      return dup_value if n == 1
      return sqrt if n == 2

      # Newton's method for integer nth root
      # x_{k+1} = ((n-1)*x_k + self // x_k^(n-1)) // n
      bn = BigInt.new(n)
      bn1 = BigInt.new(n - 1)
      x = BigInt.new(1) << ((bit_length + n - 1) // n)
      loop do
        xn1 = x ** (n - 1)
        x1 = (bn1 * x + self // xn1) // bn
        break if x1 >= x
        x = x1
      end
      x
    end

    def sqrt : BigInt
      raise ArgumentError.new("Square root of negative number") if negative?
      return BigInt.new if zero?
      return BigInt.new(1) if abs_size == 1 && @limbs[0] == 1_u64

      # Newton's method
      x = BigInt.new(1) << ((bit_length + 1) // 2)
      loop do
        x1 = (x + self // x) >> 1
        break if x1 >= x
        x = x1
      end
      x
    end

    def prime? : Bool
      # Quick checks without allocations
      if abs_size <= 1
        v = zero? ? 0_u64 : @limbs[0]
        v = 0_u64 if negative?
        return false if v <= 1
        return true if v == 2 || v == 3
        return false if v.even?
        return false if v % 3 == 0
      else
        return false if negative?
        return false if even?
        return false if divisible_by?(3)
      end

      # Write self-1 = 2^r * d
      one = BigInt.new(1)
      self_minus_1 = self - one
      r = self_minus_1.trailing_zeros_count.to_i32
      d = self_minus_1 >> r

      two = BigInt.new(2)

      # Deterministic witnesses sufficient for numbers < 3.3e24
      witnesses = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]

      witnesses.each do |a_int|
        a = BigInt.new(a_int)
        next if a >= self
        x = a.pow_mod(d, self)
        next if (x.abs_size == 1 && x.@limbs[0] == 1_u64 && !x.negative?) || x == self_minus_1
        found = false
        (r - 1).times do
          x = x.pow_mod(two, self)
          if x == self_minus_1
            found = true
            break
          end
        end
        return false unless found
      end
      true
    end

    # --- Conversion ---

    def to_bytes(big_endian : Bool = true) : Bytes
      raise ArgumentError.new("Cannot convert negative BigInt to bytes") if negative?
      if zero?
        return Bytes.new(1, 0_u8)
      end

      n = abs_size
      # Total bytes needed
      top_limb = @limbs[n - 1]
      top_bytes = (64 - top_limb.leading_zeros_count.to_i32 + 7) // 8
      total = (n - 1) * 8 + top_bytes
      bytes = Bytes.new(total)

      # Write in little-endian limb order first, then reverse if big_endian
      pos = 0
      (n - 1).times do |i|
        limb = @limbs[i]
        8.times do |b|
          bytes[pos] = (limb >> (b * 8)).to_u8!
          pos += 1
        end
      end
      # Top limb (only top_bytes bytes)
      top_bytes.times do |b|
        bytes[pos] = (top_limb >> (b * 8)).to_u8!
        pos += 1
      end

      if big_endian
        bytes.reverse!
      end
      bytes
    end

    def self.from_bytes(bytes : Bytes, big_endian : Bool = true) : BigInt
      # Strip leading zeros
      start = 0
      if big_endian
        while start < bytes.size - 1 && bytes[start] == 0
          start += 1
        end
      else
        last = bytes.size - 1
        while last > 0 && bytes[last] == 0
          last -= 1
        end
        # Work with a trimmed slice
        bytes = bytes[0..last]
        start = 0
      end

      effective = big_endian ? bytes[start..] : bytes[start..]
      return BigInt.new if effective.size == 1 && effective[0] == 0

      n_limbs = (effective.size + 7) // 8
      result = BigInt.new
      result.ensure_capacity(n_limbs)

      n_limbs.times do |li|
        limb = 0_u64
        8.times do |b|
          byte_idx = if big_endian
                       effective.size - 1 - (li * 8 + b)
                     else
                       li * 8 + b
                     end
          break if byte_idx < 0 || byte_idx >= effective.size
          limb |= effective[byte_idx].to_u64 << (b * 8)
        end
        result.@limbs[li] = limb
      end
      result.set_size(n_limbs)
      result.normalize!
      result
    end

    def to_s : String
      to_s(10)
    end

    def to_s(base : Int = 10, *, precision : Int = 1, upcase : Bool = false) : String
      String.build do |io|
        to_s(io, base, precision: precision, upcase: upcase)
      end
    end

    def to_s(io : IO) : Nil
      to_s(io, 10)
    end

    DC_TO_S_THRESHOLD = 50

    def to_s(io : IO, base : Int = 10, *, precision : Int = 1, upcase : Bool = false) : Nil
      raise ArgumentError.new("Invalid base #{base}") unless 2 <= base <= 36
      if zero?
        io << '-' if @size < 0
        pad = Math.max(precision.to_i32, 1)
        pad.times { io << '0' }
        return
      end
      io << '-' if negative?

      n = abs_size
      if n == 1 && precision <= 1
        # Single-limb fast path: use Crystal's built-in integer-to-string
        s = @limbs[0].to_s(base)
        io << (upcase ? s.upcase : s)
      elsif n >= DC_TO_S_THRESHOLD
        BigInt.dc_to_s(io, @limbs, n, base.to_i32, precision.to_i32, upcase)
      else
        BigInt.simple_to_s(io, @limbs, n, base.to_i32, precision.to_i32, upcase)
      end
    end

    # Simple O(n²) base conversion for small numbers.
    # Extracts digits in chunks for efficiency: divide by base^chunk_size to get
    # chunk_size digits at once, then extract individual digits from the remainder.
    protected def self.simple_to_s(io : IO, limbs : Pointer(Limb), size : Int32, base : Int32, precision : Int32, upcase : Bool)
      tmp = Pointer(Limb).malloc(size)
      tmp.copy_from(limbs, size)
      tmp_size = size

      chunk_size, chunk_base = chunk_params(base)

      # Pre-allocate digit buffer
      max_digits = (size.to_f64 * 64.0 * Math.log(2.0) / Math.log(base.to_f64)).to_i32 + 2
      max_digits = Math.max(max_digits, precision)
      buf = Pointer(UInt8).malloc(max_digits)
      pos = max_digits - 1

      while tmp_size > 0
        # Extract chunk_size digits at once by dividing by chunk_base
        rem = limbs_div_rem_1(tmp, tmp, tmp_size, chunk_base)
        while tmp_size > 0 && tmp[tmp_size - 1] == 0
          tmp_size -= 1
        end
        # Extract individual digits from rem
        if tmp_size > 0
          # Not the last chunk — emit exactly chunk_size digits (with leading zeros)
          chunk_size.times do
            buf[pos] = (rem % base.to_u64).to_u8
            rem = rem // base.to_u64
            pos -= 1
          end
        else
          # Last chunk — only emit significant digits
          while rem > 0 && pos >= 0
            buf[pos] = (rem % base.to_u64).to_u8
            rem = rem // base.to_u64
            pos -= 1
          end
        end
      end

      # Fill leading zeros for precision
      while (max_digits - 1 - pos) < precision
        buf[pos] = 0_u8
        pos -= 1
      end

      start = pos + 1
      i = start
      while i < max_digits
        c = digit_to_char(buf[i])
        io << (upcase ? c.upcase : c)
        i += 1
      end
    end

    # Divide-and-conquer base conversion: O(n·log²n).
    # Precomputes powers of base, splits number in half, converts each half recursively.
    protected def self.dc_to_s(io : IO, limbs : Pointer(Limb), size : Int32, base : Int32, precision : Int32, upcase : Bool)
      # Estimate digit count: digits ≈ bit_length * log(2)/log(base)
      top = limbs[size - 1]
      bit_len = (size - 1) * 64 + (64 - top.leading_zeros_count.to_i32)
      est_digits = (bit_len.to_f64 * Math.log(2.0) / Math.log(base.to_f64)).to_i32 + 2

      # Precompute base powers: powers[i] = base^(chunk * 2^i) where chunk = chunk_params digits
      powers = precompute_base_powers(base, est_digits)

      # Allocate digit buffer (filled right-to-left with leading zeros)
      buf = Pointer(UInt8).malloc(est_digits)
      buf_len = est_digits
      est_digits.times { |i| buf[i] = 0_u8 }

      # Copy limbs into a working BigInt
      num = BigInt.new(capacity: size)
      num.@limbs.copy_from(limbs, size)
      num.set_size(size)

      # Recursively fill buffer
      dc_to_s_recurse(buf, buf_len, num, base, powers, powers.size - 1)

      # Skip leading zeros (but respect precision)
      start = 0
      while start < buf_len - 1 && buf[start] == 0 && (buf_len - start) > precision
        start += 1
      end

      i = start
      while i < buf_len
        c = digit_to_char((buf + i).value)
        io << (upcase ? c.upcase : c)
        i += 1
      end
    end

    # Precompute powers: base^1, base^2, base^4, base^8, ... by repeated squaring
    # Each power[i] splits off 2^i * chunk_size digits from the number.
    protected def self.precompute_base_powers(base : Int32, max_digits : Int32) : Array(BigInt)
      chunk_size, _ = chunk_params(base)
      powers = [] of BigInt
      # power[0] = base^chunk_size
      p = BigInt.new(base) ** chunk_size
      powers << p
      digits_covered = chunk_size
      while digits_covered * 2 < max_digits
        p = p * p
        powers << p
        digits_covered *= 2
      end
      powers
    end

    # Recursively convert num into buf[0..buf_len-1].
    # level is the current power table index to split at.
    protected def self.dc_to_s_recurse(buf : Pointer(UInt8), buf_len : Int32, num : BigInt, base : Int32, powers : Array(BigInt), level : Int32)
      # Base case: small enough for batch digit extraction
      if level < 0 || num.abs_size < DC_TO_S_THRESHOLD
        n = num.abs_size
        return if n == 0 # buf already zero-filled

        chunk_size, chunk_base = chunk_params(base)
        tmp = Pointer(Limb).malloc(n)
        tmp.copy_from(num.@limbs, n)
        tmp_size = n
        pos = buf_len - 1

        while tmp_size > 0 && pos >= 0
          # Extract chunk_size digits at once
          rem = limbs_div_rem_1(tmp, tmp, tmp_size, chunk_base)
          while tmp_size > 0 && tmp[tmp_size - 1] == 0
            tmp_size -= 1
          end
          if tmp_size > 0
            # Not the last chunk: emit exactly chunk_size digits
            chunk_size.times do
              break if pos < 0
              buf[pos] = (rem % base.to_u64).to_u8
              rem = rem // base.to_u64
              pos -= 1
            end
          else
            # Last chunk: only significant digits
            while rem > 0 && pos >= 0
              buf[pos] = (rem % base.to_u64).to_u8
              rem = rem // base.to_u64
              pos -= 1
            end
          end
        end
        return
      end

      divisor = powers[level]
      # If num < divisor, skip this level
      if num.abs_size < divisor.abs_size || (num.abs_size == divisor.abs_size && limbs_cmp(num.@limbs, num.abs_size, divisor.@limbs, divisor.abs_size) < 0)
        dc_to_s_recurse(buf, buf_len, num, base, powers, level - 1)
        return
      end

      # Split: num = hi * divisor + lo
      hi, lo = num.tdiv_rem(divisor)

      # The divisor covers chunk_size * 2^level digits → that's the size of the lower half
      chunk_size, _ = chunk_params(base)
      lo_digits = chunk_size * (1 << level)
      if lo_digits > buf_len
        lo_digits = buf_len
      end
      hi_digits = buf_len - lo_digits

      # Recurse on each half
      dc_to_s_recurse(buf, hi_digits, hi, base, powers, level - 1)
      dc_to_s_recurse(buf + hi_digits, lo_digits, lo, base, powers, level - 1)
    end

    def inspect(io : IO) : Nil
      to_s(io, 10)
    end

    # --- Checked integer conversions ---

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

    {% for info in [{Int8, "i8"}, {Int16, "i16"}, {Int32, "i32"}, {Int64, "i64"}, {Int128, "i128"}] %}
      def to_{{info[1].id}} : {{info[0]}}
        val = to_i128_internal
        if val < {{info[0]}}::MIN.to_i128 || val > {{info[0]}}::MAX.to_i128
          raise OverflowError.new("BigInt too large for {{info[0]}}")
        end
        val.to_{{info[1].id}}!
      end

      def to_{{info[1].id}}! : {{info[0]}}
        return {{info[0]}}.new(0) if zero?
        {% if info[1] == "i128" %}
          to_i128_internal.to_i128!
        {% else %}
          val = @limbs[0].to_{{info[1].id}}!
          negative? ? (0.to_{{info[1].id}}! &- val) : val
        {% end %}
      end
    {% end %}

    {% for info in [{UInt8, "u8"}, {UInt16, "u16"}, {UInt32, "u32"}, {UInt64, "u64"}, {UInt128, "u128"}] %}
      def to_{{info[1].id}} : {{info[0]}}
        raise OverflowError.new("Negative BigInt") if negative?
        val = to_u128_internal
        if val > {{info[0]}}::MAX.to_u128
          raise OverflowError.new("BigInt too large for {{info[0]}}")
        end
        val.to_{{info[1].id}}!
      end

      def to_{{info[1].id}}! : {{info[0]}}
        return {{info[0]}}.new(0) if zero?
        {% if info[1] == "u128" %}
          to_u128_internal.to_u128!
        {% else %}
          val = @limbs[0].to_{{info[1].id}}!
          negative? ? (0.to_{{info[1].id}}! &- val) : val
        {% end %}
      end
    {% end %}

    def to_f : Float64
      to_f64
    end

    def to_f! : Float64
      to_f64
    end

    def to_f32 : Float32
      to_f64.to_f32
    end

    def to_f32! : Float32
      to_f64.to_f32
    end

    def to_f64 : Float64
      return 0.0 if zero?
      n = abs_size
      if n == 1
        return negative? ? -@limbs[0].to_f64 : @limbs[0].to_f64
      end
      # Use top 2 limbs + exponent for correct rounding at any size.
      # Float64 has 53 bits of mantissa; 2 limbs = 128 bits is more than enough.
      hi = @limbs[n - 1].to_f64
      lo = @limbs[n - 2].to_f64
      # hi * 2^64 + lo, then shift by the remaining limbs
      result = hi * (UInt64::MAX.to_f64 + 1.0) + lo
      # Scale by 2^(64*(n-2)) for the lower limbs we skipped
      exp = (n - 2) * 64
      result = result * 2.0 ** exp
      negative? ? -result : result
    end

    def to_f64! : Float64
      to_f64
    end

    def to_big_i : BigInt
      self
    end

    def to_big_f(*, precision : Int32 = BigFloat.default_precision) : BigFloat
      BigFloat.new(self, precision: precision)
    end

    def to_big_r : BigRational
      BigRational.new(self)
    end

    def to_big_d : BigDecimal
      BigDecimal.new(self)
    end

    def digits(base : Int = 10) : Array(Int32)
      raise ArgumentError.new("Can't request digits of negative number") if negative?
      raise ArgumentError.new("Invalid base #{base}") unless base >= 2
      return [0] if zero?

      result = [] of Int32
      tmp = dup_value
      b = BigInt.new(base)
      while !tmp.zero?
        q, r = tmp.tdiv_rem(b)
        result << r.to_i32
        tmp = q
      end
      result
    end

    # --- Misc ---

    def next_power_of_two : BigInt
      return BigInt.new(1) if @size <= 0
      popcount == 1 ? dup_value : BigInt.new(1) << bit_length
    end

    def factor_by(number : Int) : {BigInt, UInt64}
      raise ArgumentError.new("Can't factor by #{number}") if number <= 1
      d = BigInt.new(number)
      count = 0_u64
      current = self.abs
      while !current.zero?
        q, r = current.tdiv_rem(d)
        break unless r.zero?
        current = q
        count += 1
      end
      {current, count}
    end

    def clone : BigInt
      dup_value
    end

    # --- Protected helpers exposed to other BigInt methods ---

    protected def initialize(*, capacity : Int32)
      @limbs = Pointer(Limb).malloc(capacity)
      @alloc = capacity
      @size = 0
    end

    protected def set_size(@size : Int32)
    end

    protected def limbs_ptr : Pointer(Limb)
      @limbs
    end

    protected def negate!
      @size = -@size
    end

    protected def abs!
      @size = abs_size
    end

    protected def ensure_capacity(n : Int32)
      return if @alloc >= n
      new_alloc = Math.max(n, @alloc * 2)
      new_alloc = Math.max(new_alloc, 1)
      new_limbs = Pointer(Limb).malloc(new_alloc)
      if @alloc > 0 && !@limbs.null?
        new_limbs.copy_from(@limbs, abs_size)
      end
      @limbs = new_limbs
      @alloc = new_alloc
    end

    protected def normalize!
      n = @size < 0 ? -@size : @size
      while n > 0 && @limbs[n - 1] == 0
        n -= 1
      end
      @size = @size < 0 ? -n : n
    end

    protected def dup_value : BigInt
      n = abs_size
      return BigInt.new if n == 0
      result = BigInt.new(capacity: n)
      result.@limbs.copy_from(@limbs, n)
      result.set_size(@size)
      result
    end

    # --- Private ---

    private def to_i128_internal : Int128
      return 0_i128 if zero?
      n = abs_size
      val = @limbs[0].to_u128
      val |= @limbs[1].to_u128 << 64 if n >= 2
      negative? ? (0_i128 &- val.to_i128!) : val.to_i128!
    end

    private def to_u128_internal : UInt128
      return 0_u128 if zero?
      n = abs_size
      val = @limbs[0].to_u128
      val |= @limbs[1].to_u128 << 64 if n >= 2
      val
    end

    # Bitwise operation on two BigInts with two's complement semantics.
    # For negative x, two's complement is ~(|x| - 1).
    # We case-split on signs to avoid allocating two's complement arrays.
    private def bitwise_op(other : BigInt, op : Symbol) : BigInt
      # Both positive: direct limb-by-limb
      if !negative? && !other.negative?
        return bitwise_pos_pos(other, op)
      end

      # Use the identity: -x in two's complement = ~(x-1)
      # Convert to two's complement, apply op, convert back.
      #
      # Result sign (from infinite sign bits):
      # AND: neg only if both neg
      # OR:  neg if either neg
      # XOR: neg if exactly one neg
      result_negative = case op
                         when :and then negative? && other.negative?
                         when :or  then negative? || other.negative?
                         when :xor then negative? ^ other.negative?
                         else           false
                         end

      an = abs_size
      bn = other.abs_size
      max_n = Math.max(an, bn) + 1 # +1 for possible carry

      # Build two's complement limb arrays for each operand
      a_tc = Pointer(Limb).malloc(max_n)
      b_tc = Pointer(Limb).malloc(max_n)

      fill_twos_complement(a_tc, max_n)
      other.fill_twos_complement(b_tc, max_n)

      # Apply operation limb-by-limb
      r_tc = Pointer(Limb).malloc(max_n)
      max_n.times do |i|
        r_tc[i] = case op
                  when :and then a_tc[i] & b_tc[i]
                  when :or  then a_tc[i] | b_tc[i]
                  when :xor then a_tc[i] ^ b_tc[i]
                  else           0_u64
                  end
      end

      # Convert result back from two's complement
      result = BigInt.new(capacity: max_n)
      if result_negative
        # Result is negative: r_tc is two's complement of magnitude
        # magnitude = ~r_tc + 1 (negate two's complement)
        max_n.times { |i| r_tc[i] = ~r_tc[i] }
        # Add 1
        carry = 1_u64
        max_n.times do |i|
          sum = r_tc[i].to_u128 &+ carry.to_u128
          r_tc[i] = sum.to_u64!
          carry = (sum >> 64).to_u64!
        end
        result.@limbs.copy_from(r_tc, max_n)
        result.set_size(-max_n)
        result.normalize!
      else
        result.@limbs.copy_from(r_tc, max_n)
        result.set_size(max_n)
        result.normalize!
      end
      result
    end

    private def bitwise_pos_pos(other : BigInt, op : Symbol) : BigInt
      an = abs_size
      bn = other.abs_size
      max_n = Math.max(an, bn)
      result = BigInt.new(capacity: max_n)
      max_n.times do |i|
        a_limb = i < an ? @limbs[i] : 0_u64
        b_limb = i < bn ? other.@limbs[i] : 0_u64
        result.@limbs[i] = case op
                           when :and then a_limb & b_limb
                           when :or  then a_limb | b_limb
                           when :xor then a_limb ^ b_limb
                           else           0_u64
                           end
      end
      result.set_size(max_n)
      result.normalize!
      result
    end

    # Fill buffer with two's complement representation of self, padded to n limbs.
    # Positive: just copy magnitude, zero-extend.
    # Negative: ~(|self| - 1), sign-extend with 0xFF..FF.
    protected def fill_twos_complement(buf : Pointer(Limb), n : Int32)
      an = abs_size
      if !negative?
        an.times { |i| buf[i] = @limbs[i] }
        (an...n).each { |i| buf[i] = 0_u64 }
      else
        # Compute ~(magnitude - 1)
        # First: magnitude - 1
        borrow = 1_u64
        an.times do |i|
          diff = @limbs[i].to_u128 &- borrow.to_u128
          buf[i] = ~diff.to_u64!
          borrow = (diff >> 127) != 0 ? 1_u64 : 0_u64
        end
        # Sign extend
        (an...n).each { |i| buf[i] = Limb::MAX }
      end
    end

    private def set_from_unsigned(mag : UInt128)
      lo = mag.to_u64!
      hi = (mag >> 64).to_u64!
      if hi != 0
        ensure_capacity(2)
        @limbs[0] = lo
        @limbs[1] = hi
        @size = 2
      elsif lo != 0
        ensure_capacity(1)
        @limbs[0] = lo
        @size = 1
      end
    end

    protected def add_magnitudes(other : BigInt, result_negative : Bool = @size < 0) : BigInt
      an = abs_size
      bn = other.abs_size
      ap = @limbs
      bp = other.@limbs
      # Ensure an >= bn for the add
      if an < bn
        an, bn = bn, an
        ap, bp = bp, ap
      end
      result = BigInt.new(capacity: an + 1)
      carry = BigInt.limbs_add(result.@limbs, ap, an, bp, bn)
      if carry != 0
        result.@limbs[an] = carry
        result.set_size(an + 1)
      else
        result.set_size(an)
      end
      if result_negative
        result.set_size(-result.@size)
      end
      result.normalize!
      result
    end

    private def sub_magnitudes(other : BigInt) : BigInt
      an = abs_size
      bn = other.abs_size
      cmp = BigInt.limbs_cmp(@limbs, an, other.@limbs, bn)
      if cmp == 0
        return BigInt.new # equal magnitudes = zero
      end
      if cmp > 0
        # |self| > |other|
        result = BigInt.new(capacity: an)
        BigInt.limbs_sub(result.@limbs, @limbs, an, other.@limbs, bn)
        result.set_size(an)
        result.set_size(-result.@size) if @size < 0
      else
        # |self| < |other|
        result = BigInt.new(capacity: bn)
        BigInt.limbs_sub(result.@limbs, other.@limbs, bn, @limbs, an)
        result.set_size(bn)
        result.set_size(-result.@size) if @size >= 0
      end
      result.normalize!
      result
    end

    # --- Class-level limb array operations ---

    # Compare two unsigned limb arrays. Returns -1, 0, or 1.
    protected def self.limbs_cmp(ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32) : Int32
      return 1 if an > bn
      return -1 if an < bn
      i = an - 1
      while i >= 0
        return 1 if ap[i] > bp[i]
        return -1 if ap[i] < bp[i]
        i -= 1
      end
      0
    end

    # Add two unsigned limb arrays. an >= bn. Returns carry (0 or 1).
    protected def self.limbs_add(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32) : Limb
      carry = 0_u64
      i = 0
      while i < bn
        sum = ap[i].to_u128 &+ bp[i].to_u128 &+ carry.to_u128
        rp[i] = sum.to_u64!
        carry = (sum >> 64).to_u64!
        i += 1
      end
      while i < an
        sum = ap[i].to_u128 &+ carry.to_u128
        rp[i] = sum.to_u64!
        carry = (sum >> 64).to_u64!
        i += 1
      end
      carry
    end

    # Subtract two unsigned limb arrays. ap >= bp (magnitude). an >= bn. Returns borrow.
    protected def self.limbs_sub(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32) : Limb
      borrow = 0_u64
      i = 0
      while i < bn
        b1 = ap[i] < bp[i] ? 1_u64 : 0_u64
        d = ap[i] &- bp[i]
        b2 = d < borrow ? 1_u64 : 0_u64
        rp[i] = d &- borrow
        borrow = b1 &+ b2
        i += 1
      end
      while i < an
        b = ap[i] < borrow ? 1_u64 : 0_u64
        rp[i] = ap[i] &- borrow
        borrow = b
        i += 1
      end
      borrow
    end

    # Add a single limb to a limb array. Returns carry.
    protected def self.limbs_add_1(rp : Pointer(Limb), ap : Pointer(Limb), n : Int32, b : Limb) : Limb
      carry = b.to_u128
      i = 0
      while i < n
        sum = ap[i].to_u128 &+ carry
        rp[i] = sum.to_u64!
        carry = sum >> 64
        i += 1
      end
      carry.to_u64!
    end

    # Multiply a limb array by a single limb. Returns carry.
    protected def self.limbs_mul_1(rp : Pointer(Limb), ap : Pointer(Limb), n : Int32, b : Limb) : Limb
      carry = 0_u128
      i = 0
      while i < n
        prod = ap[i].to_u128 &* b.to_u128 &+ carry
        rp[i] = prod.to_u64!
        carry = prod >> 64
        i += 1
      end
      carry.to_u64!
    end

    # rp[] += ap[] * b. Returns carry out.
    protected def self.limbs_addmul_1(rp : Pointer(Limb), ap : Pointer(Limb), n : Int32, b : Limb) : Limb
      carry = 0_u128
      i = 0
      while i < n
        prod = ap[i].to_u128 &* b.to_u128 &+ rp[i].to_u128 &+ carry
        rp[i] = prod.to_u64!
        carry = prod >> 64
        i += 1
      end
      carry.to_u64!
    end

    # rp[] -= ap[] * b. Returns borrow out.
    protected def self.limbs_submul_1(rp : Pointer(Limb), ap : Pointer(Limb), n : Int32, b : Limb) : Limb
      borrow = 0_u128
      i = 0
      while i < n
        prod = ap[i].to_u128 &* b.to_u128 &+ borrow
        if rp[i].to_u128 >= prod.to_u64!.to_u128
          rp[i] = rp[i] &- prod.to_u64!
          borrow = prod >> 64
        else
          old = rp[i]
          rp[i] = rp[i] &- prod.to_u64!
          borrow = (prod >> 64) &+ 1
        end
        i += 1
      end
      borrow.to_u64!
    end

    KARATSUBA_THRESHOLD = 32
    TOOM3_THRESHOLD     = 90

    # Top-level multiply dispatch. an >= bn > 0. rp must not alias ap or bp.
    protected def self.limbs_mul(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32)
      if bn < KARATSUBA_THRESHOLD
        limbs_mul_schoolbook(rp, ap, an, bp, bn)
      elsif bn < TOOM3_THRESHOLD
        scratch = Pointer(Limb).malloc(karatsuba_scratch_size(an))
        limbs_mul_karatsuba(rp, ap, an, bp, bn, scratch)
      else
        scratch = Pointer(Limb).malloc(toom3_scratch_size(an))
        limbs_mul_toom3(rp, ap, an, bp, bn, scratch)
      end
    end

    # Schoolbook multiply: O(an*bn).
    protected def self.limbs_mul_schoolbook(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32)
      (an + bn).times { |i| rp[i] = 0_u64 }
      i = 0
      while i < bn
        carry = limbs_addmul_1(rp + i, ap, an, bp[i])
        rp[i + an] = carry
        i += 1
      end
    end

    # Karatsuba multiply: O(n^1.585).
    # rp must have space for an+bn limbs. scratch must have karatsuba_scratch_size(an) limbs.
    protected def self.limbs_mul_karatsuba(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32, scratch : Pointer(Limb))
      if bn < KARATSUBA_THRESHOLD
        limbs_mul_schoolbook(rp, ap, an, bp, bn)
        return
      end

      if an >= 2 * bn
        limbs_mul_unbalanced(rp, ap, an, bp, bn, scratch)
        return
      end

      # Split: a = a1*B^m + a0, b = b1*B^m + b0
      m = bn >> 1
      a0 = ap;       a0n = m
      a1 = ap + m;   a1n = an - m
      b0 = bp;       b0n = m
      b1 = bp + m;   b1n = bn - m

      # z0 = a0 * b0 → rp[0..2m-1]
      limbs_mul_karatsuba(rp, a0, a0n, b0, b0n, scratch)

      # Zero upper part of rp
      i = 2 * m
      while i < an + bn
        rp[i] = 0_u64
        i += 1
      end

      # z2 = a1 * b1 → rp[2m..]
      limbs_mul_karatsuba(rp + 2 * m, a1, a1n, b1, b1n, scratch)

      # z1 = (a0+a1)*(b0+b1) - z0 - z2
      # Layout in scratch: [t1 (m+2) | t2 (m+2) | t3 (2m+4) | recursive scratch]
      t1 = scratch
      t1n = Math.max(a0n, a1n) + 1
      t2 = scratch + t1n
      t2n = Math.max(b0n, b1n) + 1

      # t1 = a0 + a1
      if a0n >= a1n
        t1[a0n] = limbs_add(t1, a0, a0n, a1, a1n)
      else
        t1[a1n] = limbs_add(t1, a1, a1n, a0, a0n)
      end
      actual_t1n = t1n
      while actual_t1n > 0 && t1[actual_t1n - 1] == 0
        actual_t1n -= 1
      end
      actual_t1n = 1 if actual_t1n == 0

      # t2 = b0 + b1
      if b0n >= b1n
        t2[b0n] = limbs_add(t2, b0, b0n, b1, b1n)
      else
        t2[b1n] = limbs_add(t2, b1, b1n, b0, b0n)
      end
      actual_t2n = t2n
      while actual_t2n > 0 && t2[actual_t2n - 1] == 0
        actual_t2n -= 1
      end
      actual_t2n = 1 if actual_t2n == 0

      # t3 = t1 * t2, placed after t1 and t2 in scratch
      t3 = scratch + t1n + t2n
      t3n = actual_t1n + actual_t2n
      next_scratch = t3 + t3n
      if actual_t1n >= actual_t2n
        limbs_mul_karatsuba(t3, t1, actual_t1n, t2, actual_t2n, next_scratch)
      else
        limbs_mul_karatsuba(t3, t2, actual_t2n, t1, actual_t1n, next_scratch)
      end
      while t3n > 0 && t3[t3n - 1] == 0
        t3n -= 1
      end

      # t3 -= z0
      z0n = a0n + b0n
      while z0n > 0 && rp[z0n - 1] == 0
        z0n -= 1
      end
      limbs_sub(t3, t3, t3n, rp, z0n) if z0n > 0 && t3n >= z0n

      # t3 -= z2
      z2n = a1n + b1n
      while z2n > 0 && rp[2 * m + z2n - 1] == 0
        z2n -= 1
      end
      limbs_sub(t3, t3, t3n, rp + 2 * m, z2n) if z2n > 0 && t3n >= z2n

      # Trim t3
      while t3n > 0 && t3[t3n - 1] == 0
        t3n -= 1
      end

      # Add t3 at position m
      if t3n > 0
        limbs_add(rp + m, rp + m, an + bn - m, t3, t3n)
      end
    end

    # Handle unbalanced multiply: an >= 2*bn. Slice a into bn-sized chunks.
    protected def self.limbs_mul_unbalanced(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32, scratch : Pointer(Limb))
      # Zero the result
      (an + bn).times { |i| rp[i] = 0_u64 }

      # Use scratch for the chunk product buffer (needs 2*bn limbs)
      tmp = scratch
      inner_scratch = scratch + 2 * bn

      offset = 0
      remaining = an
      while remaining > 0
        chunk = Math.min(remaining, bn)
        # Dispatch to best algorithm for this chunk size
        if chunk >= bn
          limbs_mul_dispatch(tmp, ap + offset, chunk, bp, bn, inner_scratch)
        else
          limbs_mul_dispatch(tmp, bp, bn, ap + offset, chunk, inner_scratch)
        end
        product_size = chunk + bn
        limbs_add(rp + offset, rp + offset, an + bn - offset, tmp, product_size)
        offset += chunk
        remaining -= chunk
      end
    end

    # Internal dispatch for recursive multiply (Karatsuba/Toom3 callers).
    # Assumes scratch is already allocated and large enough.
    protected def self.limbs_mul_dispatch(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32, scratch : Pointer(Limb))
      if bn < KARATSUBA_THRESHOLD
        limbs_mul_schoolbook(rp, ap, an, bp, bn)
      elsif bn < TOOM3_THRESHOLD
        limbs_mul_karatsuba(rp, ap, an, bp, bn, scratch)
      else
        limbs_mul_toom3(rp, ap, an, bp, bn, scratch)
      end
    end

    protected def self.karatsuba_scratch_size(n : Int32) : Int32
      # Each Karatsuba level needs ~4*(n/2+1) scratch plus recursive scratch.
      # S(n) = 4*(n/2+1) + S(n/2+1) ≈ 4n. Add 2*n for unbalanced multiply tmp buffer.
      Math.max(6 * n + 64, 256)
    end

    protected def self.toom3_scratch_size(n : Int32) : Int32
      # Toom-3 scratch layout (k = ceil(n/3), pn = 2*(k+1)):
      #   [w0 | w1 | wm1 | w2 | winf | ea | eb | interp_c2 | interp_t | interp_tmp8 | eval_tmp | recursive_scratch]
      #   5*pn + 2*(k+2) + 3*maxn + (k+2) + recursive
      # where maxn = 2*k+4.
      # Conservative: ~24n covers all buffers plus recursion.
      Math.max(24 * n + 512, 2048)
    end

    # Toom-Cook 3-way multiply: O(n^1.465).
    # Splits each operand into 3 pieces, evaluates at 5 points {0, 1, -1, 2, ∞},
    # does 5 recursive multiplications of ~n/3 size, then interpolates.
    # Requires an >= bn >= TOOM3_THRESHOLD. rp must have space for an+bn limbs.
    protected def self.limbs_mul_toom3(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32, scratch : Pointer(Limb))
      if bn < TOOM3_THRESHOLD
        if bn < KARATSUBA_THRESHOLD
          limbs_mul_schoolbook(rp, ap, an, bp, bn)
        else
          limbs_mul_karatsuba(rp, ap, an, bp, bn, scratch)
        end
        return
      end

      if an >= 3 * bn
        limbs_mul_unbalanced(rp, ap, an, bp, bn, scratch)
        return
      end

      # Split into thirds: k = ceil(an/3) so both operands fit in 3 pieces of size k.
      # Using bn would leave a2 with up to an-2*ceil(bn/3) limbs, which overflows buffers.
      k = (an + 2) // 3

      # a = a2*B^(2k) + a1*B^k + a0
      a0 = ap;           a0n = Math.min(k, an)
      a1 = ap + k;       a1n = Math.min(k, Math.max(an - k, 0))
      a2 = ap + 2 * k;   a2n = Math.max(an - 2 * k, 0)

      # b = b2*B^(2k) + b1*B^k + b0
      b0 = bp;           b0n = Math.min(k, bn)
      b1 = bp + k;       b1n = Math.min(k, Math.max(bn - k, 0))
      b2 = bp + 2 * k;   b2n = Math.max(bn - 2 * k, 0)

      # Normalize piece sizes (strip leading zeros) so limbs_cmp works correctly
      # in evaluation functions. Without this, pieces with trailing zeros in the
      # original number (e.g. 10^8192) would have inflated sizes.
      while a0n > 0 && a0[a0n - 1] == 0; a0n -= 1; end
      while a1n > 0 && a1[a1n - 1] == 0; a1n -= 1; end
      while a2n > 0 && a2[a2n - 1] == 0; a2n -= 1; end
      while b0n > 0 && b0[b0n - 1] == 0; b0n -= 1; end
      while b1n > 0 && b1[b1n - 1] == 0; b1n -= 1; end
      while b2n > 0 && b2[b2n - 1] == 0; b2n -= 1; end

      # We need 5 product buffers in scratch, each up to 2*(k+1) limbs.
      # Layout: [w0 | w1 | wm1 | w2 | winf | ea | eb | interp_c2 | interp_t | interp_tmp8 | eval_tmp | recursive_scratch]
      pn = 2 * (k + 1)  # max product size
      maxn = 2 * k + 4   # max coefficient size for interpolation
      w0   = scratch
      w1   = scratch + pn
      wm1  = scratch + 2 * pn
      w2   = scratch + 3 * pn
      winf = scratch + 4 * pn

      # Evaluation temporaries
      ea = scratch + 5 * pn                    # k+2 limbs for evaluating a
      eb = scratch + 5 * pn + (k + 2)         # k+2 limbs for evaluating b
      # Interpolation temporaries (carved from scratch, not heap-allocated)
      interp_c2  = scratch + 5 * pn + 2 * (k + 2)
      interp_t   = interp_c2 + maxn
      interp_tmp = interp_t + maxn             # used for 8*winf and eval_at2 temp
      rec_scratch = interp_tmp + maxn

      # --- Evaluate at point 0: a(0) = a0, b(0) = b0 ---
      # W(0) = a0 * b0
      if a0n > 0 && b0n > 0
        toom3_mul_recurse(w0, a0, a0n, b0, b0n, rec_scratch)
        w0n = a0n + b0n
        while w0n > 0 && w0[w0n - 1] == 0; w0n -= 1; end
      else
        w0[0] = 0_u64
        w0n = 0
      end

      # --- Evaluate at point ∞: a(∞) = a2, b(∞) = b2 ---
      # W(∞) = a2 * b2
      if a2n > 0 && b2n > 0
        toom3_mul_recurse(winf, a2, a2n, b2, b2n, rec_scratch)
        winfn = a2n + b2n
        while winfn > 0 && winf[winfn - 1] == 0; winfn -= 1; end
      else
        winf[0] = 0_u64
        winfn = 0
      end

      # --- Evaluate at point 1: a(1) = a0+a1+a2, b(1) = b0+b1+b2 ---
      ean = toom3_eval_pos(ea, a0, a0n, a1, a1n, a2, a2n)
      ebn = toom3_eval_pos(eb, b0, b0n, b1, b1n, b2, b2n)
      toom3_mul_recurse(w1, ea, ean, eb, ebn, rec_scratch)
      w1n = ean + ebn
      while w1n > 0 && w1[w1n - 1] == 0; w1n -= 1; end

      # --- Evaluate at point -1: a(-1) = a0-a1+a2, b(-1) = b0-b1+b2 ---
      ea_neg = false
      eb_neg = false
      ean, ea_neg = toom3_eval_neg(ea, a0, a0n, a1, a1n, a2, a2n)
      ebn, eb_neg = toom3_eval_neg(eb, b0, b0n, b1, b1n, b2, b2n)
      toom3_mul_recurse(wm1, ea, ean, eb, ebn, rec_scratch)
      wm1n = ean + ebn
      while wm1n > 0 && wm1[wm1n - 1] == 0; wm1n -= 1; end
      wm1_neg = ea_neg ^ eb_neg  # product is negative if exactly one eval was negative

      # --- Evaluate at point 2: a(2) = a0+2*a1+4*a2, b(2) = b0+2*b1+4*b2 ---
      ean = toom3_eval_at2(ea, a0, a0n, a1, a1n, a2, a2n, interp_tmp)
      ebn = toom3_eval_at2(eb, b0, b0n, b1, b1n, b2, b2n, interp_tmp)
      toom3_mul_recurse(w2, ea, ean, eb, ebn, rec_scratch)
      w2n = ean + ebn
      while w2n > 0 && w2[w2n - 1] == 0; w2n -= 1; end

      # --- Interpolation ---
      # We have: w0=W(0), w1=W(1), wm1=W(-1) (with sign), w2=W(2), winf=W(∞)
      # Need to recover r0..r4 where result = r0 + r1*B^k + r2*B^(2k) + r3*B^(3k) + r4*B^(4k)
      #
      # r0 = w0
      # r4 = winf
      # r3 = (w2 - w1) / 3 - (wm1_adj) ... using standard Toom-3 interpolation sequence
      #
      # Standard sequence (Bodrato & Zanoni):
      # 1. r3 = (w2 - wm1) / 3
      # 2. r1 = (w1 - wm1) / 2
      # 3. r2 = wm1 - w0   (using the sign-adjusted wm1)
      # ... actually let me use the standard formulation carefully.
      #
      # Let W0=w0, W1=w1, Wn=wm1 (with sign), W2=w2, Wi=winf
      # The interpolation matrix inversion gives:
      #   r0 = W0
      #   r4 = Wi
      #   r3 = (W2 - Wn) / 3          (then: r3 = (r3 - W1) / 2 + 2*Wi)  -- wait, standard formulation
      #
      # Using the well-known Toom-3 interpolation (from "Improved Toom-Cook" / GMP docs):
      #   Step 1: r3 = (w2 - wm1) / 3
      #   Step 2: r1 = (w1 - wm1) / 2
      #   Step 3: r2 = w1 - w0   (where w1 here is W(1), wm1 is signed W(-1))
      #   ... no, I need to be precise.
      #
      # Correct standard Toom-3 interpolation:
      #   Given: w0 = r0, w1 = r0+r1+r2+r3+r4, wm1 = r0-r1+r2-r3+r4,
      #          w2 = r0+2r1+4r2+8r3+16r4, winf = r4
      #
      #   1. w3 = (w2 - wm1) / 3       = 2*r1 + 4*r2 + (8+16/3)*... no
      #
      # Let me just use the concrete formulas:
      #   r0 = w0
      #   r4 = winf
      #   t1 = (w1 + wm1) / 2          = r0 + r2 + r4
      #   t2 = w1 - w0                  = r1 + r2 + r3 + r4
      #   t3 = (w2 - wm1) / 3          = r1 + r2*5/3... no...
      #
      # OK let me use the standard concrete sequence properly:
      #   r0 = w0
      #   r4 = winf
      #   Then define:
      #     w1 := w1 - w0              = r1 + r2 + r3 + r4
      #     w2 := w2 - wm1             = 2*(r1 + r2 + ... ) ... hmm
      #
      # I'll implement it step by step from the standard Toom-3 interpolation.

      toom3_interpolate(rp, an + bn, k, w0, w0n, w1, w1n, wm1, wm1n, wm1_neg, w2, w2n, winf, winfn, interp_c2, interp_t, interp_tmp)
    end

    # Evaluate p(1) = a0 + a1 + a2. Returns actual size of result in ea.
    protected def self.toom3_eval_pos(ea : Pointer(Limb), a0 : Pointer(Limb), a0n : Int32, a1 : Pointer(Limb), a1n : Int32, a2 : Pointer(Limb), a2n : Int32) : Int32
      # ea = a0 + a1
      if a0n >= a1n
        carry = a1n > 0 ? limbs_add(ea, a0, a0n, a1, a1n) : (a0n.times { |i| ea[i] = a0[i] }; 0_u64)
        ean = a0n
      else
        carry = limbs_add(ea, a1, a1n, a0, a0n)
        ean = a1n
      end
      ea[ean] = carry
      ean += 1 if carry != 0

      # ea += a2
      if a2n > 0
        if ean >= a2n
          carry2 = limbs_add(ea, ea, ean, a2, a2n)
        else
          carry2 = limbs_add(ea, a2, a2n, ea, ean)
          ean = a2n
        end
        ea[ean] = carry2
        ean += 1 if carry2 != 0
      end

      while ean > 1 && ea[ean - 1] == 0; ean -= 1; end
      ean = 1 if ean == 0
      ean
    end

    # Evaluate p(-1) = a0 - a1 + a2. Returns {size, negative}.
    protected def self.toom3_eval_neg(ea : Pointer(Limb), a0 : Pointer(Limb), a0n : Int32, a1 : Pointer(Limb), a1n : Int32, a2 : Pointer(Limb), a2n : Int32) : {Int32, Bool}
      # First compute t = a0 + a2
      if a0n >= a2n
        carry = a2n > 0 ? limbs_add(ea, a0, a0n, a2, a2n) : (a0n.times { |i| ea[i] = a0[i] }; 0_u64)
        tn = a0n
      else
        carry = limbs_add(ea, a2, a2n, a0, a0n)
        tn = a2n
      end
      ea[tn] = carry
      tn += 1 if carry != 0
      while tn > 1 && ea[tn - 1] == 0; tn -= 1; end

      # Now subtract a1: result = (a0 + a2) - a1
      neg = false
      if a1n == 0
        # result is just ea, positive
      else
        cmp = limbs_cmp(ea, tn, a1, a1n)
        if cmp >= 0
          limbs_sub(ea, ea, tn, a1, a1n)
        else
          # Need to compute a1 - (a0+a2), result is negative
          # Use ea as temp - we can overwrite since we're computing into ea
          limbs_sub(ea, a1, a1n, ea, tn)
          tn = a1n
          neg = true
        end
      end

      while tn > 1 && ea[tn - 1] == 0; tn -= 1; end
      tn = 1 if tn == 0
      {tn, neg}
    end

    # Evaluate p(2) = a0 + 2*a1 + 4*a2. Returns actual size.
    # Uses a small temp buffer to compute 2*a1 and 4*a2 cleanly.
    protected def self.toom3_eval_at2(ea : Pointer(Limb), a0 : Pointer(Limb), a0n : Int32, a1 : Pointer(Limb), a1n : Int32, a2 : Pointer(Limb), a2n : Int32, tmp : Pointer(Limb)) : Int32
      # Start with a0
      if a0n > 0
        a0n.times { |i| ea[i] = a0[i] }
        ean = a0n
      else
        ea[0] = 0_u64
        ean = 1
      end

      # Add 2*a1 using provided temp buffer
      if a1n > 0
        top = limbs_lshift(tmp, a1, a1n, 1)
        tmpn = a1n
        if top != 0; tmp[tmpn] = top; tmpn += 1; end
        if ean >= tmpn
          c = limbs_add(ea, ea, ean, tmp, tmpn)
        else
          c = limbs_add(ea, tmp, tmpn, ea, ean)
          ean = tmpn
        end
        if c != 0; ea[ean] = c; ean += 1; end
      end

      # Add 4*a2
      if a2n > 0
        top = limbs_lshift(tmp, a2, a2n, 2)
        tmpn = a2n
        if top != 0; tmp[tmpn] = top; tmpn += 1; end
        if ean >= tmpn
          c = limbs_add(ea, ea, ean, tmp, tmpn)
        else
          c = limbs_add(ea, tmp, tmpn, ea, ean)
          ean = tmpn
        end
        if c != 0; ea[ean] = c; ean += 1; end
      end

      while ean > 1 && ea[ean - 1] == 0; ean -= 1; end
      ean = 1 if ean == 0
      ean
    end

    # Recursive multiply helper for Toom-3 evaluations.
    protected def self.toom3_mul_recurse(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32, scratch : Pointer(Limb))
      # Ensure an >= bn
      if an < bn
        ap, bp = bp, ap
        an, bn = bn, an
      end
      return if bn == 0 || an == 0
      if bn < KARATSUBA_THRESHOLD
        limbs_mul_schoolbook(rp, ap, an, bp, bn)
      elsif bn < TOOM3_THRESHOLD
        limbs_mul_karatsuba(rp, ap, an, bp, bn, scratch)
      else
        limbs_mul_toom3(rp, ap, an, bp, bn, scratch)
      end
    end

    # Toom-3 interpolation. Recovers coefficients c0..c4 and writes the final product to rp.
    #
    # Formulas (derived from inverting the 5-point evaluation matrix):
    #   c0 = w0
    #   c4 = winf
    #   c2 = (w1 + wm1)/2 - c0 - c4
    #   t  = (w1 - wm1)/2                  (= c1 + c3)
    #   c3 = ((w2 - w0)/2 - t - 2*c2 - 8*c4) / 3
    #   c1 = t - c3
    #
    # Result = c0 + c1*B^k + c2*B^(2k) + c3*B^(3k) + c4*B^(4k).
    protected def self.toom3_interpolate(rp : Pointer(Limb), rn : Int32,
                                          k : Int32,
                                          w0 : Pointer(Limb), w0n : Int32,
                                          w1 : Pointer(Limb), w1n : Int32,
                                          wm1 : Pointer(Limb), wm1n : Int32, wm1_neg : Bool,
                                          w2 : Pointer(Limb), w2n : Int32,
                                          winf : Pointer(Limb), winfn : Int32,
                                          c2 : Pointer(Limb), t : Pointer(Limb), tmp8 : Pointer(Limb))
      # c2, t, tmp8 are pre-allocated from scratch (each at least 2*k+4 limbs).
      maxn = 2 * k + 4

      # --- c2 = (w1 + wm1) / 2 - w0 - winf ---
      # w1 + signed_wm1: if wm1_neg, w1 + (-|wm1|) = w1 - |wm1|; else w1 + |wm1|
      # w1 + wm1 = 2*(c0 + c2 + c4), always non-negative.
      if wm1_neg
        c2n = w1n
        w1n.times { |i| c2[i] = w1[i] }
        limbs_sub(c2, c2, c2n, wm1, wm1n) if wm1n > 0
      else
        if w1n >= wm1n
          c = limbs_add(c2, w1, w1n, wm1, wm1n)
          c2n = w1n
        else
          c = limbs_add(c2, wm1, wm1n, w1, w1n)
          c2n = wm1n
        end
        if c != 0; c2[c2n] = c; c2n += 1; end
      end
      while c2n > 1 && c2[c2n - 1] == 0; c2n -= 1; end
      limbs_rshift(c2, c2, c2n, 1) if c2n > 0
      # Subtract w0
      if w0n > 0
        c2n = Math.max(c2n, w0n) if w0n > c2n
        limbs_sub(c2, c2, c2n, w0, w0n)
      end
      # Subtract winf
      if winfn > 0
        c2n = Math.max(c2n, winfn) if winfn > c2n
        limbs_sub(c2, c2, c2n, winf, winfn)
      end
      while c2n > 1 && c2[c2n - 1] == 0; c2n -= 1; end

      # --- t = (w1 - wm1) / 2 = c1 + c3 (always non-negative) ---
      if wm1_neg
        # w1 - (-|wm1|) = w1 + |wm1|
        if w1n >= wm1n
          c = limbs_add(t, w1, w1n, wm1, wm1n)
          tn = w1n
        else
          c = limbs_add(t, wm1, wm1n, w1, w1n)
          tn = wm1n
        end
        if c != 0; t[tn] = c; tn += 1; end
      else
        # w1 - |wm1|
        tn = w1n
        w1n.times { |i| t[i] = w1[i] }
        limbs_sub(t, t, tn, wm1, wm1n) if wm1n > 0
      end
      while tn > 1 && t[tn - 1] == 0; tn -= 1; end
      limbs_rshift(t, t, tn, 1)
      while tn > 1 && t[tn - 1] == 0; tn -= 1; end

      # --- c3 = ((w2 - w0) / 2 - t - 2*c2 - 8*winf) / 3 ---
      # Compute into w2 buffer (safe to overwrite now).
      # IMPORTANT: Do not trim c3n between operations. Aggressive trimming can make
      # c3n < subtrahend size, causing limbs_sub to read beyond valid data.
      c3 = w2
      c3n = w2n
      # c3 = w2 - w0
      limbs_sub(c3, c3, c3n, w0, w0n) if w0n > 0 && c3n >= w0n
      # c3 = c3 / 2
      limbs_rshift(c3, c3, c3n, 1) if c3n > 0
      # c3 -= t
      if tn > 0
        c3n = Math.max(c3n, tn) if tn > c3n
        limbs_sub(c3, c3, c3n, t, tn)
      end
      # c3 -= 2*c2
      if c2n > 0
        c3n = Math.max(c3n, c2n) if c2n > c3n
        limbs_sub(c3, c3, c3n, c2, c2n)
        limbs_sub(c3, c3, c3n, c2, c2n)
      end
      # c3 -= 8*winf
      if winfn > 0
        top = limbs_lshift(tmp8, winf, winfn, 3)
        tmp8n = winfn
        if top != 0; tmp8[tmp8n] = top; tmp8n += 1; end
        c3n = Math.max(c3n, tmp8n) if tmp8n > c3n
        limbs_sub(c3, c3, c3n, tmp8, tmp8n)
      end
      # Trim before dividing by 3
      while c3n > 1 && c3[c3n - 1] == 0; c3n -= 1; end
      # c3 /= 3
      limbs_div_rem_1(c3, c3, c3n, 3_u64)
      while c3n > 1 && c3[c3n - 1] == 0; c3n -= 1; end

      # --- c1 = t - c3 ---
      c1 = t  # reuse t buffer (t = c1 + c3, so c1 = t - c3)
      c1n = tn
      if c3n > 0
        c1n = Math.max(c1n, c3n) if c3n > c1n
        limbs_sub(c1, c1, c1n, c3, c3n)
      end
      while c1n > 1 && c1[c1n - 1] == 0; c1n -= 1; end

      # --- Recompose: result = c0 + c1*B^k + c2*B^(2k) + c3*B^(3k) + c4*B^(4k) ---
      rn.times { |i| rp[i] = 0_u64 }

      # c0 = w0 at offset 0
      w0n.times { |i| rp[i] = w0[i] } if w0n > 0

      # c4 = winf at offset 4k
      winfn.times { |i| rp[4 * k + i] = winf[i] } if winfn > 0

      # c1 at offset k (add)
      limbs_add(rp + k, rp + k, rn - k, c1, c1n) if c1n > 0

      # c2 at offset 2k (add)
      limbs_add(rp + 2 * k, rp + 2 * k, rn - 2 * k, c2, c2n) if c2n > 0

      # c3 at offset 3k (add)
      limbs_add(rp + 3 * k, rp + 3 * k, rn - 3 * k, c3, c3n) if c3n > 0
    end

    # Divide limb array by a single limb. Returns remainder.
    # qp[0..n-1] = ap[0..n-1] / d, returns ap mod d.
    # qp may alias ap.
    protected def self.limbs_div_rem_1(qp : Pointer(Limb), ap : Pointer(Limb), n : Int32, d : Limb) : Limb
      raise DivisionByZeroError.new if d == 0
      rem = 0_u128
      i = n - 1
      while i >= 0
        cur = (rem << 64) | ap[i].to_u128
        qp[i] = (cur // d.to_u128).to_u64!
        rem = cur % d.to_u128
        i -= 1
      end
      rem.to_u64!
    end

    # Left-shift limb array by shift bits (0 < shift < 64). Returns bits shifted out of top.
    protected def self.limbs_lshift(rp : Pointer(Limb), ap : Pointer(Limb), n : Int32, shift : Int32) : Limb
      return 0_u64 if shift == 0
      complement = 64 - shift
      carry = 0_u64
      i = 0
      while i < n
        new_carry = ap[i] >> complement
        rp[i] = (ap[i] << shift) | carry
        carry = new_carry
        i += 1
      end
      carry
    end

    # Right-shift limb array by shift bits (0 < shift < 64). Returns bits shifted out of bottom.
    protected def self.limbs_rshift(rp : Pointer(Limb), ap : Pointer(Limb), n : Int32, shift : Int32) : Limb
      return 0_u64 if shift == 0
      complement = 64 - shift
      carry = 0_u64
      i = n - 1
      while i >= 0
        new_carry = ap[i] << complement
        rp[i] = (ap[i] >> shift) | carry
        carry = new_carry
        i -= 1
      end
      carry
    end

    # Knuth Algorithm D: divide np[0..nn-1] by dp[0..dn-1].
    # Stores quotient in qp[0..nn-dn], remainder in rp[0..dn-1].
    # Requires nn >= dn >= 2, and dp[dn-1] != 0.
    protected def self.limbs_div_rem(qp : Pointer(Limb), rp : Pointer(Limb),
                                     np : Pointer(Limb), nn : Int32,
                                     dp : Pointer(Limb), dn : Int32,
                                     scratch : Pointer(Limb))
      # Step D1: Normalize — shift so that dp[dn-1] has its high bit set.
      shift = dp[dn - 1].leading_zeros_count.to_i32
      # Use scratch for working copies: un at scratch[0..nn], vn at scratch[nn+1..nn+dn]
      un = scratch                  # normalized dividend (nn+1 limbs)
      vn = scratch + (nn + 1)       # normalized divisor (dn limbs)

      if shift > 0
        limbs_lshift(vn, dp, dn, shift)
        un[nn] = limbs_lshift(un, np, nn, shift)
      else
        un.copy_from(np, nn)
        un[nn] = 0_u64
        vn.copy_from(dp, dn)
      end

      qn = nn - dn + 1 # number of quotient limbs

      j = qn - 1
      while j >= 0
        # Step D3: Calculate q_hat — estimate quotient digit.
        # q_hat = (un[j+dn]*B + un[j+dn-1]) / vn[dn-1], clamped to B-1.
        u_hi = un[j + dn].to_u128
        u_lo = un[j + dn - 1].to_u128
        v_top = vn[dn - 1].to_u128

        dividend_top = (u_hi << 64) | u_lo
        q_hat = dividend_top // v_top
        r_hat = dividend_top % v_top

        # Refine: while q_hat >= B or q_hat * vn[dn-2] > B*r_hat + un[j+dn-2]
        base = 1_u128 << 64
        while q_hat >= base || q_hat * vn[dn - 2].to_u128 > (r_hat << 64) + un[j + dn - 2].to_u128
          q_hat -= 1
          r_hat += v_top
          break if r_hat >= base
        end

        # Step D4: Multiply and subtract: un[j..j+dn] -= q_hat * vn[0..dn-1]
        borrow = limbs_submul_1(un + j, vn, dn, q_hat.to_u64!)
        # Check the top limb
        if un[j + dn] < borrow
          # Step D6: Add back — q_hat was one too large
          q_hat -= 1
          carry = limbs_add(un + j, un + j, dn, vn, dn)
          un[j + dn] = un[j + dn] &+ carry
        end
        un[j + dn] = un[j + dn] &- borrow

        qp[j] = q_hat.to_u64!
        j -= 1
      end

      # Step D8: Unnormalize remainder
      if shift > 0
        limbs_rshift(rp, un, dn, shift)
      else
        rp.copy_from(un, dn)
      end
    end

    # Returns {chunk_size, base^chunk_size} for string parsing.
    # chunk_size is the largest k such that base^k fits in UInt64.
    protected def self.chunk_params(base : Int32) : {Int32, UInt64}
      # Precomputed for common bases
      case base
      when 2  then {63, 1_u64 << 63}
      when 8  then {21, 8_u64 ** 21}
      when 10 then {19, 10_u64 ** 19}
      when 16 then {15, 1_u64 << 60}
      else
        # Compute: largest k where base^k < 2^64
        k = 1
        power = base.to_u64
        while power <= UInt64::MAX // base.to_u64
          k += 1
          power = power &* base.to_u64
        end
        {k, power}
      end
    end

    protected def self.char_to_digit(c : Char, base : Int32) : Int32
      d = case c
          when '0'..'9' then c.ord - '0'.ord
          when 'a'..'z' then c.ord - 'a'.ord + 10
          when 'A'..'Z' then c.ord - 'A'.ord + 10
          else               raise ArgumentError.new("Invalid digit '#{c}' for base #{base}")
          end
      raise ArgumentError.new("Digit '#{c}' out of range for base #{base}") if d >= base
      d
    end

    protected def self.digit_to_char(d : UInt8) : Char
      if d < 10
        ('0'.ord + d).chr
      else
        ('a'.ord + d - 10).chr
      end
    end
  end
end
