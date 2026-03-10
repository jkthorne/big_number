require "./spec_helper"

describe BigNumber::BigRational do
  # --- Construction ---

  it "constructs from two ints" do
    r = BR.new(3, 4)
    r.numerator.should eq(BI.new(3))
    r.denominator.should eq(BI.new(4))
  end

  it "constructs from two BigInts" do
    r = BR.new(BI.new(7), BI.new(14))
    r.numerator.should eq(BI.new(1))
    r.denominator.should eq(BI.new(2))
  end

  it "constructs from single int" do
    r = BR.new(5)
    r.numerator.should eq(BI.new(5))
    r.denominator.should eq(BI.new(1))
  end

  it "constructs from single BigInt" do
    r = BR.new(BI.new(42))
    r.numerator.should eq(BI.new(42))
    r.denominator.should eq(BI.new(1))
  end

  it "constructs zero" do
    r = BR.new(0, 7)
    r.numerator.should eq(BI.new(0))
    r.denominator.should eq(BI.new(1))
    r.zero?.should be_true
  end

  it "constructs from float" do
    r = BR.new(0.5)
    r.numerator.should eq(BI.new(1))
    r.denominator.should eq(BI.new(2))
  end

  it "constructs from float 0.0" do
    r = BR.new(0.0)
    r.zero?.should be_true
    r.denominator.should eq(BI.new(1))
  end

  it "constructs from negative float" do
    r = BR.new(-0.25)
    r.numerator.should eq(BI.new(-1))
    r.denominator.should eq(BI.new(4))
  end

  it "constructs from string num/den" do
    r = BR.new("3/4")
    r.numerator.should eq(BI.new(3))
    r.denominator.should eq(BI.new(4))
  end

  it "constructs from string integer" do
    r = BR.new("42")
    r.numerator.should eq(BI.new(42))
    r.denominator.should eq(BI.new(1))
  end

  it "constructs from negative string" do
    r = BR.new("-5/3")
    r.numerator.should eq(BI.new(-5))
    r.denominator.should eq(BI.new(3))
  end

  it "raises on zero denominator" do
    expect_raises(DivisionByZeroError) { BR.new(1, 0) }
  end

  it "raises on non-finite float" do
    expect_raises(ArgumentError) { BR.new(Float64::INFINITY) }
    expect_raises(ArgumentError) { BR.new(Float64::NAN) }
  end

  # --- Canonicalization ---

  it "reduces to lowest terms" do
    r = BR.new(6, 4)
    r.numerator.should eq(BI.new(3))
    r.denominator.should eq(BI.new(2))
  end

  it "reduces large fractions" do
    r = BR.new(100, 250)
    r.numerator.should eq(BI.new(2))
    r.denominator.should eq(BI.new(5))
  end

  it "normalizes negative denominator" do
    r = BR.new(3, -4)
    r.numerator.should eq(BI.new(-3))
    r.denominator.should eq(BI.new(4))
  end

  it "normalizes both negative" do
    r = BR.new(-3, -4)
    r.numerator.should eq(BI.new(3))
    r.denominator.should eq(BI.new(4))
  end

  it "reduces negative fraction" do
    r = BR.new(-6, 4)
    r.numerator.should eq(BI.new(-3))
    r.denominator.should eq(BI.new(2))
  end

  # --- Arithmetic ---

  describe "addition" do
    it "adds two rationals" do
      (BR.new(1, 2) + BR.new(1, 3)).should eq(BR.new(5, 6))
    end

    it "adds rational and int" do
      (BR.new(1, 2) + 1).should eq(BR.new(3, 2))
    end

    it "adds int and rational" do
      (1 + BR.new(1, 2)).should eq(BR.new(3, 2))
    end

    it "adds rational and BigInt" do
      (BR.new(1, 3) + BI.new(2)).should eq(BR.new(7, 3))
    end

    it "adds with negative" do
      (BR.new(1, 2) + BR.new(-1, 3)).should eq(BR.new(1, 6))
    end
  end

  describe "subtraction" do
    it "subtracts two rationals" do
      (BR.new(3, 4) - BR.new(1, 4)).should eq(BR.new(1, 2))
    end

    it "subtracts rational and int" do
      (BR.new(5, 2) - 1).should eq(BR.new(3, 2))
    end

    it "subtracts int and rational" do
      (1 - BR.new(1, 3)).should eq(BR.new(2, 3))
    end

    it "produces negative result" do
      (BR.new(1, 4) - BR.new(3, 4)).should eq(BR.new(-1, 2))
    end
  end

  describe "multiplication" do
    it "multiplies two rationals" do
      (BR.new(2, 3) * BR.new(3, 4)).should eq(BR.new(1, 2))
    end

    it "multiplies rational and int" do
      (BR.new(2, 3) * 3).should eq(BR.new(2))
    end

    it "multiplies int and rational" do
      (3 * BR.new(2, 3)).should eq(BR.new(2))
    end

    it "multiplies by zero" do
      (BR.new(5, 7) * 0).should eq(BR.new(0))
    end

    it "multiplies negatives" do
      (BR.new(-2, 3) * BR.new(-3, 5)).should eq(BR.new(2, 5))
    end
  end

  describe "division" do
    it "divides two rationals" do
      (BR.new(2, 3) / BR.new(4, 5)).should eq(BR.new(5, 6))
    end

    it "divides rational by int" do
      (BR.new(2, 3) / 2).should eq(BR.new(1, 3))
    end

    it "divides int by rational" do
      (1 / BR.new(2, 3)).should eq(BR.new(3, 2))
    end

    it "raises on division by zero" do
      expect_raises(DivisionByZeroError) { BR.new(1, 2) / BR.new(0) }
      expect_raises(DivisionByZeroError) { BR.new(1, 2) / 0 }
    end
  end

  describe "exponentiation" do
    it "raises to positive power" do
      (BR.new(2, 3) ** 3).should eq(BR.new(8, 27))
    end

    it "raises to zero power" do
      (BR.new(2, 3) ** 0).should eq(BR.new(1))
    end

    it "raises to negative power" do
      (BR.new(2, 3) ** -2).should eq(BR.new(9, 4))
    end

    it "raises to power of 1" do
      (BR.new(5, 7) ** 1).should eq(BR.new(5, 7))
    end
  end

  describe "unary minus" do
    it "negates positive" do
      (-BR.new(3, 4)).should eq(BR.new(-3, 4))
    end

    it "negates negative" do
      (-BR.new(-3, 4)).should eq(BR.new(3, 4))
    end

    it "negates zero" do
      (-BR.new(0)).should eq(BR.new(0))
    end
  end

  # --- Comparison ---

  describe "comparison" do
    it "compares equal rationals" do
      (BR.new(1, 2) <=> BR.new(2, 4)).should eq(0)
      (BR.new(1, 2) == BR.new(2, 4)).should be_true
    end

    it "compares less than" do
      (BR.new(1, 3) < BR.new(1, 2)).should be_true
    end

    it "compares greater than" do
      (BR.new(3, 4) > BR.new(2, 3)).should be_true
    end

    it "compares with int" do
      (BR.new(3, 2) > 1).should be_true
      (BR.new(1, 2) < 1).should be_true
      (BR.new(2) == 2).should be_true
    end

    it "compares with BigInt" do
      (BR.new(5, 2) > BI.new(2)).should be_true
      (BR.new(3, 2) < BI.new(2)).should be_true
    end

    it "compares negative rationals" do
      (BR.new(-1, 2) < BR.new(1, 2)).should be_true
      (BR.new(-1, 3) > BR.new(-1, 2)).should be_true
    end

    it "compares int with rational" do
      (2 == BR.new(2)).should be_true
      (1 <=> BR.new(3, 2)).should eq(-1)
    end
  end

  # --- Predicates ---

  describe "predicates" do
    it "zero?" do
      BR.new(0).zero?.should be_true
      BR.new(1, 2).zero?.should be_false
    end

    it "positive?" do
      BR.new(1, 2).positive?.should be_true
      BR.new(-1, 2).positive?.should be_false
      BR.new(0).positive?.should be_false
    end

    it "negative?" do
      BR.new(-1, 2).negative?.should be_true
      BR.new(1, 2).negative?.should be_false
      BR.new(0).negative?.should be_false
    end

    it "integer?" do
      BR.new(4, 2).integer?.should be_true
      BR.new(3, 2).integer?.should be_false
      BR.new(0).integer?.should be_true
    end
  end

  # --- abs, inv ---

  describe "abs" do
    it "positive stays positive" do
      BR.new(3, 4).abs.should eq(BR.new(3, 4))
    end

    it "negative becomes positive" do
      BR.new(-3, 4).abs.should eq(BR.new(3, 4))
    end

    it "zero" do
      BR.new(0).abs.should eq(BR.new(0))
    end
  end

  describe "inv" do
    it "inverts positive" do
      BR.new(3, 4).inv.should eq(BR.new(4, 3))
    end

    it "inverts negative" do
      BR.new(-3, 4).inv.should eq(BR.new(-4, 3))
    end

    it "raises on zero" do
      expect_raises(DivisionByZeroError) { BR.new(0).inv }
    end
  end

  # --- Conversions ---

  describe "to_f64" do
    it "converts simple fraction" do
      BR.new(1, 2).to_f64.should eq(0.5)
    end

    it "converts integer" do
      BR.new(3).to_f64.should eq(3.0)
    end

    it "to_f alias" do
      BR.new(1, 4).to_f.should eq(0.25)
    end
  end

  describe "to_s" do
    it "formats fraction" do
      BR.new(3, 4).to_s.should eq("3/4")
    end

    it "formats integer" do
      BR.new(5).to_s.should eq("5")
    end

    it "formats negative" do
      BR.new(-3, 4).to_s.should eq("-3/4")
    end

    it "formats zero" do
      BR.new(0).to_s.should eq("0")
    end

    it "round-trips through string" do
      ["1/2", "-3/4", "7", "0", "100/3", "-1/7"].each do |s|
        BR.new(s).to_s.should eq(s)
      end
    end
  end

  describe "hash" do
    it "equal values have equal hashes" do
      BR.new(1, 2).hash.should eq(BR.new(2, 4).hash)
    end
  end

  describe "clone" do
    it "creates independent copy" do
      a = BR.new(3, 4)
      b = a.clone
      a.should eq(b)
    end
  end

  describe "to_big_r" do
    it "returns self" do
      r = BR.new(3, 4)
      r.to_big_r.should eq(r)
    end
  end

  # --- Type extensions ---

  describe "type extensions" do
    it "Int#to_big_r" do
      5.to_big_r.should eq(BR.new(5))
    end

    it "Float#to_big_r" do
      0.5.to_big_r.should eq(BR.new(1, 2))
    end

    it "String#to_big_r" do
      "3/4".to_big_r.should eq(BR.new(3, 4))
    end
  end

  # --- Algebraic property fuzz tests ---

  describe "algebraic properties" do
    it "additive identity: a + 0 == a" do
      10.times do
        a = BR.new(rand(-100..100), rand(1..100))
        (a + BR.new(0)).should eq(a)
      end
    end

    it "additive inverse: a + (-a) == 0" do
      10.times do
        a = BR.new(rand(-100..100), rand(1..100))
        (a + (-a)).should eq(BR.new(0))
      end
    end

    it "commutativity of addition: a + b == b + a" do
      10.times do
        a = BR.new(rand(-100..100), rand(1..100))
        b = BR.new(rand(-100..100), rand(1..100))
        (a + b).should eq(b + a)
      end
    end

    it "associativity of addition: (a + b) + c == a + (b + c)" do
      10.times do
        a = BR.new(rand(-50..50), rand(1..50))
        b = BR.new(rand(-50..50), rand(1..50))
        c = BR.new(rand(-50..50), rand(1..50))
        ((a + b) + c).should eq(a + (b + c))
      end
    end

    it "commutativity of multiplication: a * b == b * a" do
      10.times do
        a = BR.new(rand(-100..100), rand(1..100))
        b = BR.new(rand(-100..100), rand(1..100))
        (a * b).should eq(b * a)
      end
    end

    it "multiplicative identity: a * 1 == a" do
      10.times do
        a = BR.new(rand(-100..100), rand(1..100))
        (a * BR.new(1)).should eq(a)
      end
    end

    it "multiplicative inverse: a * inv(a) == 1 for nonzero a" do
      10.times do
        n = rand(-100..100)
        next if n == 0
        a = BR.new(n, rand(1..100))
        (a * a.inv).should eq(BR.new(1))
      end
    end

    it "subtraction consistency: (a + b) - b == a" do
      10.times do
        a = BR.new(rand(-100..100), rand(1..100))
        b = BR.new(rand(-100..100), rand(1..100))
        ((a + b) - b).should eq(a)
      end
    end

    it "distributivity: a * (b + c) == a*b + a*c" do
      10.times do
        a = BR.new(rand(-20..20), rand(1..20))
        b = BR.new(rand(-20..20), rand(1..20))
        c = BR.new(rand(-20..20), rand(1..20))
        (a * (b + c)).should eq(a * b + a * c)
      end
    end
  end
end
