require "benchmark"
require "big"
require "../src/big_number"

puts "BigNumber vs stdlib BigInt (libgmp)"
puts "=" * 50

sizes = {1 => 19, 10 => 190, 30 => 570, 50 => 950, 100 => 1900, 1000 => 19000}

# --- BigRational benchmarks ---
puts "\n\nBigRational Arithmetic"
puts "=" * 50

rational_sizes = {1 => 5, 10 => 50, 50 => 200}

rational_sizes.each do |label, digits|
  num_str = "7" * digits
  den_str = "3" * digits
  r1 = BigNumber::BigRational.new(BigNumber::BigInt.new(num_str), BigNumber::BigInt.new(den_str))
  r2 = BigNumber::BigRational.new(BigNumber::BigInt.new("5" * digits), BigNumber::BigInt.new("9" * digits))

  puts "\n--- ~#{digits} digit numerator/denominator ---"

  Benchmark.ips do |x|
    x.report("BigRational add") { r1 + r2 }
    x.report("BigRational mul") { r1 * r2 }
    x.report("BigRational div") { r1 / r2 }
  end
end

puts "\n\nBigNumber vs stdlib BigInt (libgmp)"
puts "=" * 50

sizes.each do |label, digits|
  str = "9" * digits
  ours = BigNumber::BigInt.new(str)
  theirs = ::BigInt.new(str)

  puts "\n--- #{label} limb(s) (~#{digits} digits) ---"

  Benchmark.ips do |x|
    x.report("BigNumber add") { ours + ours }
    x.report("stdlib    add") { theirs + theirs }
  end

  Benchmark.ips do |x|
    x.report("BigNumber mul") { ours * ours }
    x.report("stdlib    mul") { theirs * theirs }
  end

  if label <= 100
    divisor_str = "7" * (digits // 2 + 1)
    ours_d = BigNumber::BigInt.new(divisor_str)
    theirs_d = ::BigInt.new(divisor_str)

    Benchmark.ips do |x|
      x.report("BigNumber div") { ours // ours_d }
      x.report("stdlib    div") { theirs // theirs_d }
    end
  end
end
