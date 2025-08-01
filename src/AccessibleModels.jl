module AccessibleModels

using Reexport
@reexport using AccessorsExtra
using DataPipes
using FlexiMaps: flatmap
import Printf

export AccessibleModel, getobj, samples

"""
    AccessibleModel(loglike, modelobj, opticspecs)

A model wrapper that provides accessible parameter manipulation through optics.

# Arguments
- `loglike`: Log-likelihood function
- `modelobj`: Model object to wrap
- `opticspecs`: Pairs of optics and distributions or intervals for parameters

# Fields
- `loglike`: Log-likelihood function
- `modelobj`: The underlying model object
- `optics`: Optics for parameter access
- `distributions`: Parameter distributions or intervals
- `prior`: Prior distribution
"""
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

"""
    from_raw(u, m::AccessibleModel)

Convert raw parameter vector to model object.
"""
from_raw(u, m::AccessibleModel) = AccessorsExtra.setall_or_construct(m.modelobj, AccessorsExtra.ConcatOptics(m.optics), u)

# doesn't seem needed, but seemed to help inference in some cases:
from_raw(u::Vector, m::AccessibleModel{<:Any,<:Any,<:Any,<:NTuple{N}}) where {N} = AccessibleModels.from_raw(NTuple{N,eltype(u)}(u), m)


"""
    from_transformed(u, m::AccessibleModel)

Convert transformed (to 0..1) parameter vector to model object.
"""
from_transformed(u, m::AccessibleModel) = from_raw(itransform(u, m), m)

"""
    transform(u, m::AccessibleModel)

Transform raw parameters to 0..1 space using distribution CDFs or interval bounds.
"""
transform(u, m::AccessibleModel) =
    map(u, m.distributions) do v, d
        _cdf(d, v)
    end

"""
    itransform(u, m::AccessibleModel)

Inverse transform from 0..1 space to raw parameters using distribution quantiles or interval bounds.
"""
itransform(u, m::AccessibleModel) =
    map(u, m.distributions) do v, d
        _quantile(d, v)
    end

"""
    transformed_func(m::AccessibleModel)

Get log-likelihood function that takes transformed parameters (in 0..1 space).
"""
transformed_func(m::AccessibleModel) = (u, p) -> (m.loglike::Base.Fix2).f(from_transformed(u, m), p)

"""
    raw_vec(m::AccessibleModel)

Extract raw parameter vector from model object.
"""
raw_vec(m::AccessibleModel) = promote(getall(m.modelobj, AccessorsExtra.ConcatOptics(m.optics))...)

"""
    transformed_vec(m::AccessibleModel)

Get the parameter vector in transformed 0..1 space.
"""
transformed_vec(m::AccessibleModel) = transform(raw_vec(m), m)

"""
    rawdata(m::AccessibleModel)

Extract the data from the log-likelihood function.
"""
rawdata(m::AccessibleModel) = (m.loglike::Base.Fix2).x

"""
    transformed_bounds(m::AccessibleModel)

Get parameter bounds in transformed space (always 0..1). Returns a tuple of lower and upper bounds, format suitable for Optimization.jl.
"""
transformed_bounds(m::AccessibleModel) = @p let
    m.distributions
    (lb=zeros(length(__)), ub=ones(length(__)))
end

"""
    getobj(sol)

Extract the model object from an optimization solution.
"""
function getobj end

# only for Pigeons: needs to be callable to pass to pigeons() directly
"""
    (m::AccessibleModel)(x)

Compute log-posterior: log-prior + log-likelihood.
"""
function (m::AccessibleModel)(x)
    prior = _logpdf(m.prior, x)
    prior == -Inf && return prior
    like = m.loglike(from_raw(x, m))
    return prior + like
end

"""
    samples(pt)

Extract MCMC samples from Pigeons sampling results as vector of model objects.

    samples(Particles, pt)

Extract MCMC samples as single object with MonteCarloMeasurements.Particles for parameters.
"""
function samples end

"""
    from_table(tbl, m::AccessibleModel)

Return the model object reconstructed from a table of parameters.
Such a table can be obtained as `rowtable(m)`, or saved/loaded with any Tables.jl-compatible package.
"""
from_table(tbl, m) = error("load Tables.jl to use from_table")

end
