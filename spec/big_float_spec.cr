require "./spec_helper"

describe BigNumber::BigFloat do
  # --- Construction ---

  describe "construction" do
    it "constructs zero by default" do
      bf = BF.new
      bf.zero?.should be_true
      bf.sign.should eq(0_i8)
    end

    it "constructs from positive Int" do
      bf = BF.new(42)
      bf.positive?.should be_true
      bf.to_f64.should eq(42.0)
    end

    it "constructs from negative Int" do
      bf = BF.new(-7)
      bf.negative?.should be_true
      bf.to_f64.should eq(-7.0)
    end

    it "constructs from zero Int" do
      bf = BF.new(0)
      bf.zero?.should be_true
    end

    it "constructs from BigInt" do
      bi = BI.new("123456789012345678901234567890")
      bf = BF.new(bi)
      bf.positive?.should be_true
      bf.to_big_i.should eq(bi)
    end

    it "constructs from Float64" do
      bf = BF.new(0.5)
      bf.to_f64.should eq(0.5)
    end

    it "constructs from negative Float64" do
      bf = BF.new(-1.25)
      bf.to_f64.should eq(-1.25)
    end

    it "constructs from Float64 zero" do
      bf = BF.new(0.0)
      bf.zero?.should be_true
    end

    it "raises on non-finite Float64" do
      expect_raises(ArgumentError) { BF.new(Float64::INFINITY) }
      expect_raises(ArgumentError) { BF.new(Float64::NAN) }
    end

    it "constructs from String with decimal point" do
      bf = BF.new("3.14")
      # Should be close to 3.14
      (bf.to_f64 - 3.14).abs.should be < 1e-10
    end

    it "constructs from String integer" do
      bf = BF.new("42")
      bf.to_f64.should eq(42.0)
    end

    it "constructs from String with exponent" do
      bf = BF.new("1.5e10")
      bf.to_f64.should eq(1.5e10)
    end

    it "constructs from negative String" do
      bf = BF.new("-2.5")
      bf.to_f64.should eq(-2.5)
    end

    it "constructs from BigRational" do
      br = BR.new(1, 3)
      bf = BF.new(br)
      # 1/3 ≈ 0.333...
      (bf.to_f64 - 1.0/3.0).abs.should be < 1e-15
    end

    it "constructs from BigRational exact" do
      br = BR.new(1, 4)
      bf = BF.new(br)
      bf.to_f64.should eq(0.25)
    end

    it "respects custom precision" do
      bf_low = BF.new(1, precision: 32)
      bf_high = BF.new(1, precision: 256)
      bf_low.precision.should eq(32)
      bf_high.precision.should eq(256)
      bf_low.mantissa.bit_length.should eq(32)
      bf_high.mantissa.bit_length.should eq(256)
    end

    it "clones correctly" do
      bf = BF.new(3.14)
      bf2 = bf.clone
      bf2.to_f64.should eq(bf.to_f64)
      bf2.precision.should eq(bf.precision)
    end
  end

  # --- Predicates ---

  describe "predicates" do
    it "zero?" do
      BF.new.zero?.should be_true
      BF.new(0).zero?.should be_true
      BF.new(1).zero?.should be_false
    end

    it "positive?" do
      BF.new(1).positive?.should be_true
      BF.new(-1).positive?.should be_false
      BF.new(0).positive?.should be_false
    end

    it "negative?" do
      BF.new(-1).negative?.should be_true
      BF.new(1).negative?.should be_false
      BF.new(0).negative?.should be_false
    end
  end

  # --- Comparison ---

  describe "comparison" do
    it "compares same-sign values" do
      (BF.new(3) > BF.new(2)).should be_true
      (BF.new(2) < BF.new(3)).should be_true
      (BF.new(2) <=> BF.new(2)).should eq(0)
    end

    it "compares opposite-sign values" do
      (BF.new(1) > BF.new(-1)).should be_true
      (BF.new(-5) < BF.new(1)).should be_true
    end

    it "compares with zero" do
      (BF.new(1) > BF.new(0)).should be_true
      (BF.new(-1) < BF.new(0)).should be_true
      (BF.new(0) <=> BF.new(0)).should eq(0)
    end

    it "compares fractional values" do
      (BF.new(1.5) > BF.new(1.25)).should be_true
      (BF.new(0.1) < BF.new(0.2)).should be_true
    end

    it "compares with different precisions" do
      a = BF.new(1, precision: 64)
      b = BF.new(1, precision: 256)
      (a == b).should be_true
    end

    it "compares with Int" do
      (BF.new(3.0) <=> 3).should eq(0)
      (BF.new(3.5) > 3).should be_true
      (BF.new(2.5) < 3).should be_true
    end

    it "compares with BigInt" do
      bi = BI.new(100)
      (BF.new(100) <=> bi).should eq(0)
      (BF.new(101) > bi).should be_true
    end

    it "equality across types" do
      (BF.new(1.0) == 1).should be_true
      (BF.new(1.0) == BI.new(1)).should be_true
      (BF.new(1.0) == 1.0).should be_true
    end

    it "hash is consistent for equal values" do
      a = BF.new(42)
      b = BF.new(42)
      a.hash.should eq(b.hash)
    end
  end

  # --- Arithmetic ---

  describe "addition" do
    it "adds same-sign values" do
      (BF.new(1.5) + BF.new(2.5)).to_f64.should eq(4.0)
    end

    it "adds opposite-sign values" do
      (BF.new(1.5) + BF.new(-0.5)).to_f64.should eq(1.0)
    end

    it "adds values with different magnitudes" do
      large = BF.new(1_000_000)
      tiny = BF.new(0.001)
      result = large + tiny
      (result.to_f64 - 1_000_000.001).abs.should be < 1e-6
    end

    it "adds with zero" do
      (BF.new(5.0) + BF.new(0)).to_f64.should eq(5.0)
      (BF.new(0) + BF.new(5.0)).to_f64.should eq(5.0)
    end

    it "adds canceling values" do
      (BF.new(3.0) + BF.new(-3.0)).zero?.should be_true
    end

    it "adds with Int" do
      (BF.new(1.5) + 2).to_f64.should eq(3.5)
    end

    it "adds with BigInt" do
      (BF.new(0.5) + BI.new(10)).to_f64.should eq(10.5)
    end
  end

  describe "subtraction" do
    it "subtracts values" do
      (BF.new(3.0) - BF.new(1.5)).to_f64.should eq(1.5)
    end

    it "subtracts to negative" do
      (BF.new(1.0) - BF.new(3.0)).to_f64.should eq(-2.0)
    end

    it "subtracts equal values" do
      (BF.new(7.0) - BF.new(7.0)).zero?.should be_true
    end
  end

  describe "multiplication" do
    it "multiplies positive values" do
      (BF.new(1.5) * BF.new(2.0)).to_f64.should eq(3.0)
    end

    it "multiplies with negative" do
      (BF.new(3.0) * BF.new(-2.0)).to_f64.should eq(-6.0)
    end

    it "multiplies both negative" do
      (BF.new(-2.0) * BF.new(-3.0)).to_f64.should eq(6.0)
    end

    it "multiplies with zero" do
      (BF.new(5.0) * BF.new(0)).zero?.should be_true
      (BF.new(0) * BF.new(5.0)).zero?.should be_true
    end

    it "multiplies with Int" do
      (BF.new(2.5) * 4).to_f64.should eq(10.0)
    end

    it "multiplies large values" do
      a = BF.new("1e50")
      b = BF.new("1e50")
      result = a * b
      result.to_f64.should eq(1e100)
    end
  end

  describe "division" do
    it "divides values" do
      (BF.new(3.0) / BF.new(2.0)).to_f64.should eq(1.5)
    end

    it "divides with different signs" do
      (BF.new(6.0) / BF.new(-2.0)).to_f64.should eq(-3.0)
    end

    it "divides zero by nonzero" do
      (BF.new(0) / BF.new(5.0)).zero?.should be_true
    end

    it "raises on division by zero" do
      expect_raises(DivisionByZeroError) { BF.new(1.0) / BF.new(0) }
    end

    it "divides with Int" do
      (BF.new(10.0) / 4).to_f64.should eq(2.5)
    end

    it "divides 1/3 correctly" do
      result = BF.new(1) / BF.new(3)
      (result.to_f64 - 1.0/3.0).abs.should be < 1e-15
    end
  end

  describe "exponentiation" do
    it "raises to positive power" do
      (BF.new(2.0) ** 10).to_f64.should eq(1024.0)
    end

    it "raises to zero power" do
      (BF.new(5.0) ** 0).to_f64.should eq(1.0)
    end

    it "raises to power 1" do
      (BF.new(3.14) ** 1).to_f64.should eq(3.14)
    end

    it "raises to negative power" do
      result = BF.new(2.0) ** -1
      (result.to_f64 - 0.5).abs.should be < 1e-15
    end
  end

  describe "unary operations" do
    it "negates positive" do
      (-BF.new(3.0)).to_f64.should eq(-3.0)
    end

    it "negates negative" do
      (-BF.new(-3.0)).to_f64.should eq(3.0)
    end

    it "negates zero" do
      (-BF.new(0)).zero?.should be_true
    end

    it "abs of positive" do
      BF.new(5.0).abs.to_f64.should eq(5.0)
    end

    it "abs of negative" do
      BF.new(-5.0).abs.to_f64.should eq(5.0)
    end
  end

  # --- Rounding ---

  describe "rounding" do
    it "floor positive" do
      BF.new(3.7).floor.to_f64.should eq(3.0)
    end

    it "floor negative" do
      BF.new(-3.7).floor.to_f64.should eq(-4.0)
    end

    it "floor of integer" do
      BF.new(5.0).floor.to_f64.should eq(5.0)
    end

    it "floor of small positive" do
      BF.new(0.5).floor.to_f64.should eq(0.0)
    end

    it "floor of small negative" do
      BF.new(-0.5).floor.to_f64.should eq(-1.0)
    end

    it "ceil positive" do
      BF.new(3.2).ceil.to_f64.should eq(4.0)
    end

    it "ceil negative" do
      BF.new(-3.2).ceil.to_f64.should eq(-3.0)
    end

    it "ceil of integer" do
      BF.new(5.0).ceil.to_f64.should eq(5.0)
    end

    it "trunc positive" do
      BF.new(3.7).trunc.to_f64.should eq(3.0)
    end

    it "trunc negative" do
      BF.new(-3.7).trunc.to_f64.should eq(-3.0)
    end

    it "round nearest" do
      BF.new(3.7).round.to_f64.should eq(4.0)
      BF.new(3.2).round.to_f64.should eq(3.0)
    end

    it "round ties to even" do
      BF.new(2.5).round.to_f64.should eq(2.0)
      BF.new(3.5).round.to_f64.should eq(4.0)
    end
  end

  # --- Conversions ---

  describe "conversions" do
    it "to_f64 exact for small values" do
      BF.new(1.5).to_f64.should eq(1.5)
      BF.new(-0.25).to_f64.should eq(-0.25)
      BF.new(42).to_f64.should eq(42.0)
    end

    it "to_f64 overflow returns infinity" do
      huge = BF.new(1) * (BF.new(2) ** 2000)
      huge.to_f64.should eq(Float64::INFINITY)
    end

    it "to_big_i truncates" do
      BF.new(3.7).to_big_i.should eq(BI.new(3))
      BF.new(-3.7).to_big_i.should eq(BI.new(-3))
    end

    it "to_big_i of integer" do
      BF.new(42).to_big_i.should eq(BI.new(42))
    end

    it "to_big_i of fraction < 1" do
      BF.new(0.5).to_big_i.should eq(BI.new(0))
    end

    it "to_big_r exact" do
      bf = BF.new(1.5)
      br = bf.to_big_r
      br.should eq(BR.new(3, 2))
    end

    it "to_s for zero" do
      BF.new(0).to_s.should eq("0.0")
    end

    it "to_s for integer" do
      BF.new(42).to_s.should eq("42.0")
    end

    it "to_s for simple fraction" do
      BF.new(1.5).to_s.should eq("1.5")
    end

    it "to_s for negative" do
      BF.new(-2.5).to_s.should eq("-2.5")
    end

    it "to_s round-trip for powers of 2" do
      bf = BF.new(0.125)
      BF.new(bf.to_s).to_f64.should eq(0.125)
    end

    it "to_big_f returns self" do
      bf = BF.new(3.14)
      bf.to_big_f.should eq(bf)
    end
  end

  # --- Extensions ---

  describe "extensions" do
    it "Int#to_big_f" do
      bf = 42.to_big_f
      bf.should be_a(BF)
      bf.to_f64.should eq(42.0)
    end

    it "Float#to_big_f" do
      bf = 3.14.to_big_f
      bf.should be_a(BF)
      (bf.to_f64 - 3.14).abs.should be < 1e-10
    end

    it "String#to_big_f" do
      bf = BF.new("2.5")
      bf.should be_a(BF)
      bf.to_f64.should eq(2.5)
    end

    it "Int + BigFloat" do
      (2 + BF.new(1.5)).to_f64.should eq(3.5)
    end

    it "Int - BigFloat" do
      (5 - BF.new(1.5)).to_f64.should eq(3.5)
    end

    it "Int * BigFloat" do
      (3 * BF.new(2.5)).to_f64.should eq(7.5)
    end

    it "Int / BigFloat" do
      (10 / BF.new(4.0)).to_f64.should eq(2.5)
    end

    it "Float + BigFloat" do
      (1.5 + BF.new(2.5)).to_f64.should eq(4.0)
    end

    it "Int <=> BigFloat" do
      (3 <=> BF.new(2.5)).should eq(1)
      (2 <=> BF.new(2.0)).should eq(0)
    end

    it "Int == BigFloat" do
      (1 == BF.new(1.0)).should be_true
      (2 == BF.new(1.0)).should be_false
    end
  end

  # --- Default precision ---

  describe "default_precision" do
    it "defaults to 128" do
      BF.default_precision.should eq(128)
    end

    it "can be changed" do
      old = BF.default_precision
      begin
        BF.default_precision = 256
        BF.default_precision.should eq(256)
        BF.new(1).precision.should eq(256)
      ensure
        BF.default_precision = old
      end
    end
  end

  # --- Fuzz tests against Crystal stdlib BigFloat ---

  describe "fuzz: vs stdlib" do
    it "construction from string matches stdlib" do
      strs = ["1.0", "0.5", "-3.14", "100.001", "0.0001", "1e10", "1.23e-5"]
      strs.each do |s|
        ours = BF.new(s).to_f64
        theirs = BigFloat.new(s).to_f64
        (ours - theirs).abs.should be < theirs.abs * 1e-10 + 1e-20
      end
    end

    it "addition matches stdlib" do
      pairs = [{1.5, 2.5}, {-3.0, 1.0}, {100.0, 0.001}, {-5.5, -2.3}]
      pairs.each do |(a, b)|
        ours = (BF.new(a) + BF.new(b)).to_f64
        theirs = (BigFloat.new(a) + BigFloat.new(b)).to_f64
        (ours - theirs).abs.should be < theirs.abs * 1e-10 + 1e-20
      end
    end

    it "subtraction matches stdlib" do
      pairs = [{5.0, 3.0}, {-1.0, 2.0}, {0.5, 0.5}]
      pairs.each do |(a, b)|
        ours = (BF.new(a) - BF.new(b)).to_f64
        theirs = (BigFloat.new(a) - BigFloat.new(b)).to_f64
        (ours - theirs).abs.should be < theirs.abs.abs * 1e-10 + 1e-20
      end
    end

    it "multiplication matches stdlib" do
      pairs = [{1.5, 2.0}, {-3.0, 4.0}, {0.1, 0.2}, {100.0, 100.0}]
      pairs.each do |(a, b)|
        ours = (BF.new(a) * BF.new(b)).to_f64
        theirs = (BigFloat.new(a) * BigFloat.new(b)).to_f64
        (ours - theirs).abs.should be < theirs.abs * 1e-10 + 1e-20
      end
    end

    it "division matches stdlib" do
      pairs = [{3.0, 2.0}, {1.0, 3.0}, {-10.0, 3.0}, {7.0, 11.0}]
      pairs.each do |(a, b)|
        ours = (BF.new(a) / BF.new(b)).to_f64
        theirs = (BigFloat.new(a) / BigFloat.new(b)).to_f64
        (ours - theirs).abs.should be < theirs.abs * 1e-10 + 1e-20
      end
    end

    it "to_f64 matches stdlib" do
      values = [0.5, -1.25, 3.14, 1000.0, 0.001]
      values.each do |v|
        ours = BF.new(v).to_f64
        theirs = BigFloat.new(v).to_f64
        (ours - theirs).abs.should be < theirs.abs * 1e-10 + 1e-20
      end
    end
  end

  # --- Algebraic properties ---

  describe "algebraic properties" do
    it "a + 0 ≈ a (additive identity)" do
      a = BF.new(3.14)
      (a + BF.new(0)).should eq(a)
    end

    it "a * 1 ≈ a (multiplicative identity)" do
      a = BF.new(3.14)
      (a * BF.new(1)).to_f64.should eq(a.to_f64)
    end

    it "a + b ≈ b + a (commutativity)" do
      a = BF.new(1.5)
      b = BF.new(2.7)
      (a + b).to_f64.should eq((b + a).to_f64)
    end

    it "a * b ≈ b * a (commutativity)" do
      a = BF.new(1.5)
      b = BF.new(2.7)
      (a * b).to_f64.should eq((b * a).to_f64)
    end

    it "a + (-a) ≈ 0 (additive inverse)" do
      a = BF.new(3.14)
      (a + (-a)).zero?.should be_true
    end

    it "a * (1/a) ≈ 1 (multiplicative inverse)" do
      a = BF.new(3.0)
      result = a * (BF.new(1) / a)
      (result.to_f64 - 1.0).abs.should be < 1e-10
    end
  end
end
