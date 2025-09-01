module DistributionsExt

using AccessibleModels
using Distributions

AccessibleModels._product_distribution(distributions...) = product_distribution(map(_to_distribution, distributions)...)
AccessibleModels._cdf(d::UnivariateDistribution, x) = cdf(d, x)
AccessibleModels._quantile(d::UnivariateDistribution, p) = quantile(d, p)
AccessibleModels._logpdf(d, x) = logpdf(d, x)

_to_distribution(d::Distribution) = d
_to_distribution(d) = Uniform(extrema(d)...)  # XXX: for intervals only, should create DistributionsIntervalsExt?

end
