require "./spec_helper"

describe BigNumber::BigInt do
  # --- Construction ---

  it "constructs zero" do
    BI.new.zero?.should be_true
    BI.new.to_s.should eq("0")
  end

  it "constructs from positive small int" do
    BI.new(42).to_s.should eq("42")
    BI.new(0).zero?.should be_true
    BI.new(1).to_s.should eq("1")
  end

  it "constructs from negative int" do
    BI.new(-7).to_s.should eq("-7")
    BI.new(-1).to_s.should eq("-1")
    BI.new(-999).to_s.should eq("-999")
  end

  it "constructs from large UInt64" do
    BI.new(UInt64::MAX).to_s.should eq(UInt64::MAX.to_s)
  end

  it "constructs from Int64::MIN" do
    BI.new(Int64::MIN).to_s.should eq(Int64::MIN.to_s)
  end

  it "constructs from Int128 spanning 2 limbs" do
    val = Int128::MAX
    BI.new(val).to_s.should eq(val.to_s)
  end

  # --- String parsing ---

  it "parses basic decimal string" do
    BI.new("12345").to_s.should eq("12345")
  end

  it "parses negative string" do
    BI.new("-999").to_s.should eq("-999")
  end

  it "parses leading zeros" do
    BI.new("007").to_s.should eq("7")
  end

  it "parses zero" do
    BI.new("0").to_s.should eq("0")
    BI.new("000").to_s.should eq("0")
  end

  it "parses large number" do
    s = "123456789012345678901234567890"
    BI.new(s).to_s.should eq(s)
  end

  it "parses hex string" do
    BI.new("ff", 16).to_s(10).should eq("255")
    BI.new("DEADBEEF", 16).to_s(16).should eq("deadbeef")
  end

  it "parses binary string" do
    BI.new("11010", 2).to_s(10).should eq("26")
  end

  it "round-trips through string" do
    vals = ["0", "1", "-1", "42", "-42", "999999999999999999",
            "123456789012345678901234567890",
            "-123456789012345678901234567890"]
    vals.each do |s|
      BI.new(s).to_s.should eq(s)
    end
  end

  # --- to_s with bases ---

  it "converts to hex" do
    BI.new(255).to_s(16).should eq("ff")
    BI.new(256).to_s(16).should eq("100")
  end

  it "converts to binary" do
    BI.new(42).to_s(2).should eq("101010")
  end

  it "converts to octal" do
    BI.new(255).to_s(8).should eq("377")
  end

  # --- Comparison ---

  it "compares equal values" do
    (BI.new(42) <=> BI.new(42)).should eq(0)
    (BI.new(42) == BI.new(42)).should be_true
    (BI.new(-7) == BI.new(-7)).should be_true
    (BI.new(0) == BI.new).should be_true
  end

  it "compares positive different sizes" do
    (BI.new(100) > BI.new(42)).should be_true
    (BI.new(42) < BI.new(100)).should be_true
  end

  it "compares negative ordering" do
    (BI.new(-3) < BI.new(-2)).should be_true
    (BI.new(-2) > BI.new(-3)).should be_true
  end

  it "compares mixed signs" do
    (BI.new(-1) < BI.new(1)).should be_true
    (BI.new(1) > BI.new(-1)).should be_true
    (BI.new(-1) < BI.new(0)).should be_true
    (BI.new(0) > BI.new(-1)).should be_true
  end

  it "compares with Int" do
    (BI.new(42) == 42).should be_true
    (BI.new(42) > 41).should be_true
    (BI.new(42) < 43).should be_true
  end

  it "compares large numbers" do
    a = BI.new("99999999999999999999")
    b = BI.new("99999999999999999998")
    (a > b).should be_true
    (a == a).should be_true
  end

  # --- Addition ---

  it "adds two positives" do
    (BI.new(42) + BI.new(17)).to_s.should eq("59")
  end

  it "adds with carry propagation" do
    a = BI.new(UInt64::MAX)
    b = BI.new(1)
    result = a + b
    result.to_s.should eq((UInt64::MAX.to_u128 + 1).to_s)
  end

  it "adds different signs" do
    (BI.new(10) + BI.new(-3)).to_s.should eq("7")
    (BI.new(-10) + BI.new(3)).to_s.should eq("-7")
  end

  it "adds to zero" do
    (BI.new(5) + BI.new(-5)).to_s.should eq("0")
  end

  it "adds large numbers" do
    a = BI.new("99999999999999999999")
    b = BI.new("1")
    (a + b).to_s.should eq("100000000000000000000")
  end

  it "adds with Int" do
    (BI.new(40) + 2).to_s.should eq("42")
  end

  # --- Subtraction ---

  it "subtracts basic" do
    (BI.new(100) - BI.new(42)).to_s.should eq("58")
  end

  it "subtracts to negative" do
    (BI.new(3) - BI.new(10)).to_s.should eq("-7")
  end

  it "subtracts negatives" do
    (BI.new(-3) - BI.new(-10)).to_s.should eq("7")
  end

  it "unary minus" do
    (-BI.new(42)).to_s.should eq("-42")
    (-BI.new(-42)).to_s.should eq("42")
    (-BI.new(0)).to_s.should eq("0")
  end

  it "abs" do
    BI.new(-42).abs.to_s.should eq("42")
    BI.new(42).abs.to_s.should eq("42")
    BI.new(0).abs.to_s.should eq("0")
  end

  # --- Multiplication ---

  it "multiplies basic" do
    (BI.new(6) * BI.new(7)).to_s.should eq("42")
  end

  it "multiplies by zero" do
    (BI.new(999) * BI.new(0)).to_s.should eq("0")
    (BI.new(0) * BI.new(999)).to_s.should eq("0")
  end

  it "multiplies signs" do
    (BI.new(-6) * BI.new(7)).to_s.should eq("-42")
    (BI.new(6) * BI.new(-7)).to_s.should eq("-42")
    (BI.new(-6) * BI.new(-7)).to_s.should eq("42")
  end

  it "multiplies large numbers" do
    a = BI.new("99999999999999999999")
    b = BI.new("99999999999999999999")
    expected = "9999999999999999999800000000000000000001"
    (a * b).to_s.should eq(expected)
  end

  it "multiplies with Int" do
    (BI.new(21) * 2).to_s.should eq("42")
  end

  # --- Division ---

  it "truncating division basic" do
    q, r = BI.new(7).tdiv_rem(BI.new(3))
    q.to_s.should eq("2")
    r.to_s.should eq("1")
  end

  it "truncating division negative dividend" do
    q, r = BI.new(-7).tdiv_rem(BI.new(3))
    q.to_s.should eq("-2")
    r.to_s.should eq("-1")
  end

  it "truncating division negative divisor" do
    q, r = BI.new(7).tdiv_rem(BI.new(-3))
    q.to_s.should eq("-2")
    r.to_s.should eq("1")
  end

  it "floor division positive" do
    (BI.new(7) // BI.new(3)).to_s.should eq("2")
  end

  it "floor division negative" do
    (BI.new(-7) // BI.new(3)).to_s.should eq("-3")
    (BI.new(7) // BI.new(-3)).to_s.should eq("-3")
  end

  it "floor mod" do
    (BI.new(-7) % BI.new(3)).to_s.should eq("2")
    (BI.new(7) % BI.new(3)).to_s.should eq("1")
  end

  it "division by zero raises" do
    expect_raises(DivisionByZeroError) { BI.new(1) // BI.new(0) }
  end

  it "single-limb division" do
    a = BI.new("123456789012345678901234567890")
    b = BI.new(7)
    q = a // b
    r = a % b
    # Verify: q * b + r == a
    (q * b + r).to_s.should eq(a.to_s)
  end

  it "multi-limb division" do
    a = BI.new("123456789012345678901234567890")
    b = BI.new("987654321098765432")
    q = a // b
    r = a % b
    (q * b + r).to_s.should eq(a.to_s)
  end

  it "divides equal values" do
    a = BI.new(42)
    (a // a).to_s.should eq("1")
    (a % a).to_s.should eq("0")
  end

  it "divides smaller by larger" do
    (BI.new(3) // BI.new(7)).to_s.should eq("0")
    (BI.new(3) % BI.new(7)).to_s.should eq("3")
  end

  it "divides with Int" do
    (BI.new(42) // 5).to_s.should eq("8")
    (BI.new(42) % 5).to_s.should eq("2")
  end

  # --- Fuzz tests against stdlib ---

  it "fuzz: add matches stdlib" do
    rng = Random.new(42)
    1000.times do
      a_str = random_decimal(rng, max_digits: 100)
      b_str = random_decimal(rng, max_digits: 100)
      ours = BI.new(a_str) + BI.new(b_str)
      theirs = ::BigInt.new(a_str) + ::BigInt.new(b_str)
      ours.to_s.should eq(theirs.to_s), "add failed: #{a_str} + #{b_str}"
    end
  end

  it "fuzz: sub matches stdlib" do
    rng = Random.new(43)
    1000.times do
      a_str = random_decimal(rng, max_digits: 100)
      b_str = random_decimal(rng, max_digits: 100)
      ours = BI.new(a_str) - BI.new(b_str)
      theirs = ::BigInt.new(a_str) - ::BigInt.new(b_str)
      ours.to_s.should eq(theirs.to_s), "sub failed: #{a_str} - #{b_str}"
    end
  end

  it "fuzz: mul matches stdlib" do
    rng = Random.new(44)
    1000.times do
      a_str = random_decimal(rng, max_digits: 60)
      b_str = random_decimal(rng, max_digits: 60)
      ours = BI.new(a_str) * BI.new(b_str)
      theirs = ::BigInt.new(a_str) * ::BigInt.new(b_str)
      ours.to_s.should eq(theirs.to_s), "mul failed: #{a_str} * #{b_str}"
    end
  end

  it "fuzz: divmod matches stdlib" do
    rng = Random.new(45)
    1000.times do
      a_str = random_decimal(rng, max_digits: 100)
      b_str = random_nonzero_decimal(rng, max_digits: 50)
      ours_q = BI.new(a_str) // BI.new(b_str)
      ours_r = BI.new(a_str) % BI.new(b_str)
      theirs = ::BigInt.new(a_str).tdiv(::BigInt.new(b_str))
      theirs_r = ::BigInt.new(a_str) - theirs * ::BigInt.new(b_str)
      # Compare floor div
      theirs_q2 = ::BigInt.new(a_str) // ::BigInt.new(b_str)
      theirs_r2 = ::BigInt.new(a_str) % ::BigInt.new(b_str)
      ours_q.to_s.should eq(theirs_q2.to_s), "div failed: #{a_str} // #{b_str}"
      ours_r.to_s.should eq(theirs_r2.to_s), "mod failed: #{a_str} % #{b_str}"
    end
  end

  it "fuzz: string round-trip" do
    rng = Random.new(46)
    1000.times do
      s = random_decimal(rng, max_digits: 100)
      BI.new(s).to_s.should eq(normalize_decimal(s))
    end
  end

  # === Step 2: Make It Complete ===

  # --- Exponentiation ---

  it "power basic" do
    (BI.new(2) ** 10).to_s.should eq("1024")
    (BI.new(0) ** 0).to_s.should eq("1")
    (BI.new(-2) ** 3).to_s.should eq("-8")
    (BI.new(-2) ** 4).to_s.should eq("16")
    (BI.new(1) ** 1000).to_s.should eq("1")
  end

  it "power large" do
    (BI.new(2) ** 100).to_s.should eq((::BigInt.new(2) ** 100).to_s)
  end

  it "power negative exponent raises" do
    expect_raises(ArgumentError) { BI.new(2) ** -1 }
  end

  # --- Number Theory ---

  it "gcd basic" do
    BI.new(12).gcd(BI.new(8)).to_s.should eq("4")
    BI.new(7).gcd(BI.new(13)).to_s.should eq("1")
  end

  it "gcd with zero" do
    BI.new(42).gcd(BI.new(0)).to_s.should eq("42")
    BI.new(0).gcd(BI.new(42)).to_s.should eq("42")
    BI.new(0).gcd(BI.new(0)).to_s.should eq("0")
  end

  it "gcd with negative" do
    BI.new(-12).gcd(BI.new(8)).to_s.should eq("4")
    BI.new(12).gcd(BI.new(-8)).to_s.should eq("4")
  end

  it "lcm" do
    BI.new(4).lcm(BI.new(6)).to_s.should eq("12")
    BI.new(0).lcm(BI.new(5)).to_s.should eq("0")
  end

  it "factorial" do
    BI.new(0).factorial.to_s.should eq("1")
    BI.new(1).factorial.to_s.should eq("1")
    BI.new(10).factorial.to_s.should eq("3628800")
    BI.new(20).factorial.to_s.should eq("2432902008176640000")
  end

  it "divisible_by?" do
    BI.new(12).divisible_by?(BI.new(3)).should be_true
    BI.new(13).divisible_by?(BI.new(3)).should be_false
    BI.new(0).divisible_by?(BI.new(5)).should be_true
  end

  # --- Bitwise ---

  it "bitwise NOT" do
    (~BI.new(0)).to_s.should eq("-1")
    (~BI.new(1)).to_s.should eq("-2")
    (~BI.new(-1)).to_s.should eq("0")
    (~BI.new(-2)).to_s.should eq("1")
  end

  it "bitwise AND positive" do
    (BI.new(0xff) & BI.new(0x0f)).to_s.should eq("15")
    (BI.new(0) & BI.new(42)).to_s.should eq("0")
  end

  it "bitwise AND negative" do
    (BI.new(-3) & BI.new(5)).to_s.should eq(((-3).to_big_i & 5.to_big_i).to_s)
  end

  it "bitwise OR" do
    (BI.new(0xf0) | BI.new(0x0f)).to_s.should eq("255")
    (BI.new(-3) | BI.new(5)).to_s.should eq(((-3).to_big_i | 5.to_big_i).to_s)
  end

  it "bitwise XOR" do
    (BI.new(0xff) ^ BI.new(0x0f)).to_s.should eq("240")
    (BI.new(-3) ^ BI.new(5)).to_s.should eq(((-3).to_big_i ^ 5.to_big_i).to_s)
  end

  it "left shift" do
    (BI.new(1) << 0).to_s.should eq("1")
    (BI.new(1) << 1).to_s.should eq("2")
    (BI.new(1) << 64).to_s.should eq((::BigInt.new(1) << 64).to_s)
    (BI.new(-3) << 2).to_s.should eq("-12")
  end

  it "right shift" do
    (BI.new(8) >> 1).to_s.should eq("4")
    (BI.new(8) >> 3).to_s.should eq("1")
    (BI.new(8) >> 4).to_s.should eq("0")
    (BI.new(-1) >> 1).to_s.should eq("-1")
    (BI.new(-4) >> 1).to_s.should eq("-2")
    (BI.new(-3) >> 1).to_s.should eq("-2")
  end

  it "bit" do
    BI.new(5).bit(0).should eq(1)
    BI.new(5).bit(1).should eq(0)
    BI.new(5).bit(2).should eq(1)
    BI.new(5).bit(3).should eq(0)
    BI.new(-1).bit(100).should eq(1)
    BI.new(0).bit(0).should eq(0)
  end

  it "bit_length" do
    BI.new(0).bit_length.should eq(1)
    BI.new(1).bit_length.should eq(1)
    BI.new(255).bit_length.should eq(8)
    BI.new(256).bit_length.should eq(9)
    BI.new(-1).bit_length.should eq(1)
    BI.new(-128).bit_length.should eq(8)
    BI.new(-129).bit_length.should eq(8) # stdlib: -129 needs 8 bits (two's complement: 0x7f needs 8)
  end

  it "popcount" do
    BI.new(7).popcount.should eq(3)
    BI.new(0).popcount.should eq(0)
    BI.new(-1).popcount.should eq(UInt64::MAX)
  end

  it "trailing_zeros_count" do
    BI.new(12).trailing_zeros_count.should eq(2)
    BI.new(1).trailing_zeros_count.should eq(0)
    BI.new(0).trailing_zeros_count.should eq(0)
  end

  # --- Conversions ---

  it "to_i32 checked" do
    BI.new(42).to_i32.should eq(42)
    BI.new(-42).to_i32.should eq(-42)
    expect_raises(OverflowError) { BI.new(Int32::MAX.to_i64 + 1).to_i32 }
  end

  it "to_u32 checked" do
    BI.new(42).to_u32.should eq(42_u32)
    expect_raises(OverflowError) { BI.new(-1).to_u32 }
    expect_raises(OverflowError) { BI.new(UInt32::MAX.to_u64 + 1).to_u32 }
  end

  it "to_i128" do
    BI.new(Int64::MAX).to_i128.should eq(Int64::MAX.to_i128)
    BI.new(Int64::MIN).to_i128.should eq(Int64::MIN.to_i128)
  end

  it "to_u128" do
    BI.new(UInt64::MAX).to_u128.should eq(UInt64::MAX.to_u128)
  end

  it "unchecked conversions" do
    BI.new(256).to_u8!.should eq(0_u8)
    BI.new(256).to_i8!.should eq(0_i8)
  end

  it "to_f32" do
    BI.new(42).to_f32.should eq(42.0_f32)
  end

  it "digits" do
    BI.new(123).digits.should eq([3, 2, 1])
    BI.new(123).digits(16).should eq([11, 7])
    BI.new(0).digits.should eq([0])
  end

  # --- to_s options ---

  it "to_s with precision" do
    BI.new(42).to_s(10, precision: 5).should eq("00042")
    BI.new(0).to_s(10, precision: 3).should eq("000")
  end

  it "to_s with upcase" do
    BI.new(255).to_s(16, upcase: true).should eq("FF")
    BI.new(255).to_s(16, upcase: false).should eq("ff")
  end

  # --- Misc ---

  it "next_power_of_two" do
    BI.new(5).next_power_of_two.to_s.should eq("8")
    BI.new(8).next_power_of_two.to_s.should eq("8")
    BI.new(1).next_power_of_two.to_s.should eq("1")
  end

  it "factor_by" do
    q, c = BI.new(72).factor_by(2)
    q.to_s.should eq("9")
    c.should eq(3_u64)
    q2, c2 = BI.new(72).factor_by(3)
    q2.to_s.should eq("8")
    c2.should eq(2_u64)
  end

  # --- Wrapping & remainder ---

  it "wrapping ops" do
    (BI.new(42) &+ BI.new(8)).to_s.should eq("50")
    (BI.new(42) &- BI.new(8)).to_s.should eq("34")
    (BI.new(6) &* BI.new(7)).to_s.should eq("42")
  end

  it "remainder" do
    BI.new(7).remainder(BI.new(3)).to_s.should eq("1")
    BI.new(-7).remainder(BI.new(3)).to_s.should eq("-1")
  end

  # --- Extensions ---

  it "Int + BigInt" do
    (42 + BI.new(8)).to_s.should eq("50")
    (42 - BI.new(8)).to_s.should eq("34")
    (6 * BI.new(7)).to_s.should eq("42")
  end

  it "Int <=> BigInt" do
    (42 == BI.new(42)).should be_true
    ((42 <=> BI.new(41)) > 0).should be_true
    ((42 <=> BI.new(43)) < 0).should be_true
  end

  it "Int#to_big_i" do
    42.to_big_i.to_s.should eq("42")
  end

  it "String#to_big_i" do
    "12345".to_big_i.to_s.should eq("12345")
    "ff".to_big_i(16).to_s.should eq("255")
  end

  it "Float#to_big_i" do
    3.7.to_big_i.to_s.should eq("3")
    (-3.7).to_big_i.to_s.should eq("-3")
  end

  it "BigInt.new(BigInt) copies" do
    a = BI.new(42)
    b = BI.new(a)
    b.to_s.should eq("42")
  end

  # --- Fuzz: Step 2 ---

  it "fuzz: bitwise ops match stdlib" do
    rng = Random.new(50)
    1000.times do
      a_str = random_decimal(rng, max_digits: 40)
      b_str = random_decimal(rng, max_digits: 40)
      ours_a = BI.new(a_str)
      ours_b = BI.new(b_str)
      theirs_a = ::BigInt.new(a_str)
      theirs_b = ::BigInt.new(b_str)

      (~ours_a).to_s.should eq((~theirs_a).to_s), "NOT failed: ~#{a_str}"
      (ours_a & ours_b).to_s.should eq((theirs_a & theirs_b).to_s), "AND failed: #{a_str} & #{b_str}"
      (ours_a | ours_b).to_s.should eq((theirs_a | theirs_b).to_s), "OR failed: #{a_str} | #{b_str}"
      (ours_a ^ ours_b).to_s.should eq((theirs_a ^ theirs_b).to_s), "XOR failed: #{a_str} ^ #{b_str}"
    end
  end

  it "fuzz: shift matches stdlib" do
    rng = Random.new(51)
    1000.times do
      a_str = random_decimal(rng, max_digits: 40)
      shift = rng.rand(0..128)
      ours = BI.new(a_str)
      theirs = ::BigInt.new(a_str)

      (ours << shift).to_s.should eq((theirs << shift).to_s), "lshift failed: #{a_str} << #{shift}"
      (ours >> shift).to_s.should eq((theirs >> shift).to_s), "rshift failed: #{a_str} >> #{shift}"
    end
  end

  it "fuzz: gcd matches stdlib" do
    rng = Random.new(52)
    1000.times do
      a_str = random_decimal(rng, max_digits: 40)
      b_str = random_decimal(rng, max_digits: 40)
      ours = BI.new(a_str).gcd(BI.new(b_str))
      theirs = ::BigInt.new(a_str).gcd(::BigInt.new(b_str))
      ours.to_s.should eq(theirs.to_s), "gcd failed: gcd(#{a_str}, #{b_str})"
    end
  end

  it "fuzz: power matches stdlib" do
    rng = Random.new(53)
    500.times do
      base_str = random_decimal(rng, max_digits: 10)
      exp = rng.rand(0..20)
      ours = BI.new(base_str) ** exp
      theirs = ::BigInt.new(base_str) ** exp
      ours.to_s.should eq(theirs.to_s), "power failed: #{base_str} ** #{exp}"
    end
  end

  it "fuzz: bit_length matches stdlib" do
    rng = Random.new(54)
    1000.times do
      a_str = random_decimal(rng, max_digits: 40)
      ours = BI.new(a_str).bit_length
      theirs = ::BigInt.new(a_str).bit_length
      ours.should eq(theirs), "bit_length failed: #{a_str}"
    end
  end

  # === Step 2b: Missing Features ===

  # --- even?/odd? ---

  it "even? and odd?" do
    BI.new(0).even?.should be_true
    BI.new(0).odd?.should be_false
    BI.new(1).even?.should be_false
    BI.new(1).odd?.should be_true
    BI.new(2).even?.should be_true
    BI.new(-3).odd?.should be_true
    BI.new(-4).even?.should be_true
    BI.new("999999999999999999999999999999").even?.should be_false
    BI.new("999999999999999999999999999998").even?.should be_true
  end

  # --- pow_mod ---

  it "pow_mod basic" do
    # 2^10 mod 1000 = 1024 mod 1000 = 24
    BI.new(2).pow_mod(BI.new(10), BI.new(1000)).to_s.should eq("24")
    # exp=0 -> 1
    BI.new(5).pow_mod(BI.new(0), BI.new(7)).to_s.should eq("1")
    # mod=1 -> 0
    BI.new(5).pow_mod(BI.new(10), BI.new(1)).to_s.should eq("0")
  end

  it "pow_mod Fermat's little theorem" do
    # For prime p, a^(p-1) ≡ 1 (mod p)
    p = BI.new(104729) # prime
    a = BI.new(12345)
    a.pow_mod(p - BI.new(1), p).to_s.should eq("1")
  end

  it "pow_mod large values" do
    base = BI.new("123456789012345678901234567890")
    exp = BI.new("9999999999999999999")
    mod = BI.new("1000000007")
    result = base.pow_mod(exp, mod)
    # Verify result is in range
    (result >= BI.new(0)).should be_true
    (result < mod).should be_true
  end

  it "pow_mod with Int convenience" do
    BI.new(2).pow_mod(10, BI.new(1000)).to_s.should eq("24")
  end

  # --- sqrt ---

  it "sqrt perfect squares" do
    BI.new(0).sqrt.to_s.should eq("0")
    BI.new(1).sqrt.to_s.should eq("1")
    BI.new(4).sqrt.to_s.should eq("2")
    BI.new(9).sqrt.to_s.should eq("3")
    BI.new(16).sqrt.to_s.should eq("4")
    BI.new(100).sqrt.to_s.should eq("10")
    BI.new(10000).sqrt.to_s.should eq("100")
  end

  it "sqrt non-perfect (floor)" do
    BI.new(2).sqrt.to_s.should eq("1")
    BI.new(3).sqrt.to_s.should eq("1")
    BI.new(5).sqrt.to_s.should eq("2")
    BI.new(8).sqrt.to_s.should eq("2")
    BI.new(99).sqrt.to_s.should eq("9")
  end

  it "sqrt large values" do
    val = BI.new("100000000000000000000000000000000000000") # 10^38
    val.sqrt.to_s.should eq("10000000000000000000") # 10^19
  end

  it "sqrt invariant r² ≤ n < (r+1)²" do
    rng = Random.new(61)
    200.times do
      s = random_decimal(rng, max_digits: 40)
      n = BI.new(s).abs
      r = n.sqrt
      (r * r <= n).should be_true, "r² > n for n=#{n}"
      ((r + BI.new(1)) * (r + BI.new(1)) > n).should be_true, "(r+1)² ≤ n for n=#{n}"
    end
  end

  it "sqrt negative raises" do
    expect_raises(ArgumentError) { BI.new(-4).sqrt }
  end

  # --- prime? ---

  it "prime? small primes" do
    [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31].each do |p|
      BI.new(p).prime?.should be_true, "#{p} should be prime"
    end
  end

  it "prime? small composites" do
    [0, 1, 4, 6, 8, 9, 10, 12, 14, 15].each do |c|
      BI.new(c).prime?.should be_false, "#{c} should not be prime"
    end
  end

  it "prime? Carmichael numbers" do
    [561, 1105, 1729].each do |c|
      BI.new(c).prime?.should be_false, "Carmichael number #{c} should not be prime"
    end
  end

  it "prime? Mersenne primes" do
    # 2^61 - 1 is a Mersenne prime
    m61 = (BI.new(1) << 61) - BI.new(1)
    m61.prime?.should be_true
    # 2^31 - 1 is a Mersenne prime
    m31 = (BI.new(1) << 31) - BI.new(1)
    m31.prime?.should be_true
  end

  it "prime? larger composite" do
    # Product of two primes
    composite = BI.new(104729) * BI.new(104743)
    composite.prime?.should be_false
  end

  # --- to_bytes / from_bytes ---

  it "to_bytes known vectors" do
    BI.new(0).to_bytes.should eq(Bytes[0])
    BI.new(1).to_bytes.should eq(Bytes[1])
    BI.new(255).to_bytes.should eq(Bytes[255])
    BI.new(256).to_bytes.should eq(Bytes[1, 0])
    BI.new(65535).to_bytes.should eq(Bytes[255, 255])
    BI.new(65536).to_bytes.should eq(Bytes[1, 0, 0])
  end

  it "to_bytes little-endian" do
    BI.new(256).to_bytes(big_endian: false).should eq(Bytes[0, 1])
  end

  it "to_bytes negative raises" do
    expect_raises(ArgumentError) { BI.new(-1).to_bytes }
  end

  it "from_bytes known vectors" do
    BI.from_bytes(Bytes[0]).to_s.should eq("0")
    BI.from_bytes(Bytes[1]).to_s.should eq("1")
    BI.from_bytes(Bytes[1, 0]).to_s.should eq("256")
    BI.from_bytes(Bytes[255, 255]).to_s.should eq("65535")
  end

  it "from_bytes little-endian" do
    BI.from_bytes(Bytes[0, 1], big_endian: false).to_s.should eq("256")
  end

  it "to_bytes/from_bytes round-trip fuzz" do
    rng = Random.new(60)
    500.times do
      s = random_decimal(rng, max_digits: 50)
      val = BI.new(s).abs
      bytes_be = val.to_bytes(big_endian: true)
      bytes_le = val.to_bytes(big_endian: false)
      BI.from_bytes(bytes_be, big_endian: true).to_s.should eq(val.to_s), "round-trip BE failed: #{val}"
      BI.from_bytes(bytes_le, big_endian: false).to_s.should eq(val.to_s), "round-trip LE failed: #{val}"
    end
  end

  it "to_bytes/from_bytes at limb boundaries" do
    # Exactly 1 limb (8 bytes)
    val = BI.new(UInt64::MAX)
    rt = BI.from_bytes(val.to_bytes)
    rt.to_s.should eq(val.to_s)
    # 2 limbs
    val2 = BI.new(UInt64::MAX) * BI.new(256) + BI.new(1)
    rt2 = BI.from_bytes(val2.to_bytes)
    rt2.to_s.should eq(val2.to_s)
  end
end

# --- Helpers ---

def random_decimal(rng : Random, max_digits : Int32) : String
  n_digits = rng.rand(1..max_digits)
  neg = rng.rand(2) == 0
  digits = String.build do |io|
    io << '-' if neg
    io << (rng.rand(1..9)).to_s  # no leading zero
    (n_digits - 1).times { io << rng.rand(0..9).to_s }
  end
  digits
end

def random_nonzero_decimal(rng : Random, max_digits : Int32) : String
  loop do
    s = random_decimal(rng, max_digits)
    return s unless s == "0"
  end
end

def normalize_decimal(s : String) : String
  # Remove leading zeros, handle sign
  neg = s.starts_with?('-')
  digits = neg ? s[1..] : s
  digits = digits.lstrip('0')
  digits = "0" if digits.empty?
  if digits == "0"
    "0"
  elsif neg
    "-#{digits}"
  else
    digits
  end
end
