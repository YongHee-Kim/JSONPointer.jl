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



"""
   @set_pointer(expr)

The macro extracts document, key, and value, then constructs an expression to call `set_pointer!` with these arguments, providing syntactic sugar for JSONPointer with `AbstractDict` types.

## Example 
JSONPointer.@set_pointer doc[key] = value 
"""
macro set_pointer(expr)
    # Check if the expression is of the form `doc[key] = value`
    if expr.head !== :(=)
        error("@set_pointer expects a syntax `doc[key] = value`")
    end

    # Extract the document, key, and value from the expression
    doc_expr = expr.args[1].args[1]
    key_expr = expr.args[1].args[2]
    value_expr = expr.args[2]

    # Construct a new expression that calls `set_pointer!` with the extracted arguments
    new_expr = quote
        doc = $(esc(doc_expr))
        key = $(esc(key_expr))
        value = $(esc(value_expr))
        set_pointer!(doc, key, value)
    end
    return new_expr
end

macro get_pointer(expr)
    # Check if the expression is of the form `doc[key]`
    if expr.head !== :ref
        error("@get_pointer expects a syntax `doc[key]`")
    end

    doc_expr = expr.args[1]
    key_expr = expr.args[2]

    new_expr = quote
        doc = $(esc(doc_expr))
        key = $(esc(key_expr))
        get_pointer(doc, key)
    end
    return new_expr
end
