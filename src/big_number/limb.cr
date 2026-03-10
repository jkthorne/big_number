module BigNumber
  # Core limb type — a single "digit" in our multi-precision representation.
  # On 64-bit systems, each limb holds 64 bits of the number.
  alias Limb = UInt64
  alias SignedLimb = Int64
  alias LimbSize = Int32
  alias BitCount = UInt64

  LIMB_BITS    = 64_u64
  LIMB_MAX     = Limb::MAX
  LIMB_HIGHBIT = 1_u64 << 63
  HLIMB_BIT    = 1_u64 << 32
  LLIMB_MASK   = HLIMB_BIT &- 1

  module LimbUtil
    # Full 64×64 → 128-bit multiply. Returns {high, low}.
    @[AlwaysInline]
    def self.umul_ppmm(u : Limb, v : Limb) : {Limb, Limb}
      result = u.to_u128 &* v.to_u128
      {(result >> 64).to_u64, result.to_u64}
    end

    # 128÷64 division. Divides (n1:n0) by d. Returns {quotient, remainder}.
    # Precondition: n1 < d (quotient fits in one limb).
    @[AlwaysInline]
    def self.udiv_qrnnd(n1 : Limb, n0 : Limb, d : Limb) : {Limb, Limb}
      n = (n1.to_u128 << 64) | n0.to_u128
      q = (n // d.to_u128).to_u64
      r = (n % d.to_u128).to_u64
      {q, r}
    end

    # Count leading zeros in a limb.
    @[AlwaysInline]
    def self.clz(x : Limb) : Int32
      return 64 if x == 0
      x.leading_zeros_count
    end

    # Count trailing zeros in a limb.
    @[AlwaysInline]
    def self.ctz(x : Limb) : Int32
      return 64 if x == 0
      x.trailing_zeros_count
    end

    # Population count (number of set bits).
    @[AlwaysInline]
    def self.popcount(x : Limb) : Int32
      x.popcount
    end
  end
end
