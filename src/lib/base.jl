using Base: @get!

@nograd readline

# Gradient of AD stacks

grad_mut(::AbstractVector) = []

@adjoint! function _push!(a::Vector, x)
  _push!(a, x), function (y)
    dstk = grad_mut(__context__, a)
    return (nothing, pop!(dstk))
  end
end

@adjoint! function pop!(stk::Stack)
  pop!(stk), function (Δ)
    dstk = grad_mut(__context__, stk.data)
    push!(dstk, Δ)
    return
  end
end

# Dictionaries

grad_mut(d::AbstractDict) = Dict()

# TODO perhaps look up mutable gradients in `forward`
function accum(a::AbstractDict, b::AbstractDict)
  @assert a === b
  return a
end

@adjoint function getindex(d::AbstractDict, k)
  d[k], function (Δ)
    grad = grad_mut(__context__, d)
    grad[k] = accum(get(grad, k, nothing), Δ)
    return (grad, nothing)
  end
end

@adjoint! function setindex!(d::AbstractDict, v, k)
  setindex!(d, v, k), function (_)
    Δ = get(grad_mut(__context__, d), k, nothing)
    delete!(grad_mut(__context__, d), k)
    (nothing, Δ, nothing)
  end
end

# Channels

@nograd Channel

grad_mut(ch::Channel) = Channel(ch.sz_max)

@adjoint! function put!(ch::Channel, x)
  put!(ch, x), function (ȳ)
    x̄ = take!(grad_mut(__context__, ch))
    (nothing, accum(x̄, ȳ), nothing)
  end
end

@adjoint! function take!(ch::Channel)
  take!(ch), function (x̄)
    put!(grad_mut(__context__, ch), x̄)
    return
  end
end
