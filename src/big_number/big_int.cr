require "./big_int/*"

module BigNumber
  # Arbitrary-precision signed integer.
  #
  # Uses sign-magnitude representation internally:
  # - @size > 0: positive, abs(@size) limbs used
  # - @size < 0: negative, abs(@size) limbs used
  # - @size == 0: zero
  struct BigInt
    include Comparable(BigInt)
    include Comparable(Int)

    @limbs : Pointer(Limb)
    @alloc : Int32
    @size : Int32

    # TODO: Phase 2 implementation
    # See PLAN.md for full function list

    def initialize
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
    end

    def initialize(value : Int)
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
      # TODO: set from integer
    end

    def initialize(str : String, base : Int32 = 10)
      @limbs = Pointer(Limb).null
      @alloc = 0
      @size = 0
      # TODO: parse from string
    end

    def <=>(other : BigInt) : Int32
      0 # TODO
    end

    def <=>(other : Int) : Int32
      0 # TODO
    end
  end
end
