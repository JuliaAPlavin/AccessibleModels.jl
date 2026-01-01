using TestItems
using TestItemRunner
@run_package_tests


@testitem "basic usage" begin
    using StructArrays
    using Distributions
    using Optimization, OptimizationMetaheuristics
    using Pigeons
    using MonteCarloMeasurements
    using Makie
    using Makie.IntervalSets: (..)


    struct ExpFunction{A,B}
        scale::A
        shift::B
    end
    
    struct SumFunction{T <: Tuple}
        comps::T
    end
    
    (m::ExpFunction)(x) = m.scale * exp(-(x - m.shift)^2)
    (m::SumFunction)(x) = sum(c -> c(x), m.comps)

    loglike(m::SumFunction, data) = sum(r -> logpdf(Normal(m(r.x), 1), r.y), data)

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


    # model with intervals, no distributions:
    amodel = AccessibleModel(Base.Fix2(loglike, data), mod0, (
        (@o _.comps[∗].shift) => 0..10,
    ))

    fig = Figure()
    obj, sg = SliderGrid(fig[1,1], amodel)
    obj, sg = SliderGrid(fig[2,1], amodel; width=300)
    @test obj isa Observable
    @test obj[] isa SumFunction

    op = OptimizationProblem(amodel)
    sol = solve(op, ECA(), amodel)
    sol = solve(op, ECA(), amodel; maxiters=100)
    @test length(sol.sol.u::Vector) == 3
    @test getobj(sol) isa SumFunction

    @test_throws "No prior" pigeons(; target=amodel, n_rounds=8, record=[traces; round_trip; record_default()])


    # model with distributions:
    amodel = AccessibleModel(Base.Fix2(loglike, data), mod0, (
        (@o _.comps[∗].shift) => Uniform(0, 10),
    ))

    fig = Figure()
    obj, sg = SliderGrid(fig[1,1], amodel)
    obj, sg = SliderGrid(fig[2,1], amodel; width=300)
    @test obj isa Observable
    @test obj[] isa SumFunction

    op = OptimizationProblem(amodel)
    sol = solve(op, ECA(), amodel)
    sol = solve(op, ECA(), amodel; maxiters=100)
    @test length(sol.sol.u::Vector) == 3
    @test getobj(sol) isa SumFunction

    pt = pigeons(; target=amodel, n_rounds=8, record=[traces; round_trip; record_default()])
    # @test sample_names(pt)
    ss = samples(pt)
    @test length(ss) == 2^8
    @test ss isa AbstractVector{<:SumFunction}
    @test 0 ≤ ss[1].comps[1].shift ≤ 10

    sp = samples(Particles, pt)
    @test sp isa SumFunction
    @test sp.comps[1].shift isa Particles
    @test 0 ≤ sp.comps[1].shift ≤ 10
end


# @testitem "_" begin
#     import Aqua
#     Aqua.test_all(AccessibleModels)

#     import CompatHelperLocal as CHL
#     CHL.@check()
# end
