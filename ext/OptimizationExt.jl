module OptimizationExt

using AccessibleModels
using AccessibleModels: transformed_func, transformed_vec, from_transformed, rawdata, transformed_bounds
using Optimization

Optimization.OptimizationProblem(s::AccessibleModel, args...; kwargs...) =
    OptimizationProblem(OptimizationFunction(transformed_func(s)), transformed_vec(s), rawdata(s), args...; transformed_bounds(s)..., kwargs...)

struct MySolution
    sol
    amodel
end

Optimization.solve(a::OptimizationProblem, b, s::AccessibleModel; kwargs...) = MySolution(solve(a, b; kwargs...), s)
AccessibleModels.getobj(sol::MySolution) = from_transformed(sol.sol.u, sol.amodel)

end
