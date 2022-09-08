"""
    PointerDict 

`PointerDict` is wrapper around `AbstractDict` that allows to use `JSONPointer` as keys.

## Constructors

PointerDict("a" => 1, "b" => 2)
PointerDict(j"/a" => 1, j"/b" => 2)
PointerDict(Dict("a" => 1, "b" => 2)
"""
struct PointerDict{K<:Union{String,Symbol}, V} <: AbstractDict{K, V}
    d::AbstractDict

    PointerDict(@nospecialize pd::PointerDict) = pd
    PointerDict(d::AbstractDict{String,V}) where {V} = new{String,V}(d)
    PointerDict(d::AbstractDict{Symbol,V}) where {V} = new{Symbol,V}(d)

    function PointerDict(d::T) where T <: AbstractDict
        dict = T{String,valtype(d)}()
        for (k,v) in d
            dict[string(k)] = v
        end
        PointerDict(dict)
    end
    function PointerDict(args...) 
        d = OrderedDict{String, Any}()
        for (k, v) in args
            if isa(k, Pointer)
                _setindex!(d, v, k)
            else 
                setindex!(d, v, k)
            end
        end
        PointerDict(d)
    end
    PointerDict(; kwargs...) = PointerDict(values(kwargs))
end

Base.IteratorSize(@nospecialize T::Type{<:PointerDict}) = Base.IteratorSize(fieldtype(T, :d))
Base.IteratorEltype(@nospecialize T::Type{<:PointerDict}) = Base.IteratorEltype(eltype(T))

Base.length(pd::PointerDict) = length(getfield(pd, :d))
function Base.sizehint!(pd::PointerDict, n::Integer)
    sizehint!(getfield(pd, :d), n)
    return pd
end

Base.keytype(@nospecialize T::Type{<:PointerDict{String}}) = String
Base.keytype(@nospecialize T::Type{<:PointerDict{Symbol}}) = Symbol

Base.pop!(pd::PointerDict, k) = pop!(getfield(pd, :d),  k)
Base.pop!(pd::PointerDict, k, d) = pop!(getfield(pd, :d), k, d)

function Base.empty!(pd::PointerDict)
    empty!(getfield(pd, :d))
    return pd
end
Base.isempty(pd::PointerDict) = isempty(getfield(pd, :d))
function Base.empty(pd::PointerDict, ::Type{K}=keytype(pd), ::Type{V}=valtype(pd)) where {K,V}
    PointerDict(empty(getfield(pd, :d), K, V))
end

function Base.delete!(pd::PointerDict, k)
    delete!(getfield(pd, :d), k)
    return pd
end

function Base.get(pd::PointerDict, k, d)
    get(getfield(pd, :d), k, d)
end
function Base.get(pd::PointerDict, jk::Pointer, d)
    _get(getfield(pd, :d), jk, d)
end
function Base.get(f::Base.Callable, pd::PointerDict, k)
    get(f, getfield(pd, :d), k)
end
function Base.get(f::Base.Callable, pd::PointerDict, jp::Pointer)
    _get(f, getfield(pd, :d), jp)
end

function Base.get!(pd::PointerDict, k, d)
    get!(getfield(pd, :d), k, d)
end
function Base.get!(pd::PointerDict, jp::Pointer, d)
    _get!(getfield(pd, :d), jp, d)
end
function Base.get!(f::Base.Callable, pd::PointerDict, k)
    get!(f, getfield(pd, :d), pd, k)
end
function Base.get!(f::Base.Callable, pd::PointerDict, jp::Pointer)
    _get!(f, getfield(pd, :d), jp)
end

function Base.getindex(pd::PointerDict, k)
    getindex(getfield(pd, :d), k)
end
function Base.getindex(pd::PointerDict, jp::Pointer)
    _getindex(getfield(pd, :d), jp)
end
function Base.setindex!(pd::PointerDict, v, k)
    setindex!(getfield(pd, :d), v, k)
end
function Base.setindex!(pd::PointerDict, v, jp::Pointer)
    _setindex!(getfield(pd, :d), v, jp)
end

Base.reverse(pd::PointerDict) = PointerDict(reverse(getfield(pd, :d)))

Base.iterate(pd::PointerDict) = iterate(getfield(pd, :d))
Base.iterate(pd::PointerDict, i) = iterate(getfield(pd, :d), i)

Base.values(pd::PointerDict) = values(getfield(pd, :d))

Base.haskey(pd::PointerDict, k) = haskey(getfield(pd, :d), k)
Base.haskey(pd::PointerDict, jp::Pointer) = _haskey(getfield(pd, :d), jp)
Base.getkey(pd::PointerDict, k, d) = getkey(getfield(pd, :d), k, d)
Base.getkey(pd::PointerDict, jp::Pointer, d) = getkey(getfield(pd, :d), jp, d)
Base.keys(pd::PointerDict) = keys(getfield(pd, :d))

Base.copy(pd::PointerDict) = PointerDict(copy(getfield(pd, :d)))

## merge and mergewith
Base.merge(pd::PointerDict) = copy(pd)

function Base.merge(pd::PointerDict, pds::PointerDict...)
    K = _promote_keytypes((pd, pds...))
    V = _promote_valtypes(valtype(pd), pds...)
    out = PointerDict(Dict{K,V}())
    for (k,v) in pd
        out[k] = v
    end
    merge!(out, pds...)
end

@compat Base.mergewith(combine, pd::PointerDict) = copy(pd)
@compat function Base.mergewith(combine, pd::PointerDict, pds::PointerDict...)
    K = _promote_keytypes((pd, pds...))
    V0 = _promote_valtypes(valtype(pd), pds...)
    V = promote_type(Core.Compiler.return_type(combine, Tuple{V0,V0}), V0)
    out = PointerDict(Dict{K,V}())
    for (k,v) in pd
        out[k] = v
    end
    mergewith!(combine, out, pds...)
end

# fall back to String if we don't clearly have Symbol
_promote_keytypes(@nospecialize(pds::Tuple{Vararg{PointerDict{Symbol, T}}})) where T = Symbol
_promote_keytypes(@nospecialize(pds::Tuple{Vararg{PointerDict}})) = String
_promote_valtypes(V) = V
function _promote_valtypes(V, d, ds...)  # give up if promoted to any
    V === Any ? Any : _promote_valtypes(promote_type(V, valtype(d)), ds...)
end