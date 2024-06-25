module JSONPointer

using OrderedCollections, TypedDelegation

include("pointer.jl")
include("pointerdict.jl")
include("abstractdict_interface.jl")

export @j_str, PointerDict, has_pointer, get_pointer, set_pointer!

end # module
