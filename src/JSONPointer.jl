module JSONPointer

using Compat
using OrderedCollections

include("pointer.jl")
include("pointerdict.jl")

export @j_str, PointerDict

end # module
