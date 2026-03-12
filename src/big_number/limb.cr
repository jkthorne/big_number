module BigNumber
  alias Limb = UInt64
  alias SignedLimb = Int64

  LIMB_BITS    = 64
  LIMB_MAX     = Limb::MAX
  LIMB_HIGHBIT = 1_u64 << 63

  # Bump allocator for temporary limb arrays. Single allocation, no per-buffer
  # deallocation — the entire arena is freed when it goes out of scope (via GC).
  struct LimbArena
    @base : Pointer(Limb)
    @offset : Int32
    @capacity : Int32

    def initialize(capacity : Int32)
      @base = Pointer(Limb).malloc(capacity)
      @offset = 0
      @capacity = capacity
    end

    # Allocate n zero-initialized limbs from the arena.
    def alloc(n : Int32) : Pointer(Limb)
      raise "LimbArena exhausted: need #{n}, have #{@capacity - @offset}" if @offset + n > @capacity
      ptr = @base + @offset
      ptr.clear(n)
      @offset += n
      ptr
    end
  end
end
