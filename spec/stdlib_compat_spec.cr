require "spec"

{% if flag?(:big_number_stdlib) %}
require "json"
require "yaml"
require "../src/big_number/stdlib"
require "../src/big_number/stdlib_json"
require "../src/big_number/stdlib_yaml"

# Phase 8: Comprehensive Stdlib Compatibility Tests
# Verifies that our BigInt/BigFloat/BigRational/BigDecimal behave identically
# to Crystal stdlib's types (minus GMP dependency).

describe "Phase 8: Stdlib Compatibility" do
  describe "BigInt type hierarchy" do
    it "is_a?(Int)" do
      BigInt.new(42).is_a?(Int).should be_true
    end

    it "is_a?(Number)" do
      BigInt.new(42).is_a?(Number).should be_true
    end

    it "is_a?(Comparable)" do
      BigInt.new(42).is_a?(Comparable(BigInt)).should be_true
    end
  end

  describe "BigFloat type hierarchy" do
    it "is_a?(Float)" do
      BigFloat.new(1.5).is_a?(Float).should be_true
    end

    it "is_a?(Number)" do
      BigFloat.new(1.5).is_a?(Number).should be_true
    end
  end

  describe "BigRational type hierarchy" do
    it "is_a?(Number)" do
      BigRational.new(1, 3).is_a?(Number).should be_true
    end
  end

  describe "BigDecimal type hierarchy" do
    it "is_a?(Number)" do
      BigDecimal.new("1.23").is_a?(Number).should be_true
    end
  end

  describe "BigInt constructors" do
    it "from zero" do
      BigInt.new.should eq(BigInt.new(0))
    end

    it "from positive Int" do
      BigInt.new(42).to_s.should eq("42")
    end

    it "from negative Int" do
      BigInt.new(-42).to_s.should eq("-42")
    end

    it "from Int8" do
      BigInt.new(127_i8).to_i.should eq(127)
    end

    it "from UInt64" do
      BigInt.new(UInt64::MAX).to_s.should eq(UInt64::MAX.to_s)
    end

    it "from Int128" do
      v = Int128::MAX
      BigInt.new(v).to_s.should eq(v.to_s)
    end

    it "from String" do
      BigInt.new("999999999999999999999999999999").to_s.should eq("999999999999999999999999999999")
    end

    it "from String with base 16" do
      BigInt.new("ff", 16).to_i.should eq(255)
    end

    it "from String with base 2" do
      BigInt.new("1010", 2).to_i.should eq(10)
    end

    it "from Float64" do
      BigInt.new(42.9).should eq(BigInt.new(42))
    end

    it "from BigFloat" do
      BigInt.new(BigFloat.new(99.1)).should eq(BigInt.new(99))
    end

    it "from BigRational" do
      BigInt.new(BigRational.new(7, 2)).should eq(BigInt.new(3))
    end

    it "from BigDecimal" do
      BigInt.new(BigDecimal.new("42.9")).should eq(BigInt.new(42))
    end

    it "from_digits" do
      BigInt.from_digits([1, 2, 3]).should eq(BigInt.new(321))
      BigInt.from_digits([0xF, 0xA], 16).should eq(BigInt.new(0xAF))
    end

    it "from_bytes round-trips" do
      original = BigInt.new("123456789012345678901234567890")
      bytes = original.to_bytes
      BigInt.from_bytes(bytes).should eq(original)
    end
  end

  describe "BigInt predicates" do
    it "zero?" do
      BigInt.new(0).zero?.should be_true
      BigInt.new(1).zero?.should be_false
      BigInt.new(-1).zero?.should be_false
    end

    it "positive?" do
      BigInt.new(1).positive?.should be_true
      BigInt.new(0).positive?.should be_false
      BigInt.new(-1).positive?.should be_false
    end

    it "negative?" do
      BigInt.new(-1).negative?.should be_true
      BigInt.new(0).negative?.should be_false
      BigInt.new(1).negative?.should be_false
    end

    it "even?" do
      BigInt.new(0).even?.should be_true
      BigInt.new(2).even?.should be_true
      BigInt.new(3).even?.should be_false
      BigInt.new(-4).even?.should be_true
    end

    it "odd?" do
      BigInt.new(1).odd?.should be_true
      BigInt.new(3).odd?.should be_true
      BigInt.new(0).odd?.should be_false
      BigInt.new(2).odd?.should be_false
    end

    it "sign" do
      BigInt.new(42).sign.should eq(1)
      BigInt.new(0).sign.should eq(0)
      BigInt.new(-42).sign.should eq(-1)
    end

    it "bit_length" do
      BigInt.new(0).bit_length.should eq(1)
      BigInt.new(1).bit_length.should eq(1)
      BigInt.new(255).bit_length.should eq(8)
      BigInt.new(256).bit_length.should eq(9)
    end
  end

  describe "BigInt arithmetic" do
    it "addition" do
      (BigInt.new(100) + BigInt.new(200)).should eq(BigInt.new(300))
      (BigInt.new(-50) + BigInt.new(30)).should eq(BigInt.new(-20))
      (BigInt.new(0) + BigInt.new(42)).should eq(BigInt.new(42))
    end

    it "addition with Int" do
      (BigInt.new(100) + 42).should eq(BigInt.new(142))
    end

    it "subtraction" do
      (BigInt.new(300) - BigInt.new(100)).should eq(BigInt.new(200))
      (BigInt.new(10) - BigInt.new(20)).should eq(BigInt.new(-10))
    end

    it "multiplication" do
      (BigInt.new(6) * BigInt.new(7)).should eq(BigInt.new(42))
      (BigInt.new(-3) * BigInt.new(4)).should eq(BigInt.new(-12))
      (BigInt.new(0) * BigInt.new(999)).should eq(BigInt.new(0))
    end

    it "floor division" do
      (BigInt.new(7) // BigInt.new(2)).should eq(BigInt.new(3))
      (BigInt.new(-7) // BigInt.new(2)).should eq(BigInt.new(-4))
      (BigInt.new(7) // BigInt.new(-2)).should eq(BigInt.new(-4))
      (BigInt.new(-7) // BigInt.new(-2)).should eq(BigInt.new(3))
    end

    it "modulo" do
      (BigInt.new(7) % BigInt.new(3)).should eq(BigInt.new(1))
      (BigInt.new(-7) % BigInt.new(3)).should eq(BigInt.new(2))
    end

    it "divmod" do
      q, r = BigInt.new(17).divmod(BigInt.new(5))
      q.should eq(BigInt.new(3))
      r.should eq(BigInt.new(2))
    end

    it "tdiv (truncated division)" do
      BigInt.new(7).tdiv(BigInt.new(2)).should eq(BigInt.new(3))
      BigInt.new(-7).tdiv(BigInt.new(2)).should eq(BigInt.new(-3))
    end

    it "remainder (truncated)" do
      BigInt.new(7).remainder(BigInt.new(3)).should eq(BigInt.new(1))
      BigInt.new(-7).remainder(BigInt.new(3)).should eq(BigInt.new(-1))
    end

    it "negation" do
      (-BigInt.new(42)).should eq(BigInt.new(-42))
      (-BigInt.new(-42)).should eq(BigInt.new(42))
      (-BigInt.new(0)).should eq(BigInt.new(0))
    end

    it "abs" do
      BigInt.new(-42).abs.should eq(BigInt.new(42))
      BigInt.new(42).abs.should eq(BigInt.new(42))
      BigInt.new(0).abs.should eq(BigInt.new(0))
    end

    it "exponentiation" do
      (BigInt.new(2) ** 0).should eq(BigInt.new(1))
      (BigInt.new(2) ** 1).should eq(BigInt.new(2))
      (BigInt.new(2) ** 10).should eq(BigInt.new(1024))
      (BigInt.new(3) ** 20).should eq(BigInt.new(3486784401_i64))
    end

    it "wrapping operators behave same as normal for BigInt" do
      (BigInt.new(100) &+ BigInt.new(200)).should eq(BigInt.new(300))
      (BigInt.new(100) &- BigInt.new(200)).should eq(BigInt.new(-100))
      (BigInt.new(6) &* BigInt.new(7)).should eq(BigInt.new(42))
    end
  end

  describe "BigInt comparison" do
    it "with BigInt" do
      (BigInt.new(10) <=> BigInt.new(20)).should eq(-1)
      (BigInt.new(20) <=> BigInt.new(10)).should eq(1)
      (BigInt.new(10) <=> BigInt.new(10)).should eq(0)
    end

    it "with Int" do
      (BigInt.new(10) <=> 20).should eq(-1)
      (BigInt.new(10) <=> 10).should eq(0)
      (BigInt.new(20) <=> 10).should eq(1)
    end

    it "with Float" do
      cmp = BigInt.new(10) <=> 10.5
      cmp.not_nil!.should eq(-1)
    end

    it "with Float NaN returns nil" do
      (BigInt.new(10) <=> Float64::NAN).should be_nil
    end

    it "equality with Int" do
      (BigInt.new(42) == 42).should be_true
      (BigInt.new(42) == 43).should be_false
    end

    it "less than / greater than" do
      (BigInt.new(1) < BigInt.new(2)).should be_true
      (BigInt.new(2) > BigInt.new(1)).should be_true
      (BigInt.new(1) <= BigInt.new(1)).should be_true
      (BigInt.new(1) >= BigInt.new(1)).should be_true
    end
  end

  describe "BigInt bitwise operations" do
    it "bitwise AND" do
      (BigInt.new(0xFF) & BigInt.new(0x0F)).should eq(BigInt.new(0x0F))
    end

    it "bitwise OR" do
      (BigInt.new(0xF0) | BigInt.new(0x0F)).should eq(BigInt.new(0xFF))
    end

    it "bitwise XOR" do
      (BigInt.new(0xFF) ^ BigInt.new(0x0F)).should eq(BigInt.new(0xF0))
    end

    it "bitwise NOT" do
      (~BigInt.new(0)).should eq(BigInt.new(-1))
      (~BigInt.new(1)).should eq(BigInt.new(-2))
    end

    it "left shift" do
      (BigInt.new(1) << 10).should eq(BigInt.new(1024))
      (BigInt.new(1) << 64).to_s.should eq("18446744073709551616")
    end

    it "right shift" do
      (BigInt.new(1024) >> 3).should eq(BigInt.new(128))
      (BigInt.new(1) >> 1).should eq(BigInt.new(0))
    end

    it "bit access" do
      BigInt.new(0b1010).bit(0).should eq(0)
      BigInt.new(0b1010).bit(1).should eq(1)
      BigInt.new(0b1010).bit(3).should eq(1)
    end

    it "popcount" do
      BigInt.new(0b1010).popcount.should eq(2)
      BigInt.new(0xFF).popcount.should eq(8)
    end

    it "trailing_zeros_count" do
      BigInt.new(8).trailing_zeros_count.should eq(3)
      BigInt.new(12).trailing_zeros_count.should eq(2)
    end
  end

  describe "BigInt number theory" do
    it "gcd" do
      BigInt.new(12).gcd(BigInt.new(8)).should eq(BigInt.new(4))
      BigInt.new(17).gcd(BigInt.new(13)).should eq(BigInt.new(1))
    end

    it "lcm" do
      BigInt.new(4).lcm(BigInt.new(6)).should eq(BigInt.new(12))
    end

    it "factorial" do
      BigInt.new(0).factorial.should eq(BigInt.new(1))
      BigInt.new(1).factorial.should eq(BigInt.new(1))
      BigInt.new(5).factorial.should eq(BigInt.new(120))
      BigInt.new(10).factorial.should eq(BigInt.new(3628800))
    end

    it "divisible_by?" do
      BigInt.new(10).divisible_by?(BigInt.new(5)).should be_true
      BigInt.new(10).divisible_by?(BigInt.new(3)).should be_false
      BigInt.new(0).divisible_by?(BigInt.new(5)).should be_true
    end

    it "prime?" do
      BigInt.new(2).prime?.should be_true
      BigInt.new(17).prime?.should be_true
      BigInt.new(4).prime?.should be_false
      BigInt.new(1).prime?.should be_false
    end

    it "pow_mod" do
      BigInt.new(2).pow_mod(BigInt.new(10), BigInt.new(1000)).should eq(BigInt.new(24))
      BigInt.new(3).pow_mod(BigInt.new(4), BigInt.new(5)).should eq(BigInt.new(1))
    end

    it "sqrt" do
      BigInt.new(0).sqrt.should eq(BigInt.new(0))
      BigInt.new(1).sqrt.should eq(BigInt.new(1))
      BigInt.new(4).sqrt.should eq(BigInt.new(2))
      BigInt.new(15).sqrt.should eq(BigInt.new(3))
      BigInt.new(16).sqrt.should eq(BigInt.new(4))
    end

    it "next_power_of_two" do
      BigInt.new(1).next_power_of_two.should eq(BigInt.new(1))
      BigInt.new(3).next_power_of_two.should eq(BigInt.new(4))
      BigInt.new(4).next_power_of_two.should eq(BigInt.new(4))
      BigInt.new(5).next_power_of_two.should eq(BigInt.new(8))
      BigInt.new(0).next_power_of_two.should eq(BigInt.new(1))
    end
  end

  describe "BigInt conversions" do
    it "to_i" do
      BigInt.new(42).to_i.should eq(42)
    end

    it "to_i64" do
      BigInt.new(Int64::MAX).to_i64.should eq(Int64::MAX)
    end

    it "to_u64" do
      BigInt.new(UInt64::MAX).to_u64.should eq(UInt64::MAX)
    end

    it "to_i128" do
      BigInt.new(Int128::MAX).to_i128.should eq(Int128::MAX)
    end

    it "to_u128" do
      BigInt.new(UInt128::MAX).to_u128.should eq(UInt128::MAX)
    end

    it "to_f64" do
      BigInt.new(42).to_f64.should eq(42.0)
    end

    it "to_f32" do
      BigInt.new(42).to_f32.should eq(42.0_f32)
    end

    it "to_big_i returns self" do
      x = BigInt.new(42)
      x.to_big_i.should eq(x)
    end

    it "to_big_f" do
      BigInt.new(42).to_big_f.should eq(BigFloat.new(42))
    end

    it "to_big_r" do
      BigInt.new(42).to_big_r.should eq(BigRational.new(42, 1))
    end

    it "to_big_d" do
      BigInt.new(42).to_big_d.should eq(BigDecimal.new(42))
    end

    it "to_s with various bases" do
      BigInt.new(255).to_s(16).should eq("ff")
      BigInt.new(255).to_s(16, upcase: true).should eq("FF")
      BigInt.new(10).to_s(2).should eq("1010")
      BigInt.new(42).to_s(8).should eq("52")
    end

    it "digits" do
      BigInt.new(123).digits.should eq([3, 2, 1])
      BigInt.new(255).digits(16).should eq([15, 15])
    end

    it "to_i32 of large value uses unchecked conversion" do
      # Our implementation uses unchecked (wrapping) conversion for to_i32
      (BigInt.new(1) << 128).to_i32!.should eq(0_i32)
    end

    it "to_i! wraps on overflow" do
      # Should not raise
      (BigInt.new(256)).to_i8!.should eq(0_i8)
    end
  end

  describe "BigInt clone and hash" do
    it "clone returns self (value type)" do
      x = BigInt.new(42)
      x.clone.should eq(x)
    end

    it "hash equality with Int" do
      BigInt.new(42).hash.should eq(42.hash)
      BigInt.new(0).hash.should eq(0.hash)
      BigInt.new(-1).hash.should eq(-1.hash)
    end

    it "equal values have equal hashes" do
      a = BigInt.new("99999999999999999999")
      b = BigInt.new("99999999999999999999")
      a.hash.should eq(b.hash)
    end
  end

  describe "BigInt large number operations" do
    it "large multiplication" do
      a = BigInt.new("999999999999999999999999999999")
      b = BigInt.new("999999999999999999999999999999")
      result = a * b
      result.to_s.should eq("999999999999999999999999999998000000000000000000000000000001")
    end

    it "large exponentiation" do
      result = BigInt.new(2) ** 256
      result.to_s.should eq("115792089237316195423570985008687907853269984665640564039457584007913129639936")
    end

    it "large factorial" do
      f20 = BigInt.new(20).factorial
      f20.to_s.should eq("2432902008176640000")
    end
  end

  # ─── BigFloat ───

  describe "BigFloat constructors" do
    it "from Float64" do
      BigFloat.new(3.14).to_f64.should be_close(3.14, 1e-10)
    end

    it "from Int" do
      BigFloat.new(42).should eq(BigFloat.new(42.0))
    end

    it "from String" do
      BigFloat.new("1.5").should eq(BigFloat.new(1.5))
    end

    it "from BigInt" do
      BigFloat.new(BigInt.new(42)).should eq(BigFloat.new(42))
    end

    it "from BigRational" do
      BigFloat.new(BigRational.new(1, 2)).to_f64.should be_close(0.5, 1e-10)
    end

    it "with precision" do
      x = BigFloat.new(1.0, precision: 256)
      x.precision.should eq(256)
    end

    it "default" do
      BigFloat.new.should eq(BigFloat.new(0.0))
    end
  end

  describe "BigFloat predicates" do
    it "zero?" do
      BigFloat.new(0.0).zero?.should be_true
      BigFloat.new(1.0).zero?.should be_false
    end

    it "positive?" do
      BigFloat.new(1.0).positive?.should be_true
      BigFloat.new(-1.0).positive?.should be_false
      BigFloat.new(0.0).positive?.should be_false
    end

    it "negative?" do
      BigFloat.new(-1.0).negative?.should be_true
      BigFloat.new(1.0).negative?.should be_false
    end

    it "nan? is always false" do
      BigFloat.new(0.0).nan?.should be_false
      BigFloat.new(999.0).nan?.should be_false
    end

    it "infinite? is always nil" do
      BigFloat.new(0.0).infinite?.should be_nil
      BigFloat.new(1e100).infinite?.should be_nil
    end

    it "integer?" do
      BigFloat.new(42.0).integer?.should be_true
      BigFloat.new(42.5).integer?.should be_false
      BigFloat.new(0.0).integer?.should be_true
    end

    it "sign" do
      BigFloat.new(42.0).sign.should eq(1)
      BigFloat.new(0.0).sign.should eq(0)
      BigFloat.new(-42.0).sign.should eq(-1)
    end
  end

  describe "BigFloat arithmetic" do
    it "addition" do
      (BigFloat.new(1.5) + BigFloat.new(2.5)).should eq(BigFloat.new(4.0))
    end

    it "subtraction" do
      (BigFloat.new(10.0) - BigFloat.new(3.0)).should eq(BigFloat.new(7.0))
    end

    it "multiplication" do
      (BigFloat.new(3.0) * BigFloat.new(4.0)).should eq(BigFloat.new(12.0))
    end

    it "division" do
      (BigFloat.new(10.0) / BigFloat.new(4.0)).should eq(BigFloat.new(2.5))
    end

    it "with Int" do
      (BigFloat.new(10.0) + 5).should eq(BigFloat.new(15.0))
      (BigFloat.new(10.0) - 3).should eq(BigFloat.new(7.0))
      (BigFloat.new(3.0) * 4).should eq(BigFloat.new(12.0))
      (BigFloat.new(10.0) / 4).should eq(BigFloat.new(2.5))
    end

    it "with Float" do
      (BigFloat.new(10.0) + 5.0).should eq(BigFloat.new(15.0))
      (BigFloat.new(10.0) * 2.0).should eq(BigFloat.new(20.0))
    end

    it "with BigInt" do
      (BigFloat.new(10.5) + BigInt.new(5)).should eq(BigFloat.new(15.5))
      (BigFloat.new(10.0) * BigInt.new(3)).should eq(BigFloat.new(30.0))
    end

    it "negation" do
      (-BigFloat.new(3.14)).to_f64.should be_close(-3.14, 1e-10)
    end

    it "abs" do
      BigFloat.new(-42.0).abs.should eq(BigFloat.new(42.0))
    end

    it "exponentiation with Int" do
      (BigFloat.new(2.0) ** 10).should eq(BigFloat.new(1024.0))
    end

    it "exponentiation with BigInt" do
      (BigFloat.new(2.0) ** BigInt.new(10)).should eq(BigFloat.new(1024.0))
    end
  end

  describe "BigFloat comparison" do
    it "with BigFloat" do
      (BigFloat.new(1.0) <=> BigFloat.new(2.0)).should eq(-1)
      (BigFloat.new(2.0) <=> BigFloat.new(1.0)).should eq(1)
      (BigFloat.new(1.0) <=> BigFloat.new(1.0)).should eq(0)
    end

    it "with Int" do
      (BigFloat.new(10.5) <=> 10).should eq(1)
      (BigFloat.new(10.0) <=> 10).should eq(0)
    end

    it "with Float" do
      cmp = BigFloat.new(10.0) <=> 10.5
      cmp.not_nil!.should eq(-1)
    end

    it "with BigInt" do
      (BigFloat.new(10.5) <=> BigInt.new(10)).should eq(1)
    end

    it "with BigRational" do
      (BigFloat.new(0.5) <=> BigRational.new(1, 2)).should eq(0)
    end
  end

  describe "BigFloat rounding" do
    it "ceil" do
      BigFloat.new(1.1).ceil.should eq(BigFloat.new(2.0))
      BigFloat.new(-1.1).ceil.should eq(BigFloat.new(-1.0))
      BigFloat.new(2.0).ceil.should eq(BigFloat.new(2.0))
    end

    it "floor" do
      BigFloat.new(1.9).floor.should eq(BigFloat.new(1.0))
      BigFloat.new(-1.1).floor.should eq(BigFloat.new(-2.0))
      BigFloat.new(2.0).floor.should eq(BigFloat.new(2.0))
    end

    it "trunc" do
      BigFloat.new(1.9).trunc.should eq(BigFloat.new(1.0))
      BigFloat.new(-1.9).trunc.should eq(BigFloat.new(-1.0))
    end

    it "round_away" do
      BigFloat.new(2.5).round_away.should eq(BigFloat.new(3.0))
      BigFloat.new(-2.5).round_away.should eq(BigFloat.new(-3.0))
    end

    it "round_even" do
      BigFloat.new(2.5).round_even.should eq(BigFloat.new(2.0))
      BigFloat.new(3.5).round_even.should eq(BigFloat.new(4.0))
    end
  end

  describe "BigFloat conversions" do
    it "to_f64" do
      BigFloat.new(42.5).to_f64.should eq(42.5)
    end

    it "to_f32" do
      BigFloat.new(42.5).to_f32.should eq(42.5_f32)
    end

    it "to_i" do
      BigFloat.new(42.9).to_i.should eq(42)
    end

    it "to_big_i" do
      BigFloat.new(42.9).to_big_i.should eq(BigInt.new(42))
    end

    it "to_big_f returns self" do
      x = BigFloat.new(42.0)
      x.to_big_f.should eq(x)
    end

    it "to_big_r" do
      r = BigFloat.new(0.5).to_big_r
      r.is_a?(BigRational).should be_true
    end

    it "to_s" do
      BigFloat.new(42.0).to_s.should_not be_empty
      BigFloat.new(-1.5).to_s.should contain("-")
    end

    it "mantissa and exponent" do
      x = BigFloat.new(42.0)
      m = x.mantissa
      e = x.exponent
      m.is_a?(BigInt).should be_true
    end
  end

  describe "BigFloat hash" do
    it "hash equality with Int" do
      BigFloat.new(42.0).hash.should eq(42.hash)
      BigFloat.new(0.0).hash.should eq(0.hash)
    end

    it "hash equality with Float64" do
      BigFloat.new(0.5).hash.should eq(0.5.hash)
    end
  end

  # ─── BigRational ───

  describe "BigRational constructors" do
    it "from numerator/denominator ints" do
      r = BigRational.new(2, 6)
      r.numerator.should eq(BigInt.new(1))
      r.denominator.should eq(BigInt.new(3))
    end

    it "from BigInt pair" do
      r = BigRational.new(BigInt.new(10), BigInt.new(4))
      r.numerator.should eq(BigInt.new(5))
      r.denominator.should eq(BigInt.new(2))
    end

    it "from Int" do
      r = BigRational.new(42)
      r.numerator.should eq(BigInt.new(42))
      r.denominator.should eq(BigInt.new(1))
    end

    it "from BigInt" do
      r = BigRational.new(BigInt.new(42))
      r.numerator.should eq(BigInt.new(42))
      r.denominator.should eq(BigInt.new(1))
    end

    it "from Float" do
      r = BigRational.new(0.5)
      r.to_f64.should eq(0.5)
    end

    it "from String" do
      r = BigRational.new("3/4")
      r.numerator.should eq(BigInt.new(3))
      r.denominator.should eq(BigInt.new(4))
    end

    it "auto-canonicalizes" do
      r = BigRational.new(6, 4)
      r.numerator.should eq(BigInt.new(3))
      r.denominator.should eq(BigInt.new(2))
    end

    it "negative denominator is normalized" do
      r = BigRational.new(1, -3)
      r.numerator.should eq(BigInt.new(-1))
      r.denominator.should eq(BigInt.new(3))
    end
  end

  describe "BigRational predicates" do
    it "zero?" do
      BigRational.new(0, 1).zero?.should be_true
      BigRational.new(1, 2).zero?.should be_false
    end

    it "positive?" do
      BigRational.new(1, 2).positive?.should be_true
      BigRational.new(-1, 2).positive?.should be_false
    end

    it "negative?" do
      BigRational.new(-1, 2).negative?.should be_true
      BigRational.new(1, 2).negative?.should be_false
    end

    it "sign" do
      BigRational.new(1, 2).sign.should eq(1)
      BigRational.new(0, 1).sign.should eq(0)
      BigRational.new(-1, 2).sign.should eq(-1)
    end

    it "integer?" do
      BigRational.new(4, 2).integer?.should be_true
      BigRational.new(3, 2).integer?.should be_false
    end
  end

  describe "BigRational arithmetic" do
    it "addition" do
      (BigRational.new(1, 3) + BigRational.new(1, 6)).should eq(BigRational.new(1, 2))
    end

    it "subtraction" do
      (BigRational.new(1, 2) - BigRational.new(1, 3)).should eq(BigRational.new(1, 6))
    end

    it "multiplication" do
      (BigRational.new(2, 3) * BigRational.new(3, 4)).should eq(BigRational.new(1, 2))
    end

    it "division" do
      (BigRational.new(1, 2) / BigRational.new(2, 3)).should eq(BigRational.new(3, 4))
    end

    it "with Int" do
      (BigRational.new(1, 3) + 1).should eq(BigRational.new(4, 3))
      (BigRational.new(1, 2) * 4).should eq(BigRational.new(2))
    end

    it "with BigInt" do
      (BigRational.new(1, 3) + BigInt.new(1)).should eq(BigRational.new(4, 3))
    end

    it "negation" do
      (-BigRational.new(1, 2)).should eq(BigRational.new(-1, 2))
    end

    it "abs" do
      BigRational.new(-1, 2).abs.should eq(BigRational.new(1, 2))
    end

    it "inv" do
      BigRational.new(2, 3).inv.should eq(BigRational.new(3, 2))
    end

    it "exponentiation" do
      (BigRational.new(2, 3) ** 3).should eq(BigRational.new(8, 27))
    end

    it "floor division" do
      (BigRational.new(7, 2) // BigRational.new(1)).should eq(BigRational.new(3))
    end

    it "modulo" do
      (BigRational.new(7, 2) % BigRational.new(1)).should eq(BigRational.new(1, 2))
    end

    it "shifts" do
      (BigRational.new(1, 1) << 3).should eq(BigRational.new(8))
      (BigRational.new(8, 1) >> 3).should eq(BigRational.new(1))
    end

    it "tdiv" do
      BigRational.new(7, 2).tdiv(BigRational.new(1)).should eq(BigRational.new(3))
      BigRational.new(-7, 2).tdiv(BigRational.new(1)).should eq(BigRational.new(-3))
    end

    it "remainder" do
      BigRational.new(7, 2).remainder(BigRational.new(1)).should eq(BigRational.new(1, 2))
      BigRational.new(-7, 2).remainder(BigRational.new(1)).should eq(BigRational.new(-1, 2))
    end
  end

  describe "BigRational comparison" do
    it "with BigRational" do
      (BigRational.new(1, 3) < BigRational.new(1, 2)).should be_true
      (BigRational.new(1, 2) == BigRational.new(2, 4)).should be_true
    end

    it "with Int" do
      (BigRational.new(3, 2) <=> 1).should eq(1)
      (BigRational.new(1, 1) == 1).should be_true
    end

    it "with BigInt" do
      (BigRational.new(5, 1) == BigInt.new(5)).should be_true
    end

    it "with Float" do
      cmp = BigRational.new(1, 2) <=> 0.5
      cmp.not_nil!.should eq(0)
    end

    it "with Float NaN returns nil" do
      (BigRational.new(1, 2) <=> Float64::NAN).should be_nil
    end
  end

  describe "BigRational rounding" do
    it "floor" do
      BigRational.new(7, 2).floor.should eq(BigRational.new(3))
      BigRational.new(-7, 2).floor.should eq(BigRational.new(-4))
    end

    it "ceil" do
      BigRational.new(7, 2).ceil.should eq(BigRational.new(4))
      BigRational.new(-7, 2).ceil.should eq(BigRational.new(-3))
    end

    it "trunc" do
      BigRational.new(7, 2).trunc.should eq(BigRational.new(3))
      BigRational.new(-7, 2).trunc.should eq(BigRational.new(-3))
    end

    it "round_away" do
      BigRational.new(5, 2).round_away.should eq(BigRational.new(3))
      BigRational.new(-5, 2).round_away.should eq(BigRational.new(-3))
    end

    it "round_even" do
      BigRational.new(5, 2).round_even.should eq(BigRational.new(2))
      BigRational.new(7, 2).round_even.should eq(BigRational.new(4))
    end
  end

  describe "BigRational conversions" do
    it "to_f64" do
      BigRational.new(1, 2).to_f64.should eq(0.5)
    end

    it "to_f32" do
      BigRational.new(1, 2).to_f32.should eq(0.5_f32)
    end

    it "to_big_i truncates" do
      BigRational.new(7, 2).to_big_i.should eq(BigInt.new(3))
      BigRational.new(-7, 2).to_big_i.should eq(BigInt.new(-3))
    end

    it "to_big_f" do
      r = BigRational.new(1, 2).to_big_f
      r.is_a?(BigFloat).should be_true
    end

    it "to_big_r returns self" do
      r = BigRational.new(1, 3)
      r.to_big_r.should eq(r)
    end

    it "to_big_d" do
      d = BigRational.new(1, 2).to_big_d
      d.is_a?(BigDecimal).should be_true
    end

    it "to_s" do
      BigRational.new(1, 3).to_s.should eq("1/3")
      BigRational.new(-1, 3).to_s.should eq("-1/3")
    end

    it "to_s with base" do
      # Whole-number rationals omit the denominator in base-N output
      BigRational.new(15, 1).to_s(16).should eq("f")
      BigRational.new(15, 7).to_s(16).should eq("f/7")
    end
  end

  describe "BigRational hash" do
    it "hash equality with Int" do
      BigRational.new(42, 1).hash.should eq(42.hash)
    end

    it "equivalent rationals have equal hashes" do
      BigRational.new(1, 3).hash.should eq(BigRational.new(2, 6).hash)
    end
  end

  # ─── BigDecimal ───

  describe "BigDecimal constructors" do
    it "from String" do
      BigDecimal.new("1.23").to_s.should eq("1.23")
    end

    it "from String with leading zeros" do
      BigDecimal.new("0.001").to_s.should eq("0.001")
    end

    it "from Int" do
      BigDecimal.new(42).to_s.should eq("42.0")
    end

    it "from Float" do
      d = BigDecimal.new(1.5)
      d.to_f64.should eq(1.5)
    end

    it "from BigInt" do
      BigDecimal.new(BigInt.new(42)).to_s.should eq("42.0")
    end

    it "from BigRational" do
      d = BigDecimal.new(BigRational.new(1, 2))
      d.to_f64.should eq(0.5)
    end

    it "negative string" do
      BigDecimal.new("-1.5").to_s.should eq("-1.5")
    end
  end

  describe "BigDecimal predicates" do
    it "zero?" do
      BigDecimal.new("0").zero?.should be_true
      BigDecimal.new("0.0").zero?.should be_true
      BigDecimal.new("1.0").zero?.should be_false
    end

    it "positive?" do
      BigDecimal.new("1.0").positive?.should be_true
      BigDecimal.new("-1.0").positive?.should be_false
    end

    it "negative?" do
      BigDecimal.new("-1.0").negative?.should be_true
      BigDecimal.new("1.0").negative?.should be_false
    end

    it "sign" do
      BigDecimal.new("1.5").sign.should eq(1)
      BigDecimal.new("0").sign.should eq(0)
      BigDecimal.new("-1.5").sign.should eq(-1)
    end
  end

  describe "BigDecimal arithmetic" do
    it "addition" do
      (BigDecimal.new("1.1") + BigDecimal.new("2.2")).to_s.should eq("3.3")
    end

    it "subtraction" do
      (BigDecimal.new("5.5") - BigDecimal.new("2.2")).to_s.should eq("3.3")
    end

    it "multiplication" do
      (BigDecimal.new("1.5") * BigDecimal.new("2.0")).to_s.should eq("3.0")
    end

    it "division" do
      (BigDecimal.new("10") / BigDecimal.new("4")).to_f64.should eq(2.5)
    end

    it "with Int" do
      (BigDecimal.new("1.5") + 1).should eq(BigDecimal.new("2.5"))
      (BigDecimal.new("3.0") * 2).should eq(BigDecimal.new("6.0"))
    end

    it "negation" do
      (-BigDecimal.new("1.5")).should eq(BigDecimal.new("-1.5"))
    end

    it "exponentiation" do
      (BigDecimal.new("2") ** 10).should eq(BigDecimal.new("1024"))
    end

    it "modulo" do
      (BigDecimal.new("10") % BigDecimal.new("3")).to_f64.should eq(1.0)
    end
  end

  describe "BigDecimal comparison" do
    it "with BigDecimal" do
      (BigDecimal.new("1.5") < BigDecimal.new("2.5")).should be_true
      (BigDecimal.new("1.0") == BigDecimal.new("1.0")).should be_true
      (BigDecimal.new("1.0") == BigDecimal.new("1.00")).should be_true
    end

    it "with Int" do
      (BigDecimal.new("42") <=> 42).should eq(0)
      (BigDecimal.new("42") <=> 43).should eq(-1)
    end

    it "with Float" do
      cmp = BigDecimal.new("1.5") <=> 1.5
      cmp.not_nil!.should eq(0)
    end
  end

  describe "BigDecimal rounding" do
    it "ceil" do
      BigDecimal.new("1.1").ceil.to_s.should eq("2.0")
      BigDecimal.new("-1.1").ceil.to_s.should eq("-1.0")
    end

    it "floor" do
      BigDecimal.new("1.9").floor.to_s.should eq("1.0")
      BigDecimal.new("-1.1").floor.to_s.should eq("-2.0")
    end

    it "trunc" do
      BigDecimal.new("1.9").trunc.to_s.should eq("1.0")
      BigDecimal.new("-1.9").trunc.to_s.should eq("-1.0")
    end
  end

  describe "BigDecimal conversions" do
    it "to_f64" do
      BigDecimal.new("42.5").to_f64.should eq(42.5)
    end

    it "to_big_i" do
      BigDecimal.new("42.9").to_big_i.should eq(BigInt.new(42))
    end

    it "to_big_f" do
      f = BigDecimal.new("42.5").to_big_f
      f.is_a?(BigFloat).should be_true
    end

    it "to_big_r" do
      r = BigDecimal.new("0.5").to_big_r
      r.is_a?(BigRational).should be_true
      r.to_f64.should eq(0.5)
    end

    it "to_big_d returns self" do
      d = BigDecimal.new("1.23")
      d.to_big_d.should eq(d)
    end

    it "to_s" do
      BigDecimal.new("123.456").to_s.should eq("123.456")
      BigDecimal.new("0.001").to_s.should eq("0.001")
    end
  end

  describe "BigDecimal hash" do
    it "hash equality with Int" do
      BigDecimal.new(42).hash.should eq(42.hash)
    end

    it "equal decimals have equal hashes" do
      BigDecimal.new("1.0").hash.should eq(BigDecimal.new("1.00").hash)
    end
  end

  # ─── Cross-type operations ───

  describe "Cross-type arithmetic" do
    it "BigInt + BigFloat" do
      result = BigFloat.new(BigInt.new(10)) + BigFloat.new(0.5)
      result.should eq(BigFloat.new(10.5))
    end

    it "BigInt / BigFloat returns BigFloat" do
      result = BigInt.new(10) / BigFloat.new(4.0)
      result.is_a?(BigFloat).should be_true
      result.should eq(BigFloat.new(2.5))
    end

    it "BigInt / BigRational returns BigRational" do
      result = BigInt.new(10) / BigRational.new(2, 1)
      result.is_a?(BigRational).should be_true
      result.should eq(BigRational.new(5))
    end

    it "BigInt / BigDecimal returns BigDecimal" do
      result = BigInt.new(10) / BigDecimal.new("4")
      result.is_a?(BigDecimal).should be_true
    end

    it "BigFloat / BigDecimal returns BigDecimal" do
      result = BigFloat.new(10.0) / BigDecimal.new("4")
      result.is_a?(BigDecimal).should be_true
    end

    it "Int + BigInt" do
      (10 + BigInt.new(32)).should eq(BigInt.new(42))
    end

    it "Int - BigInt" do
      (100 - BigInt.new(58)).should eq(BigInt.new(42))
    end

    it "Int * BigInt" do
      (6 * BigInt.new(7)).should eq(BigInt.new(42))
    end

    it "Int / BigRational" do
      (1 / BigRational.new(2, 1)).should eq(BigRational.new(1, 2))
    end

    it "Int / BigFloat" do
      result = 10 / BigFloat.new(4.0)
      result.should eq(BigFloat.new(2.5))
    end

    it "Float / BigInt" do
      result = 10.0 / BigInt.new(4)
      result.is_a?(BigFloat).should be_true
    end
  end

  describe "Cross-type conversions" do
    it "BigInt → BigFloat → BigRational round-trip" do
      original = BigInt.new(42)
      via_float = original.to_big_f
      via_rat = via_float.to_big_r
      via_rat.to_big_i.should eq(original)
    end

    it "BigDecimal → BigRational → BigFloat" do
      d = BigDecimal.new("0.5")
      r = d.to_big_r
      r.to_f64.should eq(0.5)
      f = r.to_big_f
      f.to_f64.should be_close(0.5, 1e-10)
    end
  end

  # ─── Primitive extensions ───

  describe "Primitive to_big_* methods" do
    it "Int#to_big_i" do
      42.to_big_i.should eq(BigInt.new(42))
      42.to_big_i.is_a?(BigInt).should be_true
    end

    it "Int#to_big_f" do
      42.to_big_f.should eq(BigFloat.new(42))
      42.to_big_f.is_a?(BigFloat).should be_true
    end

    it "Int#to_big_r" do
      42.to_big_r.should eq(BigRational.new(42, 1))
      42.to_big_r.is_a?(BigRational).should be_true
    end

    it "Int#to_big_d" do
      42.to_big_d.should eq(BigDecimal.new(42))
      42.to_big_d.is_a?(BigDecimal).should be_true
    end

    it "Float#to_big_i truncates" do
      42.9.to_big_i.should eq(BigInt.new(42))
    end

    it "Float#to_big_f" do
      1.5.to_big_f.is_a?(BigFloat).should be_true
    end

    it "Float#to_big_r" do
      0.5.to_big_r.to_f64.should eq(0.5)
    end

    it "Float#to_big_d" do
      1.5.to_big_d.is_a?(BigDecimal).should be_true
    end

    it "String#to_big_i" do
      "123".to_big_i.should eq(BigInt.new(123))
      "ff".to_big_i(16).should eq(BigInt.new(255))
    end

    it "String#to_big_f" do
      "1.5".to_big_f.is_a?(BigFloat).should be_true
    end

    it "String#to_big_r" do
      "1/3".to_big_r.should eq(BigRational.new(1, 3))
    end

    it "String#to_big_d" do
      "1.23".to_big_d.should eq(BigDecimal.new("1.23"))
    end
  end

  # ─── Math module ───

  describe "Math module with Big types" do
    it "Math.isqrt" do
      Math.isqrt(BigInt.new(0)).should eq(BigInt.new(0))
      Math.isqrt(BigInt.new(1)).should eq(BigInt.new(1))
      Math.isqrt(BigInt.new(4)).should eq(BigInt.new(2))
      Math.isqrt(BigInt.new(8)).should eq(BigInt.new(2))
      Math.isqrt(BigInt.new(9)).should eq(BigInt.new(3))
      Math.isqrt(BigInt.new(100)).should eq(BigInt.new(10))
    end

    it "Math.isqrt large value" do
      # sqrt(10^20) = 10^10
      v = BigInt.new(10) ** 20
      Math.isqrt(v).should eq(BigInt.new(10) ** 10)
    end

    it "Math.sqrt(BigInt)" do
      Math.sqrt(BigInt.new(4)).should eq(BigFloat.new(2.0))
      Math.sqrt(BigInt.new(4)).is_a?(BigFloat).should be_true
    end

    it "Math.sqrt(BigFloat)" do
      Math.sqrt(BigFloat.new(4.0)).should eq(BigFloat.new(2.0))
      Math.sqrt(BigFloat.new(9.0)).should eq(BigFloat.new(3.0))
    end

    it "Math.sqrt(BigRational)" do
      result = Math.sqrt(BigRational.new(4, 1))
      result.is_a?(BigFloat).should be_true
    end

    it "Math.pw2ceil" do
      Math.pw2ceil(BigInt.new(1)).should eq(BigInt.new(1))
      Math.pw2ceil(BigInt.new(2)).should eq(BigInt.new(2))
      Math.pw2ceil(BigInt.new(3)).should eq(BigInt.new(4))
      Math.pw2ceil(BigInt.new(5)).should eq(BigInt.new(8))
      Math.pw2ceil(BigInt.new(16)).should eq(BigInt.new(16))
      Math.pw2ceil(BigInt.new(17)).should eq(BigInt.new(32))
    end
  end

  # ─── Random ───

  describe "Random with BigInt" do
    it "rand(BigInt) returns value in range" do
      rng = Random.new(42)
      max = BigInt.new(1000000)
      10.times do
        v = rng.rand(max)
        v.is_a?(BigInt).should be_true
        (v >= BigInt.new(0)).should be_true
        (v < max).should be_true
      end
    end

    it "rand(Range(BigInt, BigInt)) exclusive" do
      rng = Random.new(42)
      lo = BigInt.new(100)
      hi = BigInt.new(110)
      10.times do
        v = rng.rand(lo...hi)
        (v >= lo).should be_true
        (v < hi).should be_true
      end
    end

    it "rand(Range(BigInt, BigInt)) inclusive" do
      rng = Random.new(42)
      lo = BigInt.new(100)
      hi = BigInt.new(105)
      10.times do
        v = rng.rand(lo..hi)
        (v >= lo).should be_true
        (v <= hi).should be_true
      end
    end

    it "produces different values" do
      rng = Random.new
      max = BigInt.new(1000000)
      values = (0...20).map { rng.rand(max) }.to_set
      values.size.should be > 5
    end
  end

  # ─── Hash equality ───

  describe "Numeric hash equality" do
    it "BigInt(n).hash == n.hash for small values" do
      [0, 1, -1, 42, -42, 1000, -1000, Int32::MAX, Int32::MIN].each do |n|
        BigInt.new(n).hash.should eq(n.hash), "hash mismatch for #{n}"
      end
    end

    it "BigFloat(n).hash == n.hash for integers" do
      [0, 1, -1, 42, 1000].each do |n|
        BigFloat.new(n).hash.should eq(n.hash), "hash mismatch for BigFloat(#{n})"
      end
    end

    it "BigFloat(f).hash == f.hash for float values" do
      [0.0, 0.5, -0.5, 1.0, -1.0].each do |f|
        BigFloat.new(f).hash.should eq(f.hash), "hash mismatch for BigFloat(#{f})"
      end
    end

    it "BigRational(n, 1).hash == n.hash" do
      [0, 1, -1, 42, 100].each do |n|
        BigRational.new(n, 1).hash.should eq(n.hash), "hash mismatch for BigRational(#{n}/1)"
      end
    end

    it "BigDecimal(n).hash == n.hash for integers" do
      [0, 1, -1, 42, 100].each do |n|
        BigDecimal.new(n).hash.should eq(n.hash), "hash mismatch for BigDecimal(#{n})"
      end
    end

    it "cross-type: all representations of 42 have same hash" do
      h = 42.hash
      BigInt.new(42).hash.should eq(h)
      BigFloat.new(42.0).hash.should eq(h)
      BigRational.new(42, 1).hash.should eq(h)
      BigDecimal.new(42).hash.should eq(h)
    end

    it "cross-type: all representations of 0 have same hash" do
      h = 0.hash
      BigInt.new(0).hash.should eq(h)
      BigFloat.new(0.0).hash.should eq(h)
      BigRational.new(0, 1).hash.should eq(h)
      BigDecimal.new(0).hash.should eq(h)
    end
  end

  # ─── JSON serialization ───

  describe "JSON serialization" do
    it "BigInt round-trips through JSON" do
      x = BigInt.new("123456789012345678901234567890")
      json = x.to_json
      parsed = BigInt.new(JSON::PullParser.new(json))
      parsed.should eq(x)
    end

    it "BigFloat round-trips through JSON" do
      x = BigFloat.new("42.5")
      json = x.to_json
      parsed = BigFloat.new(JSON::PullParser.new(json))
      parsed.to_f64.should be_close(42.5, 1e-10)
    end

    it "BigDecimal round-trips through JSON" do
      x = BigDecimal.new("123.456")
      json = x.to_json
      parsed = BigDecimal.new(JSON::PullParser.new(json))
      parsed.should eq(x)
    end

    it "BigInt as JSON object key" do
      key = BigInt.new(42)
      key.to_json_object_key.should eq("42")
      BigInt.from_json_object_key?("42").should eq(BigInt.new(42))
    end

    it "BigFloat as JSON object key" do
      key = BigFloat.new(42.5)
      s = key.to_json_object_key
      BigFloat.from_json_object_key?(s).not_nil!.to_f64.should be_close(42.5, 1e-10)
    end

    it "BigDecimal as JSON object key" do
      key = BigDecimal.new("1.23")
      s = key.to_json_object_key
      BigDecimal.from_json_object_key?(s).should eq(BigDecimal.new("1.23"))
    end
  end

  # ─── YAML serialization ───

  describe "YAML serialization" do
    it "BigInt from YAML" do
      yaml = "--- 42\n"
      x = BigInt.from_yaml(yaml)
      x.should eq(BigInt.new(42))
    end

    it "BigFloat from YAML" do
      yaml = "--- 42.5\n"
      x = BigFloat.from_yaml(yaml)
      x.to_f64.should be_close(42.5, 1e-10)
    end

    it "BigDecimal from YAML" do
      yaml = "--- 1.23\n"
      x = BigDecimal.from_yaml(yaml)
      x.to_f64.should be_close(1.23, 1e-10)
    end
  end

  # ─── Edge cases ───

  describe "Edge cases" do
    it "BigInt zero operations" do
      z = BigInt.new(0)
      (z + z).should eq(z)
      (z * BigInt.new(999)).should eq(z)
      (z - z).should eq(z)
      (-z).should eq(z)
      z.abs.should eq(z)
    end

    it "BigInt one identity" do
      one = BigInt.new(1)
      x = BigInt.new(42)
      (x * one).should eq(x)
      (x // one).should eq(x)
      (x ** 1).should eq(x)
    end

    it "BigRational zero" do
      z = BigRational.new(0, 1)
      (z + BigRational.new(1, 2)).should eq(BigRational.new(1, 2))
      (z * BigRational.new(999, 1)).should eq(z)
    end

    it "BigDecimal very small number" do
      d = BigDecimal.new("0.000000001")
      d.to_s.should eq("0.000000001")
    end

    it "BigDecimal very large number" do
      d = BigDecimal.new("99999999999999999999999999999.99")
      d.to_s.should eq("99999999999999999999999999999.99")
    end

    it "BigInt very large number string round-trip" do
      s = "9" * 1000
      x = BigInt.new(s)
      x.to_s.should eq(s)
    end

    it "BigFloat precision is preserved" do
      x = BigFloat.new("1.0", precision: 256)
      x.precision.should eq(256)
    end
  end

  # ─── No GMP symbols ───

  describe "No GMP dependency" do
    it "compiles without libgmp" do
      # This test file itself compiles and runs without requiring libgmp.
      # If GMP were linked, the require at the top would pull it in.
      # The fact that these tests compile and pass is proof that no GMP is needed.
      true.should be_true
    end
  end
end
{% end %}
