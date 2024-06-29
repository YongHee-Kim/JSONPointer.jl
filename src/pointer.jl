const TOKEN_PREFIX = '/'

macro j_str(token)
    Pointer(token)
end

"""
    _unescape_jpath(raw::String)

Transform escaped characters in JPaths back to their original value.
https://tools.ietf.org/html/rfc6901
"""
function _unescape_jpath(raw::AbstractString)
    m = match(r"%([0-9A-F]{2})", raw)
    if m !== nothing
        for c in m.captures
            raw = replace(raw, "%$(c)" => Char(parse(UInt8, "0x$(c)")))
        end
    end
    return raw
end

function _last_element_to_type!(jk)
    if !occursin("::", jk[end])
        return Any
    end
    x = split(jk[end], "::")
    jk[end] = String(x[1])
    if x[2] == "string"
        return String
    elseif x[2] == "number"
        return Union{Int, Float64}
    elseif x[2] == "object"
        return OrderedDict{String, Any}
    elseif x[2] == "array"
        return Vector{Any}
    elseif x[2] == "boolean"
        return Bool
    elseif x[2] == "null"
        return Missing
    else
        # what is most fitting error type for this?

    throw(DomainError(
            "`::$(x[2])`cannot be used in JSON. use one of `::string`, `::number`, " *
            "`::object`, `::array`, `::boolean`, or `::null`."
        ))
    end
end

"""
    Pointer(token::AbstractString; shift_index::Bool = false)

A JSON Pointer is a Unicode string containing a sequence of zero or more
reference tokens, each prefixed by a '/' (%x2F) character.

Follows IETF JavaScript Object Notation (JSON) Pointer https://tools.ietf.org/html/rfc6901.

## Arguments

- `shift_index`: shift given index by 1 for compatibility with original JSONPointer.

## Non-standard extensions

- Index numbers starts from `1` instead of `0`

- User can declare type with '::T' notation at the end. For example
  `/foo::string`. The type `T` must be one of the six types supported by JSON:
  * `::string`
  * `::number`
  * `::object`
  * `::array`
  * `::boolean`
  * `::null`

## Examples

    Pointer("/a")
    Pointer("/a/3")
    Pointer("/a/b/c::number")
    Pointer("/a/0/c::object"; shift_index = true)
"""
struct Pointer{T}
    tokens::Vector{Union{String, Int}}
end

function Pointer(token_string::AbstractString; shift_index::Bool = false)
    if startswith(token_string, "#")
        token_string = _unescape_jpath(token_string[2:end])
    end
    if isempty(token_string)
        return Pointer{Nothing}([""])
    end
    if !startswith(token_string, TOKEN_PREFIX)
        throw(ArgumentError("JSONPointer must starts with '$TOKEN_PREFIX' prefix"))
    end
    tokens = convert(
        Vector{Union{String, Int}},
        String.(split(token_string, TOKEN_PREFIX; keepempty = false)),
    )
    if length(tokens) == 0
        return Pointer{Any}([""])
    end
    T = _last_element_to_type!(tokens)
    for (i, token) in enumerate(tokens)
        if occursin(r"^\d+$", token) # index of a array
            tokens[i] = parse(Int, token)
            if shift_index
                tokens[i] += 1
            end
            if iszero(tokens[i])
                throw(BoundsError("Julia uses 1-based indexing, use '1' instead of '0'"))
            end
        elseif occursin(r"^\\\d+$", token) # literal string for a number
            tokens[i] = String(chop(token; head = 1, tail = 0))
        elseif occursin("~", token)
            tokens[i] = replace(replace(token, "~0" => "~"), "~1" => "/")
        end
    end
    return Pointer{T}(tokens)
end

Base.length(x::Pointer) = length(x.tokens)
Base.eachindex(x::Pointer) = eachindex(x.tokens)

Base.eltype(::Pointer{T}) where {T} = T

function Base.show(io::IO, x::Pointer{T}) where {T}
    print(io, "JSONPointer{", T, "}(\"/", join(x.tokens, "/"), "\")")
end

function Base.show(io::IO, ::Pointer{Nothing})
    print(io, "JSONPointer{Nothing}(\"\")")
end


Base.getindex(A::AbstractArray, p::Pointer) = _getindex(A, p)
Base.haskey(A::AbstractArray, p::Pointer) = _haskey(A, p)

function Base.unique(arr::AbstractArray{<:Pointer, N}) where {N}
    out = deepcopy(arr)
    if isempty(arr)
        return out
    end
    pointers = getfield.(arr, :tokens)
    if allunique(pointers)
        return out
    end
    delete_target = Int[]
    for p in pointers
        indicies = findall(el -> el == p, pointers)
        if length(indicies) > 1
            append!(delete_target, indicies[1:end-1])
        end
    end
    deleteat!(out, unique(delete_target))
    return out
end

Base.:(==)(a::Pointer{U}, b::Pointer{U}) where {U} = a.tokens == b.tokens

# ==============================================================================

_checked_get(collection::AbstractArray, token::Int) = collection[token]
_checked_get(collection::Tuple, token::Int) = collection[token]
_checked_get(collection::AbstractDict, token::String) = get_pointer(collection, token)

# ==============================================================================

_haskey(::Any, ::Pointer{Nothing}) = true

function _haskey(collection, p::Pointer)
    for token in p.tokens
        if !_haskey(collection, token)
            return false
        end
        collection = _checked_get(collection, token)
    end
    return true
