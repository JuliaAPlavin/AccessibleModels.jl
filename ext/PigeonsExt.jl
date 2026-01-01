module PigeonsExt

using AccessibleModels
using AccessibleModels: @p, flatmap
using AccessibleModels: raw_vec, from_raw
using Pigeons
using Pigeons.Random

Pigeons.default_reference(m::AccessibleModel) =
    isnothing(m.prior) ? error("No prior specified for model") :
                         Pigeons.DistributionLogPotential(m.prior)

Pigeons.initialization(m::AccessibleModel, ::AbstractRNG, ::Int) =
	m.modelobj isa Type ? collect(map(Pigeons.mean, m.distributions)) :
		 				  collect(raw_vec(m))

function AccessibleModels.samples(pt)
    @assert last(sample_names(pt)) == :log_density
    map(x -> from_raw(x[begin:end-1], pt.inputs.target), get_sample(pt))
end

Pigeons.sample_names(x::Array, p::Pigeons.InterpolatedLogPotential) = [sample_names(x, p.path.target); :log_density]

Pigeons.sample_names(::Array, m::AccessibleModel) = flatmap(m.optics) do o
    @p let
		AccessorsExtra.flat_concatoptic(m.modelobj, o)
		AccessorsExtra._optics
		map(Symbol ∘ AccessorsExtra.barebones_string)
    end
end |> collect

end
