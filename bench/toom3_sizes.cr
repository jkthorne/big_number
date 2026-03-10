require "big"
require "../src/big_number"

a_str = "9" * (513 * 19)
b_str = "7" * (513 * 19)
prod = BigNumber::BigInt.new(a_str) * BigNumber::BigInt.new(b_str)
prod_std = ::BigInt.new(a_str) * ::BigInt.new(b_str)

# Check product limbs against stdlib
prod_expected = BigNumber::BigInt.new(prod_std.to_s)
puts "Product: #{prod.abs_size} limbs"
prod_ok = true
prod.abs_size.times do |i|
  if prod.@limbs[i] != prod_expected.@limbs[i]
    puts "Product LIMB MISMATCH at #{i}: ours=#{prod.@limbs[i]}, expected=#{prod_expected.@limbs[i]}"
    prod_ok = false
    break
  end
end
puts "Product limbs: #{prod_ok ? "PASS" : "FAIL"}"

# Check divisor
divisor = BigNumber::BigInt.new(10) ** 19456
divisor_std = ::BigInt.new(10) ** 19456
divisor_expected = BigNumber::BigInt.new(divisor_std.to_s)
puts "\nDivisor: #{divisor.abs_size} limbs"
div_ok = true
divisor.abs_size.times do |i|
  if divisor.@limbs[i] != divisor_expected.@limbs[i]
    puts "Divisor LIMB MISMATCH at #{i}: ours=#{divisor.@limbs[i]}, expected=#{divisor_expected.@limbs[i]}"
    div_ok = false
    break
  end
end
puts "Divisor limbs: #{div_ok ? "PASS" : "FAIL"}"

# Now test the division itself
hi, lo = prod.tdiv_rem(divisor)
hi_std = prod_std // divisor_std
lo_std = prod_std % divisor_std

hi_expected = BigNumber::BigInt.new(hi_std.to_s)
lo_expected = BigNumber::BigInt.new(lo_std.to_s)

puts "\nDivision result:"
puts "hi: #{hi.abs_size} limbs (expected #{hi_expected.abs_size})"
hi_ok = true
Math.min(hi.abs_size, hi_expected.abs_size).times do |i|
  if hi.@limbs[i] != hi_expected.@limbs[i]
    puts "hi MISMATCH at limb #{i}"
    hi_ok = false
    break
  end
end
puts "hi: #{hi_ok ? "PASS" : "FAIL"}"

puts "lo: #{lo.abs_size} limbs (expected #{lo_expected.abs_size})"
lo_ok = true
Math.min(lo.abs_size, lo_expected.abs_size).times do |i|
  if lo.@limbs[i] != lo_expected.@limbs[i]
    puts "lo MISMATCH at limb #{i}"
    lo_ok = false
    break
  end
end
puts "lo: #{lo_ok ? "PASS" : "FAIL"}"

# Also check: does our tdiv_rem satisfy hi*div + lo == prod?
reconstructed = hi * divisor + lo
recon_ok = true
prod.abs_size.times do |i|
  if reconstructed.@limbs[i] != prod.@limbs[i]
    puts "\nReconstruction MISMATCH at limb #{i}"
    recon_ok = false
    break
  end
end
puts "\nReconstruction (hi*div+lo==prod): #{recon_ok ? "PASS" : "FAIL"}"
