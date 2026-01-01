module MakieExt

using AccessibleModels
using AccessibleModels.Distributions
using AccessibleModels: from_transformed, transformed_vec
using AccessibleModels.Printf
using AccessibleModels: @p, flatmap
using Makie

"""
    SliderGrid(pos, m::AccessibleModel; fmt, title, state, kwargs...)

Create interactive Makie sliders for model parameters with real-time object updates.

If `state::Dict` is provided, slider values are stored in the given dictionary keyed by
parameter labels (the same text shown next to sliders).
"""
function Makie.SliderGrid(pos, m::AccessibleModel; title="$(nameof(typeof(m.modelobj))):", fmt=x -> @sprintf("%.3f", x), rowgap=nothing, state=nothing, kwargs...)
    result = Observable{Any}(m.modelobj)
    tvec = transformed_vec(m)
    i_tvec = 0
    labelkeys = String[]
    sliders = flatmap(enumerate(m.optics)) do (i, o)
        curvals = liftT(result -> getall(result, o), Any, result)

        labels = @p let
            AccessorsExtra.flat_concatoptic(m.modelobj, o)
            AccessorsExtra._optics
            map(AccessorsExtra.barebones_string)
        end

        map(enumerate(labels)) do (j, label)
            i_tvec += 1
            Label(pos[i_tvec,1], label; halign=:left)
            Label(pos[i_tvec,3], lift(curvals -> dofmt(fmt, curvals[j]), curvals), halign=:right)
            push!(labelkeys, label)
            dist = m.distributions[i_tvec]
            sliderrange = auto_slider_range(dist)

            startvalue = tvec[i_tvec]
            if !isnothing(state) && haskey(state, label)
                startvalue = cdf(dist, state[label])
            end
            Slider(pos[i_tvec,2]; range=sliderrange, startvalue, kwargs...)
        end
    end
    Label(pos[0,:], title, tellwidth=false)
    if !isnothing(rowgap)
        rowgap!(pos, rowgap)
    end

    map!(result, map(s -> s.value, sliders)...) do vals...
        from_transformed(vals, m)
    end
    if !isnothing(state)
        for (dist, sl, label) in zip(m.distributions, sliders, labelkeys)
            on(sl.value) do v
                rawval = quantile(dist, v)
                _insert!(state, label, rawval)
            end
        end
    end
    return result, sliders
end

auto_slider_range(_) = range(0,1; length=300)
auto_slider_range(d::DiscreteUnivariateDistribution) = @p support(d) map(cdf(d, _)) map(clamp(_ - √(eps(_)), 0,1))


dofmt(fmt::Function, x::Integer) = string(x)
dofmt(fmt::Function, x::Real) = fmt(x)


# copied from MakieExtra.jl:
function liftT(f::Function, T::Type, args...)
    res = Observable{T}(f(to_value.(args)...))
    map!(f, res, args...)
    return res
end


_insert!(dict::AbstractDict, key, value) = dict[key] = value
_insert!(dict, key, value) = insert!(dict, key, value)  # for Dictionaries

end
