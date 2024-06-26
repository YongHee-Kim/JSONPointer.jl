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
        dict = dicttype(T){String,valtype(d)}()
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
    # PointerDict(; kwargs...) = PointerDict(values(kwargs))
end

dicttype(::Type{T}) where T <: AbstractDict = eval(T.name.wrapper)
dicttype(x::T) where T <: AbstractDict = eval(T.name.wrapper)

Base.IteratorSize(@nospecialize T::Type{<:PointerDict}) = Base.IteratorSize(fieldtype(T, :d))
Base.IteratorEltype(@nospecialize T::Type{<:PointerDict}) = Base.IteratorEltype(eltype(T))

Base.keytype(@nospecialize T::Type{<:PointerDict{String}}) = String
Base.keytype(@nospecialize T::Type{<:PointerDict{Symbol}}) = Symbol

function Base.empty(pd::PointerDict, ::Type{K}=keytype(pd), ::Type{V}=valtype(pd)) where {K,V}
    PointerDict(empty(getfield(pd, :d), K, V))
end

# Simply delegated dictionary functions to the wrapped PointerDdicct object
# NOTE: push! is not included below, because the fallback version just
#       calls setindex!
@delegate_onefield(PointerDict, d, [ Base.getindex, Base.get, Base.get!, Base.haskey,
Base.getkey, Base.pop!, Base.iterate,
Base.isempty, Base.length, Base.delete!, Base.setindex!])
# Base.copy(pd::PointerDict) = PointerDict(copy(getfield(pd, :d)))

# empty! returns the wrapped dictionary if simply delegated 
function Base.empty!(pd::PointerDict)
    empty!(getfield(pd, :d))
    return pd
end


function Base.get(pd::PointerDict, jk::Pointer, d)
    _get(getfield(pd, :d), jk, d)
end
function Base.get(f::Base.Callable, pd::PointerDict, jp::Pointer)
    _get(f, getfield(pd, :d), jp)
end

function Base.get!(pd::PointerDict, jp::Pointer, d)
    _get!(getfield(pd, :d), jp, d)
end
function Base.get!(f::Base.Callable, pd::PointerDict, jp::Pointer)
    _get!(f, getfield(pd, :d), jp)
end

function Base.getindex(pd::PointerDict, jp::Pointer)
    _getindex(getfield(pd, :d), jp)
end

function Base.setindex!(pd::PointerDict, v, jp::Pointer)
    _setindex!(getfield(pd, :d), v, jp)
end
Base.haskey(pd::PointerDict, jp::Pointer) = _haskey(getfield(pd, :d), jp)
Base.getkey(pd::PointerDict, jp::Pointer, d) = getkey(getfield(pd, :d), jp, d)

## merge and mergewith
Base.merge(pd::PointerDict) = copy(pd)

function Base.merge(pd::PointerDict, pds::PointerDict...)
    K = _promote_keytypes((pd, pds...))
    V = _promote_valtypes(valtype(pd), pds...)
    out = PointerDict(Dict{K,V}())
    for (k,v) in pd
        out[k] = v
    end
    merge!(recursive_merge, out, pds...)
end

recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
recursive_merge(x::AbstractVector...) = cat(x...; dims=1)
recursive_merge(x...) = x[end]

# fall back to String if we don't clearly have Symbol
_promote_keytypes(@nospecialize(pds::Tuple{Vararg{PointerDict{Symbol, T}}})) where T = Symbol
_promote_keytypes(@nospecialize(pds::Tuple{Vararg{PointerDict}})) = String
_promote_valtypes(V) = V
function _promote_valtypes(V, d, ds...)  # give up if promoted to any
    V === Any ? Any : _promote_valtypes(promote_type(V, valtype(d)), ds...)
end