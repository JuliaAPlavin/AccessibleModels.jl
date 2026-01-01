module AccessibleModels

using Reexport
@reexport using AccessorsExtra
using DataPipes
using FlexiMaps: flatmap
import Printf

export AccessibleModel, getobj, samples

struct AccessibleModel{F,M,P,D,PD}
    loglike::F
    modelobj::M
    optics::P
    distributions::D
    prior::PD
end

AccessibleModel(loglike, modelobj, opticspecs) = AccessibleModel(
    loglike,
    modelobj,
    map(first, opticspecs),
    flatmap(opticspecs) do (o, d)
        fill(d, AccessorsExtra.nvals_optic(modelobj, o))
    end |> Tuple,
)
AccessibleModel(loglike, modelobj, optics, distributions) = AccessibleModel(
    loglike,
    modelobj,
    optics,
    distributions,
    _product_distribution(distributions...),
)

function _product_distribution end
function _cdf end
function _quantile end
function _logpdf end

_optic((o, d)::Pair) = o
optic(optics) = AccessorsExtra.ConcatOptics(map(_optic, optics))
from_raw(u, m::AccessibleModel) = AccessorsExtra.setall_or_construct(m.modelobj, AccessorsExtra.ConcatOptics(m.optics), u)
from_transformed(u, m::AccessibleModel) = from_raw(itransform(u, m), m)

transform(u, m::AccessibleModel) =
    map(u, m.distributions) do v, d
        _cdf(d, v)
    end
itransform(u, m::AccessibleModel) =
    map(u, m.distributions) do v, d
        _quantile(d, v)
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

# only for Pigeons: needs to be callable to pass to pigeons() directly
function (m::AccessibleModel)(x)
    prior = _logpdf(m.prior, x)
    prior == -Inf && return prior
    like = m.loglike(from_raw(x, m))
    return prior + like
end

function samples end

end
