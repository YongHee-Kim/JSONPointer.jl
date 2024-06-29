# Contains interfaces for AbstractDict 
function has_pointer(dict::AbstractDict, p::Pointer)
    _haskey(dict, p)
end

function get_pointer(dict::AbstractDict, p::Pointer)
    _getindex(dict, p)
end
function get_pointer(dict::AbstractDict, p::Pointer, default)
    if has_pointer(dict, p)
        return _getindex(dict, p)
    end 
    return default
end
function set_pointer!(dict::AbstractDict, p::Pointer, value)
    _setindex!(dict, value, p)
end

# Fallback funcctions, When provided key is not JSONPointer 
set_pointer!(dict::AbstractDict, key, value) = setindex!(dict, value, key)
get_pointer(dict::AbstractDict, key, default) = get(dict, key, default)
get_pointer(dict::AbstractDict, key) = getindex(dict, key)

