module PreallocationTools

using ForwardDiff, ArrayInterface, LabelledArrays

struct DiffCache{T<:AbstractArray, S<:AbstractArray}
    du::T
    dual_du::S
end

function DiffCache(u::AbstractArray{T}, siz, ::Type{Val{chunk_size}}) where {T, chunk_size}
    x = ArrayInterface.restructure(u,zeros(ForwardDiff.Dual{nothing,T,chunk_size}, siz...))
    DiffCache(u, x)
end

"""

`dualcache(u::AbstractArray, N = Val{default_cache_size(length(u))})`

Builds a `DualCache` object that stores both a version of the cache for `u`
and for the `Dual` version of `u`, allowing use of pre-cached vectors with
forward-mode automatic differentiation.

"""
dualcache(u::AbstractArray, N=Val{ForwardDiff.pickchunksize(length(u))}) = DiffCache(u, size(u), N)

function get_tmp(dc::DiffCache, u::T) where T<:ForwardDiff.Dual
  x = reinterpret(T, dc.dual_du)
end

function get_tmp(dc::DiffCache, u::AbstractArray{T}) where T<:ForwardDiff.Dual
  x = reinterpret(T, dc.dual_du)
end

function get_tmp(dc::DiffCache, u::LabelledArrays.LArray{T,N,D,Syms}) where {T,N,D,Syms}
  x = reinterpret(T, dc.dual_du.__x)
  LabelledArrays.LArray{T,N,D,Syms}(x)
end

get_tmp(dc::DiffCache, u::Number) = dc.du
get_tmp(dc::DiffCache, u::AbstractArray) = dc.du

"""
    b = LazyBufferCache(f=identity)

A lazily allocated buffer object.  Given a vector `u`, `b[u]` returns a `Vector` of the
same element type and length `f(length(u))` (defaulting to the same length), which is
allocated as needed and then cached within `b` for subsequent usage.
"""
struct LazyBufferCache{F<:Function}
    bufs::Dict # a dictionary mapping types to buffers
    lengthmap::F
    LazyBufferCache(f::F=identity) where {F<:Function} = new{F}(Dict()) # start with empty dict
end

# override the [] method
function Base.getindex(b::LazyBufferCache, u::AbstractArray{T}) where {T}
    n = b.lengthmap(size(u)) # required buffer length
    buf = get!(b.bufs, T) do
        similar(u, T, n) # buffer to allocate if it was not found in b.bufs
    end::typeof(u) # declare type since b.bufs dictionary is untyped
    # Doesn't work well with matrices, needs more thought!
    #return resize!(buf, n) # resize the buffer if needed, e.g. if problem was resized
end

export dualcache, get_tmp, LazyBufferCache

end