module BigNumber
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
      temp = BigInt.new(other)
      self <=> temp
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
      (self <=> BigInt.new(other)) == 0
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
        result = BigInt.new
        if prod <= UInt64::MAX.to_u128
          result.ensure_capacity(1)
          result.@limbs[0] = prod.to_u64!
          result.set_size(1)
        else
          result.ensure_capacity(2)
          result.@limbs[0] = prod.to_u64!
          result.@limbs[1] = (prod >> 64).to_u64!
          result.set_size(2)
        end
        if (@size < 0) ^ (other.@size < 0)
          result.set_size(-result.@size)
        end
        return result
      end

      an = abs_size
      bn = other.abs_size
      rn = an + bn
      result = BigInt.new
      result.ensure_capacity(rn)
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
        q = BigInt.new
        q.ensure_capacity(an)
        rem_limb = BigInt.limbs_div_rem_1(q.@limbs, @limbs, an, other.@limbs[0])
        q.set_size(an)
        q.normalize!
        r = BigInt.new
        if rem_limb != 0
          r.ensure_capacity(1)
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
      q = BigInt.new
      q.ensure_capacity(qn)
      r = BigInt.new
      r.ensure_capacity(bn)
      BigInt.limbs_div_rem(q.@limbs, r.@limbs, @limbs, an, other.@limbs, bn)
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
        q = q - BigInt.new(1)
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
      raise ArgumentError.new("Modulus must be positive") if mod <= BigInt.new(0)
      return BigInt.new if mod == BigInt.new(1)
      result = BigInt.new(1) % mod
      base = self % mod
      e = exp.dup_value
      while e > BigInt.new(0)
        if e.odd?
          result = (result * base) % mod
        end
        e = e >> 1
        base = (base * base) % mod if e > BigInt.new(0)
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
        self.abs - BigInt.new(1)
      else
        # ~x = -(x + 1)
        -(self + BigInt.new(1))
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
      result = BigInt.new
      result.ensure_capacity(new_size)

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
      result = BigInt.new
      result.ensure_capacity(new_size)

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
          result = result - BigInt.new(1)
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
      while !b.zero?
        a, b = b, a % b
      end
      a
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
        result = result * BigInt.new(i)
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

    def to_s(io : IO, base : Int = 10, *, precision : Int = 1, upcase : Bool = false) : Nil
      raise ArgumentError.new("Invalid base #{base}") unless 2 <= base <= 36
      if zero?
        io << '-' if @size < 0 # -0 shouldn't happen but be safe
        pad = Math.max(precision.to_i32, 1)
        pad.times { io << '0' }
        return
      end
      io << '-' if negative?

      n = abs_size
      tmp = Pointer(Limb).malloc(n)
      tmp.copy_from(@limbs, n)
      tmp_size = n

      raw_digits = [] of UInt8
      while tmp_size > 0
        rem = BigInt.limbs_div_rem_1(tmp, tmp, tmp_size, base.to_u64)
        raw_digits << rem.to_u8
        while tmp_size > 0 && tmp[tmp_size - 1] == 0
          tmp_size -= 1
        end
      end

      # Pad with leading zeros to meet precision
      while raw_digits.size < precision
        raw_digits << 0_u8
      end

      raw_digits.reverse_each do |d|
        c = BigInt.digit_to_char(d)
        io << (upcase ? c.upcase : c)
      end
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
        val = @limbs[0].to_{{info[1].id}}!
        negative? ? (0.to_{{info[1].id}}! &- val) : val
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
        val = @limbs[0].to_{{info[1].id}}!
        negative? ? (0.to_{{info[1].id}}! &- val) : val
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
      result = 0.0
      i = n - 1
      while i >= 0
        result = result * (UInt64::MAX.to_f64 + 1.0) + @limbs[i].to_f64
        i -= 1
      end
      negative? ? -result : result
    end

    def to_f64! : Float64
      to_f64
    end

    def to_big_i : BigInt
      self
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
      raise ArgumentError.new("Expected non-negative number") if negative?
      return BigInt.new(1) if zero?
      # If already a power of 2, return self
      bl = bit_length
      if popcount == 1
        return dup_value
      end
      BigInt.new(1) << bl
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
      result = BigInt.new
      n = abs_size
      if n > 0
        result.ensure_capacity(n)
        result.@limbs.copy_from(@limbs, n)
        result.set_size(@size)
      end
      result
    end

    # --- Private ---

    private def to_i128_internal : Int128
      return 0_i128 if zero?
      n = abs_size
      val = @limbs[0].to_u128
      val |= @limbs[1].to_u128 << 64 if n >= 2
      negative? ? -(val.to_i128!) : val.to_i128!
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
      result = BigInt.new
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
        result.ensure_capacity(max_n)
        result.@limbs.copy_from(r_tc, max_n)
        result.set_size(-max_n)
        result.normalize!
      else
        result.ensure_capacity(max_n)
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
      result = BigInt.new
      result.ensure_capacity(max_n)
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
      result = BigInt.new
      result.ensure_capacity(an + 1)
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
      result = BigInt.new
      if cmp > 0
        # |self| > |other|
        result.ensure_capacity(an)
        BigInt.limbs_sub(result.@limbs, @limbs, an, other.@limbs, bn)
        result.set_size(an)
        # Result has sign of self
        result.set_size(-result.@size) if @size < 0
      else
        # |self| < |other|
        result.ensure_capacity(bn)
        BigInt.limbs_sub(result.@limbs, other.@limbs, bn, @limbs, an)
        result.set_size(bn)
        # Result has sign of other (opposite of self, since we're subtracting)
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
        s = ap[i] &+ bp[i]
        c1 = s < ap[i] ? 1_u64 : 0_u64
        s2 = s &+ carry
        c2 = s2 < s ? 1_u64 : 0_u64
        rp[i] = s2
        carry = c1 &+ c2
        i += 1
      end
      while i < an
        s = ap[i] &+ carry
        carry = s < ap[i] ? 1_u64 : 0_u64
        rp[i] = s
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

    # Top-level multiply dispatch. an >= bn > 0. rp must not alias ap or bp.
    protected def self.limbs_mul(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32)
      if bn < KARATSUBA_THRESHOLD
        limbs_mul_schoolbook(rp, ap, an, bp, bn)
      else
        # Allocate scratch space for Karatsuba
        scratch = Pointer(Limb).malloc(karatsuba_scratch_size(an))
        limbs_mul_karatsuba(rp, ap, an, bp, bn, scratch)
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
      # Fall back to schoolbook for small or unbalanced operands
      if bn < KARATSUBA_THRESHOLD
        limbs_mul_schoolbook(rp, ap, an, bp, bn)
        return
      end

      # If very unbalanced (an >= 2*bn), slice a into chunks and multiply piecewise
      if an >= 2 * bn
        limbs_mul_unbalanced(rp, ap, an, bp, bn, scratch)
        return
      end

      # Split at midpoint: m = bn / 2
      # a = a1 * B^m + a0,  b = b1 * B^m + b0
      m = bn >> 1
      a0 = ap;         a0n = m
      a1 = ap + m;     a1n = an - m
      b0 = bp;         b0n = m
      b1 = bp + m;     b1n = bn - m

      # z0 = a0 * b0  (stored in rp[0..2m-1])
      limbs_mul_karatsuba(rp, a0, a0n, b0, b0n, scratch)
      # Zero upper part of rp that we'll accumulate into
      (an + bn - 2 * m).times { |i| rp[2 * m + i] = 0_u64 }

      # z2 = a1 * b1  (stored in rp[2m..an+bn-1])
      limbs_mul_karatsuba(rp + 2 * m, a1, a1n, b1, b1n, scratch)

      # z1 = (a0 + a1) * (b0 + b1) - z0 - z2
      # Compute |a0 + a1| and |b0 + b1| in scratch
      t1 = scratch
      t1n = Math.max(a0n, a1n) + 1
      t2 = scratch + t1n
      t2n = Math.max(b0n, b1n) + 1

      # a0 + a1
      if a0n >= a1n
        t1[a0n] = limbs_add(t1, a0, a0n, a1, a1n)
      else
        t1[a1n] = limbs_add(t1, a1, a1n, a0, a0n)
      end
      # Trim leading zero
      actual_t1n = t1n
      while actual_t1n > 0 && t1[actual_t1n - 1] == 0
        actual_t1n -= 1
      end
      actual_t1n = 1 if actual_t1n == 0

      # b0 + b1
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

      # t3 = (a0+a1) * (b0+b1) in scratch after t1 and t2
      t3 = scratch + t1n + t2n
      t3n = actual_t1n + actual_t2n
      next_scratch = t3 + t3n
      if actual_t1n >= actual_t2n
        limbs_mul_karatsuba(t3, t1, actual_t1n, t2, actual_t2n, next_scratch)
      else
        limbs_mul_karatsuba(t3, t2, actual_t2n, t1, actual_t1n, next_scratch)
      end
      # Trim
      while t3n > 0 && t3[t3n - 1] == 0
        t3n -= 1
      end

      # t3 -= z0 (rp[0..2m-1])
      z0n = a0n + b0n
      limbs_sub(t3, t3, t3n, rp, z0n) if z0n > 0 && t3n >= z0n

      # t3 -= z2 (rp[2m..])
      z2n = a1n + b1n
      while z2n > 0 && rp[2 * m + z2n - 1] == 0
        z2n -= 1
      end
      limbs_sub(t3, t3, t3n, rp + 2 * m, z2n) if z2n > 0 && t3n >= z2n

      # Trim t3 again
      while t3n > 0 && t3[t3n - 1] == 0
        t3n -= 1
      end

      # Add t3 at position m in rp
      if t3n > 0
        carry = limbs_add(rp + m, rp + m, an + bn - m, t3, t3n)
        # carry should be absorbed since result fits in an+bn limbs
      end
    end

    # Handle unbalanced multiply: an >= 2*bn. Slice a into bn-sized chunks.
    protected def self.limbs_mul_unbalanced(rp : Pointer(Limb), ap : Pointer(Limb), an : Int32, bp : Pointer(Limb), bn : Int32, scratch : Pointer(Limb))
      # Zero the result
      (an + bn).times { |i| rp[i] = 0_u64 }

      # Temporary buffer for each chunk product
      tmp = Pointer(Limb).malloc(2 * bn)

      offset = 0
      remaining = an
      while remaining > 0
        chunk = Math.min(remaining, bn)
        if chunk >= bn
          limbs_mul_karatsuba(tmp, ap + offset, chunk, bp, bn, scratch)
        else
          # Last chunk may be smaller
          if chunk >= bn
            limbs_mul_karatsuba(tmp, ap + offset, chunk, bp, bn, scratch)
          else
            # smaller * larger: swap if needed
            if chunk >= bn
              limbs_mul_karatsuba(tmp, ap + offset, chunk, bp, bn, scratch)
            else
              limbs_mul_karatsuba(tmp, bp, bn, ap + offset, chunk, scratch)
            end
          end
        end
        # Add tmp to rp at offset
        product_size = chunk + bn
        carry = limbs_add(rp + offset, rp + offset, an + bn - offset, tmp, product_size)
        offset += chunk
        remaining -= chunk
      end
    end

    protected def self.karatsuba_scratch_size(n : Int32) : Int32
      # Conservative estimate: each level needs ~4n, with log2(n/threshold) levels
      n * 8 + 64
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
                                     dp : Pointer(Limb), dn : Int32)
      # Step D1: Normalize — shift so that dp[dn-1] has its high bit set.
      shift = dp[dn - 1].leading_zeros_count.to_i32
      # Allocate working copies
      un = Pointer(Limb).malloc(nn + 1)  # normalized dividend (one extra limb)
      vn = Pointer(Limb).malloc(dn)      # normalized divisor

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
