module IntervalSetsExt

using AccessibleModels
using IntervalSets

AccessibleModels.uniform(x::AbstractInterval) = AccessibleModels.Uniform(endpoints(x)...)

end
