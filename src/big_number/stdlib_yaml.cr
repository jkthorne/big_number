require "yaml"
require "./stdlib"

# Deserializes a `BigInt` from a YAML scalar node.
#
# Raises if the node is not a scalar.
def BigInt.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : self
  unless node.is_a?(YAML::Nodes::Scalar)
    node.raise "Expected scalar, not #{node.class}"
  end

  BigInt.new(node.value)
end

# Deserializes a `BigFloat` from a YAML scalar node.
#
# Raises if the node is not a scalar.
def BigFloat.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : self
  unless node.is_a?(YAML::Nodes::Scalar)
    node.raise "Expected scalar, not #{node.class}"
  end

  BigFloat.new(node.value)
end

# Deserializes a `BigDecimal` from a YAML scalar node.
#
# Raises if the node is not a scalar.
def BigDecimal.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : self
  unless node.is_a?(YAML::Nodes::Scalar)
    node.raise "Expected scalar, not #{node.class}"
  end

  BigDecimal.new(node.value)
end
