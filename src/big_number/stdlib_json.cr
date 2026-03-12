require "json"
require "./stdlib"

class JSON::Builder
  # Writes a `BigDecimal` value as a JSON number.
  def number(number : BigDecimal) : Nil
    scalar do
      @io << number
    end
  end
end

struct BigInt
  # Deserializes a `BigInt` from a JSON integer or string.
  def self.new(pull : JSON::PullParser) : self
    case pull.kind
    when .int?
      value = pull.raw_value
      pull.read_next
    else
      value = pull.read_string
    end
    new(value)
  end

  # Attempts to parse a JSON object key as a `BigInt`.
  # Returns `nil` if the key is not a valid integer string.
  def self.from_json_object_key?(key : String) : BigInt?
    new(key)
  rescue ArgumentError
    nil
  end

  # Returns the string representation for use as a JSON object key.
  def to_json_object_key : String
    to_s
  end

  # Serializes this `BigInt` as a JSON number.
  def to_json(json : JSON::Builder) : Nil
    json.number(self)
  end
end

struct BigFloat
  # Deserializes a `BigFloat` from a JSON integer, float, or string.
  def self.new(pull : JSON::PullParser) : self
    case pull.kind
    when .int?, .float?
      value = pull.raw_value
      pull.read_next
    else
      value = pull.read_string
    end
    new(value)
  end

  # Attempts to parse a JSON object key as a `BigFloat`.
  # Returns `nil` if the key is not a valid number string.
  def self.from_json_object_key?(key : String) : BigFloat?
    new(key)
  rescue ArgumentError
    nil
  end

  # Returns the string representation for use as a JSON object key.
  def to_json_object_key : String
    to_s
  end

  # Serializes this `BigFloat` as a JSON number.
  def to_json(json : JSON::Builder) : Nil
    json.number(self)
  end
end

struct BigDecimal
  # Deserializes a `BigDecimal` from a JSON integer, float, or string.
  def self.new(pull : JSON::PullParser) : self
    case pull.kind
    when .int?, .float?
      value = pull.raw_value
      pull.read_next
    else
      value = pull.read_string
    end
    new(value)
  end

  # Attempts to parse a JSON object key as a `BigDecimal`.
  # Returns `nil` if the key is not a valid decimal string.
  def self.from_json_object_key?(key : String) : BigDecimal?
    new(key)
  rescue InvalidBigDecimalException
    nil
  end

  # Returns the string representation for use as a JSON object key.
  def to_json_object_key : String
    to_s
  end

  # Serializes this `BigDecimal` as a JSON number.
  def to_json(json : JSON::Builder) : Nil
    json.number(self)
  end
end
