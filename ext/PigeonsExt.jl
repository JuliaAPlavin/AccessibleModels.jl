module PigeonsExt

using AccessibleModels
using AccessibleModels: @p
using AccessibleModels: raw_vec, from_raw
using Pigeons
using Pigeons.Random

Pigeons.default_reference(m::AccessibleModel) =
    isnothing(m.prior) ? error("No prior specified for model") :
                         Pigeons.DistributionLogPotential(m.prior)

Pigeons.initialization(m::AccessibleModel, ::AbstractRNG, ::Int) = collect(raw_vec(m))

function AccessibleModels.samples(pt)
    @assert sample_names(pt)[end] == :log_density
    map(x -> from_raw(x[begin:end-1], pt.inputs.target), get_sample(pt))
end

# Pigeons.sample_names(_::Array, m::AccessibleModel) = flatmap(m.optics) do o
#     basename = @p let
# 		AccessorsExtra.flat_concatoptic(m.modelobj, o)
# 		AccessorsExtra._optics
# 		map(AccessorsExtra.barebones_string)
#     end
# end |> collect

end
