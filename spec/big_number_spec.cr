require "./spec_helper"

alias BI = BigNumber::BigInt

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