end

_haskey(collection::AbstractDict, token::String) = haskey(collection, token)

function _haskey(collection::AbstractArray, token::Int)
    return 1 <= token <= length(collection)
end
function _haskey(collection::Tuple, token::Int)
    return 1 <= token <= length(collection)
end
_haskey(::Any, ::Any) = false

# ==============================================================================
_getindex(collection, ::Pointer{Nothing}) = collection
function _getindex(collection, p::Pointer)
    for (i, token) in enumerate(p.tokens)
        if !_haskey(collection, token)
            throw(ElementRetrievalError(collection, p, i))
        end
        collection = _checked_get(collection, token)
    end
    return collection
end

# ==============================================================================

function _get(collection, p::Pointer, default)
    if _haskey(collection, p)
        return _getindex(collection, p)
    end
    return default
end
function _get!(collection, p::Pointer, default)
    if _haskey(collection, p)
        return _getindex(collection, p)
    else 
        _setindex!(collection, default, p)
    end
    return default
end

# ==============================================================================

_null_value(p::Pointer) = _null_value(eltype(p))
_null_value(::Type{String}) = ""
_null_value(::Type{<:Real}) = 0
_null_value(::Type{<:AbstractDict}) = OrderedDict{String, Any}()
_null_value(::Type{<:AbstractVector{T}}) where {T} = T[]
_null_value(::Type{Bool}) = false
_null_value(::Type{Nothing}) = nothing
_null_value(::Type{Missing}) = missing

_null_value(::Type{Any}) = missing

_convert_v(v::U, ::Pointer{U}) where {U} = v
function _convert_v(v::V, p::Pointer{U}) where {U, V}
    v = ismissing(v) ? _null_value(p) : v
    try
        # Conversion to OrderedDict is deprecated for unordered associative containers. Have to be sorted before the conversion
        if eltype(p) <: OrderedDict
            if <:(V, OrderedDict) == false
                return convert(eltype(p), sort!(OrderedDict(v)))
            end
        end
        return convert(eltype(p), v)
    catch
        throw(ArgumentError(
            "$(v)::$(typeof(v)) is not valid type for $(p). Remove type " *
            "assertion in the JSON pointer if you don't a need static type."
        ))
    end
end

function _add_element_if_needed(prev::AbstractVector{T}, k::Int) where {T}
    x = k - length(prev)
    if x > 0
        append!(prev, [_null_value(T) for _ = 1:x])
    end
    return
end

function _add_element_if_needed(prev::AbstractDict{K, V}, k::String) where {K, V}
    if !haskey(prev, k)
        prev[k] = _null_value(V)
    end
end

_new_data(::Any, n::Int) = Vector{Any}(missing, n)
_new_data(::AbstractVector, ::String) = OrderedDict{String, Any}()
function _new_data(x::T, ::String) where T <: AbstractDict
    OrderedDict{String, Any}()
end

function _setindex!(collection::AbstractDict, v, p::Pointer)
    prev = collection
    for (i, token) in enumerate(p.tokens)
        if !hasmethod(_add_element_if_needed, (typeof(prev), typeof(token)))
            throw(ElementInsertionError(collection, p, i))
        end    
        _add_element_if_needed(prev, token)
        if i < length(p)
            if ismissing(prev[token])
                prev[token] = _new_data(prev, p.tokens[i + 1])
            end
            prev = prev[token]
        end
    end
    prev[p.tokens[end]] = _convert_v(v, p)
    return v
end

# pointer manipulation functions
function Base.append!(p::Pointer, token::Union{String, Int})
    push!(p.tokens, token)
    return p
end
function Base.deleteat!(p::Pointer, index::Int)
    deleteat!(p.tokens, index)
    return p
end
function Base.pop!(p::Pointer)
    pop!(p.tokens)
    return p
end

# Exception Handling 
struct ElementRetrievalError <: Exception
    collection
    pointer::Pointer
    token_index
end
function Base.showerror(io::IO, err::ElementRetrievalError)   
    error_msg = string("ElementRetrievalError:\"", mark_error_in_pointer(err.pointer, err.token_index), "\" from: ", err.collection, "\n └")

    width_limit = displaysize()[2] * 3
    if textwidth(error_msg) >= width_limit
        print(io, error_msg[1:width_limit - 6], "...")
    else 
        print(io, error_msg)
    end

    token = err.pointer.tokens[err.token_index]
    if isa(err.collection, AbstractDict)
        showerror(io, KeyError(token))
    elseif isa(err.collection, AbstractArray)
        showerror(io, BoundsError(err.collection, token))
    else 
        showerror(io, MethodError(_getindex, (err.collection, token)))
    end
end

struct ElementInsertionError <: Exception 
    collection
    pointer::Pointer
    token_index
end

function Base.showerror(io::IO, err::ElementInsertionError)
    error_msg = string("ElementInsertionError:\"", mark_error_in_pointer(err.pointer, err.token_index), "\" to: ", err.collection, "\n └")

    print(io, error_msg)
end

function mark_error_in_pointer(p::Pointer, token_index::Int)
    tokens = p.tokens
    error_msg = join(tokens[1:token_index-1], "/")
    error_msg *= string("/", "\033[1m\033[31m", tokens[token_index], "\033[0m")
    if token_index < length(tokens)
        error_msg *= "/" * join(tokens[token_index+1:end], "/")
    end
    return error_msg
end
