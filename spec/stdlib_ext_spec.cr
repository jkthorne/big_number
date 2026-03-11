require "spec"

{% if flag?(:big_number_stdlib) %}
require "../src/big_number/stdlib"

describe "Phase 6: stdlib_ext" do
  describe "Int#to_big_* conversions" do
    it "to_big_i" do
      x = 42.to_big_i
      x.is_a?(BigInt).should be_true
      x.should eq(BigInt.new(42))
    end

    it "to_big_f" do
      x = 42.to_big_f
      x.is_a?(BigFloat).should be_true
      x.should eq(BigFloat.new(42))
    end

    it "to_big_r" do
      x = 42.to_big_r
      x.is_a?(BigRational).should be_true
      x.should eq(BigRational.new(42, 1))
    end

    it "to_big_d" do
      x = 42.to_big_d
      x.is_a?(BigDecimal).should be_true
      x.should eq(BigDecimal.new(42))
    end
  end

  describe "Float#to_big_* conversions" do
    it "to_big_i" do
      x = 42.5.to_big_i
      x.is_a?(BigInt).should be_true
      x.should eq(BigInt.new(42))
    end

    it "to_big_f" do
      x = 42.5.to_big_f
      x.is_a?(BigFloat).should be_true
    end

    it "to_big_r" do
      x = 0.5.to_big_r
      x.is_a?(BigRational).should be_true
      x.to_f64.should eq(0.5)
    end

    it "to_big_d" do
      x = 1.5.to_big_d
      x.is_a?(BigDecimal).should be_true
    end
  end

  describe "String#to_big_* conversions" do
    it "to_big_i" do
      "123".to_big_i.should eq(BigInt.new(123))
    end

    it "to_big_i with base" do
      "ff".to_big_i(16).should eq(BigInt.new(255))
    end

    it "to_big_f" do
      x = "1.5".to_big_f
      x.is_a?(BigFloat).should be_true
    end

    it "to_big_r" do
      "1/3".to_big_r.should eq(BigRational.new(1, 3))
    end

    it "to_big_d" do
      "1.23".to_big_d.should eq(BigDecimal.new("1.23"))
    end
  end

  describe "Int arithmetic with BigInt" do
    it "Int + BigInt" do
      (10 + BigInt.new(32)).should eq(BigInt.new(42))
    end

    it "Int - BigInt" do
      (100 - BigInt.new(58)).should eq(BigInt.new(42))
    end

    it "Int * BigInt" do
      (6 * BigInt.new(7)).should eq(BigInt.new(42))
    end

    it "Int % BigInt" do
      (10 % BigInt.new(3)).should eq(BigInt.new(1))
    end

    it "Int <=> BigInt" do
      (10 <=> BigInt.new(20)).should eq(-1)
      (20 <=> BigInt.new(10)).should eq(1)
      (10 <=> BigInt.new(10)).should eq(0)
    end

    it "Int == BigInt" do
      (42 == BigInt.new(42)).should be_true
      (42 == BigInt.new(43)).should be_false
    end

    it "Int &+ BigInt" do
      (10 &+ BigInt.new(32)).should eq(BigInt.new(42))
    end

    it "Int &- BigInt" do
      (100 &- BigInt.new(58)).should eq(BigInt.new(42))
    end

    it "Int &* BigInt" do
      (6 &* BigInt.new(7)).should eq(BigInt.new(42))
    end

    it "Int.gcd(BigInt)" do
      12.gcd(BigInt.new(8)).should eq(4)
    end

    it "Int.lcm(BigInt)" do
      12.lcm(BigInt.new(8)).should eq(BigInt.new(24))
    end
  end

  describe "Int arithmetic with BigRational" do
    it "Int + BigRational" do
      (1 + BigRational.new(1, 2)).should eq(BigRational.new(3, 2))
    end

    it "Int - BigRational" do
      (1 - BigRational.new(1, 3)).should eq(BigRational.new(2, 3))
    end

    it "Int * BigRational" do
      (3 * BigRational.new(1, 2)).should eq(BigRational.new(3, 2))
    end

    it "Int / BigRational" do
      result = 1 / BigRational.new(2, 1)
      result.should eq(BigRational.new(1, 2))
    end

    it "Int <=> BigRational" do
      (1 <=> BigRational.new(1, 2)).should eq(1)
      (0 <=> BigRational.new(1, 2)).should eq(-1)
    end
  end

  describe "Int arithmetic with BigFloat" do
    it "Int <=> BigFloat" do
      (10 <=> BigFloat.new(20.0)).should eq(-1)
      (20 <=> BigFloat.new(10.0)).should eq(1)
    end

    it "Int - BigFloat" do
      result = 10 - BigFloat.new(3.0)
      result.should eq(BigFloat.new(7.0))
    end

    it "Int / BigFloat" do
      result = 10 / BigFloat.new(4.0)
      result.should eq(BigFloat.new(2.5))
    end
  end

  describe "Number arithmetic with BigFloat" do
    it "Number + BigFloat" do
      result = 10 + BigFloat.new(5.0)
      result.should eq(BigFloat.new(15.0))
    end

    it "Number * BigFloat" do
      result = 3 * BigFloat.new(4.0)
      result.should eq(BigFloat.new(12.0))
    end
  end

  describe "Float comparisons with Big types" do
    it "Float <=> BigInt" do
      (10.0 <=> BigInt.new(20)).should eq(-1)
      (10.0 <=> BigInt.new(5)).should eq(1)
    end

    it "Float <=> BigFloat" do
      cmp = 10.0 <=> BigFloat.new(20.0)
      cmp.should eq(-1)
    end

    it "Float <=> BigRational" do
      cmp = 0.5 <=> BigRational.new(1, 3)
      cmp.not_nil!.should eq(1)
    end

    it "Float NaN <=> BigInt returns nil" do
      (Float64::NAN <=> BigInt.new(42)).should be_nil
    end
  end

  describe "BigFloat <=> BigRational" do
    it "compares correctly" do
      (BigFloat.new(0.5) <=> BigRational.new(1, 3)).should eq(1)
      (BigFloat.new(0.25) <=> BigRational.new(1, 2)).should eq(-1)
    end
  end

  describe "Number.expand_div for primitives" do
    it "Int32 / BigInt returns BigFloat" do
      result = 10_i32 / BigInt.new(3)
      result.is_a?(BigFloat).should be_true
    end

    it "Int64 / BigDecimal returns BigDecimal" do
      result = 10_i64 / BigDecimal.new("3")
      result.is_a?(BigDecimal).should be_true
    end

    it "Float64 / BigInt returns BigFloat" do
      result = 10.0 / BigInt.new(4)
      result.is_a?(BigFloat).should be_true
    end

    it "Float64 / BigFloat returns BigFloat" do
      result = 10.0 / BigFloat.new(4.0)
      result.is_a?(BigFloat).should be_true
    end

    it "Int32 / BigRational returns BigRational" do
      result = 10_i32 / BigRational.new(3, 1)
      result.is_a?(BigRational).should be_true
    end
  end

  describe "Math module" do
    it "Math.isqrt(BigInt)" do
      Math.isqrt(BigInt.new(16)).should eq(BigInt.new(4))
      Math.isqrt(BigInt.new(15)).should eq(BigInt.new(3))
      Math.isqrt(BigInt.new(0)).should eq(BigInt.new(0))
      Math.isqrt(BigInt.new(1)).should eq(BigInt.new(1))
    end

    it "Math.sqrt(BigInt)" do
      result = Math.sqrt(BigInt.new(4))
      result.is_a?(BigFloat).should be_true
      result.should eq(BigFloat.new(2.0))
    end

    it "Math.sqrt(BigFloat)" do
      result = Math.sqrt(BigFloat.new(4.0))
      result.is_a?(BigFloat).should be_true
      result.should eq(BigFloat.new(2.0))
    end

    it "Math.sqrt(BigFloat) for large values" do
      result = Math.sqrt(BigFloat.new(1000000.0))
      result.should eq(BigFloat.new(1000.0))
    end

    it "Math.sqrt(BigRational)" do
      result = Math.sqrt(BigRational.new(4, 1))
      result.is_a?(BigFloat).should be_true
    end

    it "Math.pw2ceil(BigInt)" do
      Math.pw2ceil(BigInt.new(33)).should eq(BigInt.new(64))
      Math.pw2ceil(BigInt.new(64)).should eq(BigInt.new(64))
      Math.pw2ceil(BigInt.new(-5)).should eq(BigInt.new(1))
      Math.pw2ceil(BigInt.new(1)).should eq(BigInt.new(1))
    end
  end

  describe "Random" do
    it "rand(BigInt)" do
      max = BigInt.new(1000)
      result = Random.new.rand(max)
      result.is_a?(BigInt).should be_true
      (result >= 0).should be_true
      (result < max).should be_true
    end

    it "rand(Range(BigInt, BigInt))" do
      lo = BigInt.new(100)
      hi = BigInt.new(200)
      result = Random.new.rand(lo..hi)
      result.is_a?(BigInt).should be_true
      (result >= lo).should be_true
      (result <= hi).should be_true
    end

    it "rand(BigInt) distribution is reasonable" do
      max = BigInt.new(10)
      seen = Set(Int32).new
      100.times do
        v = Random.new.rand(max).to_i
        seen << v
      end
      # Should see multiple different values
      seen.size.should be > 3
    end
  end

  describe "Crystal::Hasher — numeric hash equality" do
    it "BigInt.new(42).hash == 42.hash" do
      BigInt.new(42).hash.should eq(42.hash)
    end

    it "BigInt.new(0).hash == 0.hash" do
      BigInt.new(0).hash.should eq(0.hash)
    end

    it "BigInt.new(-1).hash == -1.hash" do
      BigInt.new(-1).hash.should eq(-1.hash)
    end

    it "BigInt.new(1000000).hash == 1000000.hash" do
      BigInt.new(1000000).hash.should eq(1000000.hash)
    end

    it "equal BigInts have equal hashes" do
      a = BigInt.new("123456789012345678901234567890")
      b = BigInt.new("123456789012345678901234567890")
      a.hash.should eq(b.hash)
    end

    it "BigFloat.new(42.0).hash == 42.hash" do
      BigFloat.new(42.0).hash.should eq(42.hash)
    end

    it "BigFloat.new(0.0).hash == 0.hash" do
      BigFloat.new(0.0).hash.should eq(0.hash)
    end

    it "BigFloat.new(0.5).hash == 0.5.hash" do
      BigFloat.new(0.5).hash.should eq(0.5.hash)
    end

    it "BigFloat.new(-1.0).hash == -1.hash" do
      BigFloat.new(-1.0).hash.should eq((-1).hash)
    end

    it "BigRational.new(42, 1).hash == 42.hash" do
      BigRational.new(42, 1).hash.should eq(42.hash)
    end

    it "BigRational.new(0, 1).hash == 0.hash" do
      BigRational.new(0, 1).hash.should eq(0.hash)
    end

    it "equal BigRationals have equal hashes" do
      a = BigRational.new(1, 3)
      b = BigRational.new(2, 6)
      a.hash.should eq(b.hash)
    end

    it "BigDecimal.new(42).hash == 42.hash" do
      BigDecimal.new(42).hash.should eq(42.hash)
    end

    it "BigDecimal.new(0).hash == 0.hash" do
      BigDecimal.new(0).hash.should eq(0.hash)
    end
  end

  describe "Float#fdiv with Big types" do
    it "Float64#fdiv(BigInt)" do
      result = 10.0.fdiv(BigInt.new(3))
      result.is_a?(Float64).should be_true
    end

    it "Float64#fdiv(BigFloat)" do
      result = 10.0.fdiv(BigFloat.new(3.0))
      result.is_a?(Float64).should be_true
    end
  end
end
{% end %}
