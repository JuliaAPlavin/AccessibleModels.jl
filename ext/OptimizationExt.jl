module OptimizationExt

using AccessibleModels
using AccessibleModels: transformed_func, transformed_vec, from_transformed, rawdata, transformed_bounds
using Optimization

function Optimization.OptimizationProblem(s::AccessibleModel, args...; kwargs...)
    tf = transformed_func(s)
    OptimizationProblem(OptimizationFunction((args...) -> -tf(args...)), transformed_vec(s), rawdata(s), args...; transformed_bounds(s)..., kwargs...)
end

struct AccessibleSolution
    sol
    amodel
end

Optimization.solve(a::OptimizationProblem, b, s::AccessibleModel; kwargs...) = AccessibleSolution(solve(a, b; kwargs...), s)
AccessibleModels.getobj(sol::AccessibleSolution) = from_transformed(sol.sol.u, sol.amodel)

end
