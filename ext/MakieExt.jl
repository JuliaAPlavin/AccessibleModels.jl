module MakieExt

using AccessibleModels
using AccessibleModels: from_transformed, transformed_vec
using AccessibleModels.Printf
using AccessibleModels: @p, flatmap
using Makie

"""
    SliderGrid(pos, m::AccessibleModel; fmt=ff"{:.3f}", title, kwargs...)

Create interactive Makie sliders for model parameters with real-time object updates.
"""
function Makie.SliderGrid(pos, m::AccessibleModel; title="$(nameof(typeof(m.modelobj))):", fmt=x -> @sprintf("%.3f", x), rowgap=nothing, kwargs...)
    result = Observable{Any}(m.modelobj)
    tvec = transformed_vec(m)
    i_tvec = 0
	sliders = flatmap(enumerate(m.optics)) do (i, o)
        curvals = liftT(result -> getall(result, o), Any, result)

        labels = @p let
            AccessorsExtra.flat_concatoptic(m.modelobj, o)
            AccessorsExtra._optics
            map(AccessorsExtra.barebones_string)
        end

        map(enumerate(labels)) do (j, label)
            Label(pos[i,1][j,1], label)
            Label(pos[i,1][j,3], @lift fmt($curvals[j]))
            i_tvec += 1
            sl = Slider(pos[i,1][j,2]; range=range(0,1; length=300), startvalue=tvec[i_tvec], kwargs...)
        end
	end
	Label(pos[0,:], title, tellwidth=false)
    if !isnothing(rowgap)
        rowgap!(pos, rowgap)
    end

	slidervals = lift(tuple, map(s -> s.value, sliders)...)
    map!(result, slidervals) do vals
	    from_transformed(vals, m)
    end
    return result, sliders
end


# copied from MakieExtra.jl:
function liftT(f::Function, T::Type, args...)
    res = Observable{T}(f(to_value.(args)...))
    map!(f, res, args...)
    return res
end

end
