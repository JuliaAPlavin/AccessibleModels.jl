module AccessibleModels

using Reexport
@reexport using AccessorsExtra
using DataManipulation
using Distributions

export AccessibleModel, getobj

struct AccessibleModel{F,M,P,D}
    loglike::F
    modelobj::M
    optics::P
    distributions::D
end

AccessibleModel(loglike, modelobj, opticspecs) = AccessibleModel(
    loglike,
    modelobj,
    map(first, opticspecs),
    flatmap(opticspecs) do (o, d)
        fill(_distribution(d), AccessorsExtra.nvals_optic(modelobj, o))
    end |> Tuple,
)

_distribution(d::UnivariateDistribution) = d
_optic((o, d)::Pair) = o
optic(optics) = AccessorsExtra.ConcatOptics(map(_optic, optics))
from_raw(u, m::AccessibleModel) = AccessorsExtra.setall_or_construct(m.modelobj, AccessorsExtra.ConcatOptics(m.optics), u)
from_transformed(u, m::AccessibleModel) = from_raw(itransform(u, m), m)

transform(u, m::AccessibleModel) = map(u, m.distributions) do v, d
    cdf(d, v)
end
itransform(u, m::AccessibleModel) = map(u, m.distributions) do v, d
    quantile(d, v)
end

transformed_func(m::AccessibleModel) = (u, p) -> (m.loglike::Base.Fix2).f(from_transformed(u, m), p)
raw_vec(m::AccessibleModel) = getall(m.modelobj, AccessorsExtra.ConcatOptics(m.optics))
transformed_vec(m::AccessibleModel) = transform(raw_vec(m), m)
rawdata(m::AccessibleModel) = (m.loglike::Base.Fix2).x
transformed_bounds(m::AccessibleModel) = @p let
    m.distributions
    (lb=zeros(length(__)), ub=ones(length(__)))
end

function getobj end

end
