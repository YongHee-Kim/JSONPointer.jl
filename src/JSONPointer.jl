module JSONPointer

using OrderedCollections, TypedDelegation

include("pointer.jl")
include("pointerdict.jl")

export @j_str, PointerDict

end # module
