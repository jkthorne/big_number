require "spec"

{% if flag?(:big_number_stdlib) %}
require "../src/big_number/stdlib"

describe "BigInt (stdlib wrapper)" do
  it "basic construction" do
    x = BigInt.new(42)
    x.to_i.should eq(42)
  end

  it "inherits from Int" do
    BigInt.new(42).is_a?(Int).should be_true
  end

  it "inherits from Number" do
    BigInt.new(42).is_a?(Number).should be_true
  end

  it "string construction" do
    x = BigInt.new("123456789012345678901234567890")
    x.to_s.should eq("123456789012345678901234567890")
  end

  it "arithmetic" do
    a = BigInt.new(100)
    b = BigInt.new(42)
    (a + b).to_i.should eq(142)
    (a - b).to_i.should eq(58)
    (a * b).to_i.should eq(4200)
    (a // b).to_i.should eq(2)
    (a % b).to_i.should eq(16)
  end

  it "comparison" do
    (BigInt.new(10) <=> BigInt.new(20)).should eq(-1)
    (BigInt.new(20) <=> BigInt.new(10)).should eq(1)
    (BigInt.new(10) <=> BigInt.new(10)).should eq(0)
    (BigInt.new(10) == BigInt.new(10)).should be_true
    (BigInt.new(10) < BigInt.new(20)).should be_true
  end

  it "comparison with Int" do
    (BigInt.new(10) <=> 20).should eq(-1)
    (BigInt.new(10) == 10).should be_true
  end

  it "bitwise" do
    (BigInt.new(0xFF) & BigInt.new(0x0F)).to_i.should eq(0x0F)
    (BigInt.new(1) << 10).to_i.should eq(1024)
  end

  it "negation and abs" do
    (-BigInt.new(42)).to_i.should eq(-42)
    BigInt.new(-42).abs.to_i.should eq(42)
  end

  it "zero?" do
    BigInt.new(0).zero?.should be_true
    BigInt.new(1).zero?.should be_false
  end

  it "to_big_f" do
    bf = BigInt.new(42).to_big_f
    bf.is_a?(BigFloat).should be_true
  end

  it "to_big_r" do
    br = BigInt.new(42).to_big_r
    br.is_a?(BigRational).should be_true
  end

  it "from_digits" do
    x = BigInt.from_digits([1, 2, 3])  # 321
    x.to_i.should eq(321)
  end

  it "exponentiation" do
    (BigInt.new(2) ** 10).to_i.should eq(1024)
  end

  it "clone returns self" do
    x = BigInt.new(42)
    x.clone.should eq(x)
  end
end

describe "BigFloat (stdlib wrapper)" do
  it "basic construction" do
    x = BigFloat.new(3.14)
    (x > BigFloat.new(3.0)).should be_true
  end

  it "inherits from Float" do
    BigFloat.new(1.0).is_a?(Float).should be_true
  end

  it "inherits from Number" do
    BigFloat.new(1.0).is_a?(Number).should be_true
  end

  it "nan? is false" do
    BigFloat.new(1.0).nan?.should be_false
  end

  it "infinite? is nil" do
    BigFloat.new(1.0).infinite?.should be_nil
  end

  it "arithmetic" do
    a = BigFloat.new(10.0)
    b = BigFloat.new(3.0)
    ((a + b) == BigFloat.new(13.0)).should be_true
    ((a - b) == BigFloat.new(7.0)).should be_true
    ((a * b) == BigFloat.new(30.0)).should be_true
  end

  it "string construction" do
    x = BigFloat.new("1.5")
    (x == BigFloat.new(1.5)).should be_true
  end

  it "rounding" do
    BigFloat.new(1.5).ceil.should eq(BigFloat.new(2.0))
    BigFloat.new(1.5).floor.should eq(BigFloat.new(1.0))
    BigFloat.new(1.5).trunc.should eq(BigFloat.new(1.0))
  end

  it "to_big_i" do
    BigFloat.new(42.9).to_big_i.should eq(BigInt.new(42))
  end
end

describe "BigRational (stdlib wrapper)" do
  it "basic construction" do
    x = BigRational.new(1, 3)
    x.numerator.should eq(BigInt.new(1))
    x.denominator.should eq(BigInt.new(3))
  end

  it "inherits from Number" do
    BigRational.new(1, 3).is_a?(Number).should be_true
  end

  it "arithmetic" do
    a = BigRational.new(1, 3)
    b = BigRational.new(1, 6)
    (a + b).should eq(BigRational.new(1, 2))
  end

  it "comparison" do
    (BigRational.new(1, 3) < BigRational.new(1, 2)).should be_true
  end

  it "to_f64" do
    BigRational.new(1, 2).to_f64.should eq(0.5)
  end

  it "to_big_i truncates" do
    BigRational.new(7, 2).to_big_i.should eq(BigInt.new(3))
  end

  it "inv" do
    BigRational.new(2, 3).inv.should eq(BigRational.new(3, 2))
  end

  it "floor/ceil" do
    BigRational.new(7, 2).floor.should eq(BigRational.new(3))
    BigRational.new(7, 2).ceil.should eq(BigRational.new(4))
  end
end

describe "BigDecimal (stdlib wrapper)" do
  it "basic construction" do
    x = BigDecimal.new("1.23")
    x.to_s.should eq("1.23")
  end

  it "inherits from Number" do
    BigDecimal.new("1.0").is_a?(Number).should be_true
  end

  it "arithmetic" do
    a = BigDecimal.new("1.5")
    b = BigDecimal.new("2.5")
    (a + b).should eq(BigDecimal.new("4.0"))
  end

  it "comparison" do
    (BigDecimal.new("1.5") < BigDecimal.new("2.5")).should be_true
  end
end

describe "Cross-type operations" do
  it "BigInt / BigFloat returns BigFloat" do
    result = BigInt.new(10) / BigFloat.new(3.0)
    result.is_a?(BigFloat).should be_true
  end

  it "BigInt / BigRational returns BigRational" do
    result = BigInt.new(10) / BigRational.new(3, 1)
    result.is_a?(BigRational).should be_true
  end

  it "BigInt.new(BigFloat) truncates" do
    BigInt.new(BigFloat.new(3.7)).should eq(BigInt.new(3))
  end

  it "BigFloat.new(BigInt)" do
    bf = BigFloat.new(BigInt.new(42))
    bf.should eq(BigFloat.new(42.0))
  end

  it "BigRational from BigInt pair" do
    r = BigRational.new(BigInt.new(7), BigInt.new(3))
    r.numerator.should eq(BigInt.new(7))
    r.denominator.should eq(BigInt.new(3))
  end
end
{% end %}
