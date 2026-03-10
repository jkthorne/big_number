module BigNumber
  # Low-level operations on unsigned limb arrays.
  # This is the foundation layer — all higher-level types build on these.
  #
  # Conventions:
  # - Limb arrays are represented as Pointer(Limb) + size
  # - Results may alias inputs unless noted otherwise
  # - Return values are typically the carry/borrow limb
  module MPN
    # TODO: Phase 1 implementation
    # P0: copyi, copyd, zero, cmp, zero_p
    # P0: add_1, add_n, add, sub_1, sub_n, sub
    # P0: mul_1, addmul_1, submul_1
    # P0: lshift, rshift
    # P1: mul, mul_n, sqr, invert_3by2
    # P2: gcd, sqrtrem, perfect_square_p
    # P2: scan0, scan1, com, neg, popcount
    # P3: get_str, set_str
  end
end
