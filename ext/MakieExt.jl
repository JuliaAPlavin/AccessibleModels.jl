module MakieExt

using AccessibleModels
using AccessibleModels: from_transformed, transformed_vec
using AccessibleModels.Printf
using AccessibleModels: flatmap
using Makie

"""
    SliderGrid(pos, m::AccessibleModel; fmt=ff"{:.3f}", kwargs...)

Create interactive Makie sliders for model parameters with real-time object updates.
"""
function Makie.SliderGrid(pos, m::AccessibleModel; fmt=x -> @sprintf("%.3f", x), kwargs...)
    result = Observable{Any}(m.modelobj)
    tvec = transformed_vec(m)
    i_tvec = 0
	sliders = flatmap(enumerate(m.optics)) do (i, o)
        curvals = @lift getall($result, o)
        N = AccessorsExtra.nvals_optic(m.modelobj, o)
        map(1:N) do j
            Label(pos[i,1][j,1], "$(AccessorsExtra.barebones_string(o)) #$j")
            Label(pos[i,1][j,3], @lift fmt($curvals[j]))
            i_tvec += 1
            sl = Slider(pos[i,1][j,2]; range=range(0,1; length=300), startvalue=tvec[i_tvec], kwargs...)
        end
	end
	Label(pos[0,:], "$(nameof(typeof(m.modelobj))):", tellwidth=false)
	slidervals = lift(tuple, map(s -> s.value, sliders)...)
    map!(result, slidervals) do vals
	    from_transformed(vals, m)
    end
    return result, sliders
end

end
