module DistributionsExt

using AccessibleModels
using Distributions

# Distribution-related methods
AccessibleModels._product_distribution(distributions...) = product_distribution(distributions...)
AccessibleModels._cdf(d::UnivariateDistribution, x) = cdf(d, x)
AccessibleModels._quantile(d::UnivariateDistribution, p) = quantile(d, p)
AccessibleModels._logpdf(d, x) = logpdf(d, x)

end
