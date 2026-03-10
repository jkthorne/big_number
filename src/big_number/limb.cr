module BigNumber
  alias Limb = UInt64
  alias SignedLimb = Int64

  LIMB_BITS    = 64
  LIMB_MAX     = Limb::MAX
  LIMB_HIGHBIT = 1_u64 << 63
end
