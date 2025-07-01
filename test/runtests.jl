using TestItems
using TestItemRunner
@run_package_tests


@testitem "basic usage" begin
    using StructArrays
    using Distributions
    using Optimization, OptimizationMetaheuristics
    using Pigeons


    struct ExpFunction{A,B}
        scale::A
        shift::B
    end
    
    struct SumFunction{T <: Tuple}
        comps::T
    end
    
    (m::ExpFunction)(x) = m.scale * exp(-(x - m.shift)^2)
    (m::SumFunction)(x) = sum(c -> c(x), m.comps)

    loglike(m::SumFunction, data) = sum(r -> pdf(Normal(m(r.x), 1), r.y), data)

    truemod = SumFunction((
        ExpFunction(2, 5),
        ExpFunction(0.5, 2),
        ExpFunction(0.5, 8),
    ))

    data = let x = 0:0.2:10
        StructArray(; x, y=truemod.(x) .+ range(-0.01, 0.01, length=length(x)))
    end
    
    mod0 = SumFunction((
        ExpFunction(1., 1.),
        ExpFunction(1., 2.),
        ExpFunction(1., 3.),
    ))
    amodel = AccessibleModel(Base.Fix2(loglike, data), mod0, (
        (@o _.comps[∗].shift) => Uniform(0, 10),
    ))

    op = OptimizationProblem(amodel)
    sol = solve(op, ECA(), amodel)
    @test length(sol.sol.u::Vector) == 3
    @test getobj(sol) isa SumFunction

    
    # pt = pigeons(; target=amodel, kwargs...)
end


# @testitem "_" begin
#     import Aqua
#     Aqua.test_all(AccessibleModels)

#     import CompatHelperLocal as CHL
#     CHL.@check()
# end
