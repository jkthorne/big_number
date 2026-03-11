require "spec"

{% if flag?(:big_number_stdlib) %}
require "../src/big_number/stdlib_json"
require "../src/big_number/stdlib_yaml"

describe "Phase 7: JSON serialization" do
  describe "BigInt" do
    it "serializes to JSON" do
      BigInt.new(42).to_json.should eq("42")
    end

    it "serializes negative to JSON" do
      BigInt.new(-123).to_json.should eq("-123")
    end

    it "serializes large number to JSON" do
      big = BigInt.new("123456789012345678901234567890")
      big.to_json.should eq("123456789012345678901234567890")
    end

    it "deserializes from JSON int" do
      result = BigInt.from_json("42")
      result.should eq(BigInt.new(42))
    end

    it "deserializes from JSON string" do
      result = BigInt.from_json("\"123456789012345678901234567890\"")
      result.should eq(BigInt.new("123456789012345678901234567890"))
    end

    it "round-trips through JSON" do
      original = BigInt.new("999999999999999999999")
      json = original.to_json
      restored = BigInt.from_json(json)
      restored.should eq(original)
    end

    it "works as JSON object key" do
      BigInt.from_json_object_key?("42").should eq(BigInt.new(42))
      BigInt.from_json_object_key?("not_a_number").should be_nil
    end

    it "converts to JSON object key" do
      BigInt.new(42).to_json_object_key.should eq("42")
    end
  end

  describe "BigFloat" do
    it "serializes to JSON" do
      BigFloat.new(1.5).to_json.should eq("1.5")
    end

    it "serializes integer BigFloat to JSON" do
      BigFloat.new(42.0).to_json.should eq("42.0")
    end

    it "deserializes from JSON float" do
      result = BigFloat.from_json("1.5")
      result.should eq(BigFloat.new(1.5))
    end

    it "deserializes from JSON int" do
      result = BigFloat.from_json("42")
      result.should eq(BigFloat.new(42.0))
    end

    it "deserializes from JSON string" do
      result = BigFloat.from_json("\"1.5\"")
      result.should eq(BigFloat.new(1.5))
    end

    it "works as JSON object key" do
      BigFloat.from_json_object_key?("1.5").should eq(BigFloat.new(1.5))
      BigFloat.from_json_object_key?("not_a_number").should be_nil
    end

    it "converts to JSON object key" do
      BigFloat.new(1.5).to_json_object_key.should eq("1.5")
    end
  end

  describe "BigDecimal" do
    it "serializes to JSON" do
      BigDecimal.new("1.23").to_json.should eq("1.23")
    end

    it "serializes integer BigDecimal to JSON" do
      BigDecimal.new(42).to_json.should eq("42.0")
    end

    it "deserializes from JSON float" do
      result = BigDecimal.from_json("1.23")
      result.should eq(BigDecimal.new("1.23"))
    end

    it "deserializes from JSON int" do
      result = BigDecimal.from_json("42")
      result.should eq(BigDecimal.new(42))
    end

    it "deserializes from JSON string" do
      result = BigDecimal.from_json("\"1.23\"")
      result.should eq(BigDecimal.new("1.23"))
    end

    it "works as JSON object key" do
      BigDecimal.from_json_object_key?("1.23").should eq(BigDecimal.new("1.23"))
    end

    it "converts to JSON object key" do
      BigDecimal.new("1.23").to_json_object_key.should eq("1.23")
    end

    it "round-trips through JSON" do
      original = BigDecimal.new("3.14159265358979323846")
      json = original.to_json
      restored = BigDecimal.from_json(json)
      restored.should eq(original)
    end
  end
end

describe "Phase 7: YAML serialization" do
  describe "BigInt" do
    it "serializes to YAML" do
      BigInt.new(42).to_yaml.should contain("42")
    end

    it "deserializes from YAML" do
      result = BigInt.from_yaml("42")
      result.should eq(BigInt.new(42))
    end

    it "round-trips through YAML" do
      original = BigInt.new("123456789012345678901234567890")
      yaml = original.to_yaml
      restored = BigInt.from_yaml(yaml)
      restored.should eq(original)
    end
  end

  describe "BigFloat" do
    it "serializes to YAML" do
      BigFloat.new(1.5).to_yaml.should contain("1.5")
    end

    it "deserializes from YAML" do
      result = BigFloat.from_yaml("1.5")
      result.should eq(BigFloat.new(1.5))
    end

    it "round-trips through YAML" do
      original = BigFloat.new(42.0)
      yaml = original.to_yaml
      restored = BigFloat.from_yaml(yaml)
      restored.should eq(original)
    end
  end

  describe "BigDecimal" do
    it "serializes to YAML" do
      BigDecimal.new("1.23").to_yaml.should contain("1.23")
    end

    it "deserializes from YAML" do
      result = BigDecimal.from_yaml("1.23")
      result.should eq(BigDecimal.new("1.23"))
    end

    it "round-trips through YAML" do
      original = BigDecimal.new("3.14159265358979323846")
      yaml = original.to_yaml
      restored = BigDecimal.from_yaml(yaml)
      restored.should eq(original)
    end
  end
end
{% end %}
