require "big"
require "../src/big_number"

# The bug is in squaring 10^4864 (a power of 10 used in DC base conversion)
# Let's test squaring large powers of 10

[1216, 2432, 4864, 9728].each do |exp|
  ours_p = BigNumber::BigInt.new(10) ** exp
  theirs_p = ::BigInt.new(10) ** exp
  puts "10^#{exp} construction: #{ours_p.to_s == theirs_p.to_s ? "PASS" : "FAIL"}"

  ours_sq = (ours_p * ours_p).to_s
  theirs_sq = (theirs_p * theirs_p).to_s
  puts "  squaring: #{ours_sq == theirs_sq ? "PASS" : "FAIL"} (#{ours_p.to_s.size} digits)"
end

# Also test: does the exponentiation (**) use multiplication correctly?
puts "\nDirect exponentiation test..."
[2432, 4864, 9728].each do |exp|
  ours = (BigNumber::BigInt.new(10) ** exp).to_s
  theirs = (::BigInt.new(10) ** exp).to_s
  puts "10^#{exp}: #{ours == theirs ? "PASS" : "FAIL"}"
end
