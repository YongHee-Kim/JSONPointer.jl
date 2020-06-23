const TOKEN_PREFIX = '/'

macro j_str(token) 
    Pointer(token) 
end

"""
    Pointer(token)

A JSON Pointer is a Unicode string containing a sequence of zero or more reference tokens, each prefixed
by a '/' (%x2F) character.

Follows IETF JavaScript Object Notation (JSON) Pointer https://tools.ietf.org/html/rfc6901 

### A Few Differences are 
- Index numbers starts from '1' instead of '0'  
- User can declare type with '::T' notation at the end 
"""
struct Pointer{T}
    token::Tuple

    function Pointer(token::AbstractString)
        if !startswith(token, TOKEN_PREFIX) 
            throw(ArgumentError("JSONPointer must starts with '$TOKEN_PREFIX' prefix"))
        end
        
        T = Any
        jk = convert(Array{Any, 1}, split(chop(token; head=1, tail=0), TOKEN_PREFIX))
        if occursin("::", jk[end])
            x = split(jk[end], "::")
            jk[end] = x[1]
            T = (x[2] == "Vector" ? "Vector{Any}" : x[2]) |> Meta.parse |> eval
        end
        @inbounds for i in 1:length(jk)
            if occursin(r"^\d+$", jk[i]) # index of a array
                jk[i] = parse(Int, string(jk[i]))
                if iszero(jk[i]) 
                    throw(AssertionError("Julia uses 1-based indexing"))
                end
            end
        end
    
        new{T}(tuple(jk...)) 
    end
end

""" 
    null_value(p::Pointer{T}) where T
    null_value(::Type{T}) where T

provide appropriate value for 'T'
'Real' return 'zero(T)' and 'AbstractString' returns '""'

If user wants different null value for 'T' override 'null_value(::Type{T})' method 

"""
null_value(p::Pointer) = null_value(eltype(p))
null_value(::Type{T}) where T = missing 
function null_value(::Type{T}) where T <: Array
    eltype(T) <: Real ? eltype(T)[] : 
    eltype(T) <: AbstractString ? eltype(T)[] :
    Any[]
end

for T in (Dict, OrderedDict)
    @eval begin 
        function $T{K,V}(kv::Pair{<:Pointer,V}...) where K<:Pointer where V
            $T{String,Any}()
        end

        Base.haskey(dict::$T{K,V}, p::Pointer) where {K, V} = haskey_by_pointer(dict, p)
        Base.getindex(dict::$T{K,V}, p::Pointer) where {K, V} = getindex_by_pointer(dict, p)
        Base.setindex!(dict::$T{K,V}, v, p::Pointer) where {K, V} = setindex_by_pointer!(dict, v, p)
        Base.get(dict::$T{K,V}, p::JSONPointer, default) where {K, V} = get_by_pointer(dict, p, default)

        # Base.setindex!(dict::$T{K,V}, v, p::Pointer) where {K <: Integer, V} = setindex_by_pointer!(dict, v, p)
    end
end
Base.getindex(A::AbstractArray, p::JSONPointer.Pointer{Any}) = getindex_by_pointer(A, p)

function haskey_by_pointer(collection, p::Pointer)::Bool
    b = true
    val = collection
    @inbounds for (i, k) in enumerate(p.token)
        val = begin 
            if isa(val, Array)
                if !isa(k, Integer)
                    missing
                else 
                    length(val) >= k ? val[k] : missing 
                end
            else 
                if isa(k, Integer)
                    missing
                else 
                    haskey(val, k) ? val[k] : missing 
                end
            end
        end

        if ismissing(val)
            b = false 
            break 
        end
    end
    return b
end

function getindex_by_pointer(collection, p::Pointer, i = 1)
    if i == 1 
        if !haskey(collection, p)
            throw(KeyError(p))
        end 
    end
    val = getindex(collection, p.token[i])
    if i < length(p)
        val = getindex_by_pointer(val, p, i+1)    
    end
    return val
end

function get_by_pointer(collection, p::JSONPointer, default)
    if haskey_by_pointer(collection, p)
        getindex_by_pointer(collection, p)
    else 
        default
    end
end

function setindex_by_pointer!(collection::T, v, p::Pointer{U}) where {T <: AbstractDict, U}
    v = ismissing(v) ? null_value(p) : v
    if !isa(v, U) && 
        try 
            v = convert(eltype(p), v)
        catch e 
            msg = isa(v, Array) ? "Vector" : "Any"
            error("$v is not valid value for $p use '::$msg' if you don't need static type")
            throw(e)
        end
    end
    prev = collection

    @inbounds for (i, k) in enumerate(p.token)
        if isa(prev, AbstractDict) 
            DT = typeof(prev)
        else 
            DT = @eval $(Symbol(T.name)){String, Any}
        end

        if isa(prev, Array)
            if !isa(k, Integer)
                throw(MethodError(setindex!, k))
            end 
            grow_array!(prev, k)
        else 
            if isa(k, Integer)
                throw(MethodError(setindex!, k))
            end
            if !haskey(prev, k)
                setindex!(prev, missing, k)
            end
        end

        if i < length(p) 
            tmp = getindex(prev, k)
            if ismissing(tmp)
                next_key = p.token[i+1]
                if isa(next_key, Integer)
                    new_data = Array{Any,1}(missing, next_key)
                else 
                    new_data = DT(next_key => missing)
                end
                setindex!(prev, new_data, k)
            end
            prev = getindex(prev, k)
        end
    end
    setindex!(prev, v, p.token[end])
end

function grow_array!(arr::Array{T, N}, target_size) where T where N 
    x = target_size - length(arr) 
    if x > 0 
        if T <: Real 
            new_arr = similar(arr, x)
            new_arr .= zero(T)
        elseif T == Any 
            new_arr = similar(arr, x)
            new_arr .= missing 
        else 
            new_arr = Array{Union{T, Missing}}(undef, x)
            new_arr .= missing 
        end
        append!(arr, new_arr)
    end
    return arr
end

Base.length(x::Pointer) = length(x.token)
Base.eltype(x::Pointer{T}) where T = T

function Base.show(io::IO, x::Pointer{T}) where T
    print(io, 
    "JSONPointer{", T, "}(\"/", join(x.token, "/"), "\")")
end

