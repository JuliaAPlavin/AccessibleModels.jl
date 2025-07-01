module MonteCarloMeasurementsPigeonsExt

using AccessibleModels
using AccessibleModels: from_raw
using MonteCarloMeasurements
using Pigeons

function AccessibleModels.samples(PT::Type{<:AbstractParticles}, pt)
    @assert sample_names(pt)[end] == :log_density
    N = length(pt.inputs.target.prior)
    arrs = map(1:N) do i
        map(x -> x[i], get_sample(pt))
    end
    from_raw(PT.(arrs), pt.inputs.target)
end

end
