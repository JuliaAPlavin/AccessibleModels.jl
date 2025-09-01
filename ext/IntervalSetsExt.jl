module IntervalSetsExt

using AccessibleModels
using IntervalSets

# For intervals, transform to [0,1] using uniform distribution over the interval
AccessibleModels._cdf(interval::AbstractInterval, x) = clamp((x - leftendpoint(interval)) / width(interval), 0, 1)
AccessibleModels._quantile(interval::AbstractInterval, p) = leftendpoint(interval) + p * width(interval)

end
