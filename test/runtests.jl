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
    using Tables


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
        ExpFunction(1.5, 2f0),
        ExpFunction(2., 3),
    ))


    # model with intervals, no distributions:
    amodel = AccessibleModel(Base.Fix2(loglike, data), mod0, (
        (@o _.comps[∗].shift) => 0..10,
    ))

    vec0 = @inferred AccessibleModels.raw_vec(amodel)
    @test eltype(vec0) == Float64
    @test (@inferred AccessibleModels.from_raw(vec0, amodel)) == SumFunction((
        ExpFunction(1., 1.),
        ExpFunction(1.5, 2.),
        ExpFunction(2., 3.),
    ))
    @test (@inferred AccessibleModels.from_raw(collect(vec0), amodel)) == SumFunction((
        ExpFunction(1., 1.),
        ExpFunction(1.5, 2.),
        ExpFunction(2., 3.),
    ))
    
    @test rowtable(amodel)::Vector{@NamedTuple{param::String, value::Float64, prior::String}} == [
        (param="comps[1].shift", value=1.0, prior="0 .. 10"),
        (param="comps[2].shift", value=2.0, prior="0 .. 10"),
        (param="comps[3].shift", value=3.0, prior="0 .. 10"),
    ]
    @test AccessibleModels.from_table(reverse(rowtable(amodel)), amodel) == SumFunction((
        ExpFunction(1., 1.),
        ExpFunction(1.5, 2.),
        ExpFunction(2., 3.),
    ))
    @test AccessibleModels.from_table([
        (param="comps[2].shift", value=20),
        (param="comps[1].shift", value=10),
        (param="comps[3].shift", value=30),
    ], amodel) == SumFunction((
        ExpFunction(1., 10),
        ExpFunction(1.5, 20),
        ExpFunction(2., 30),
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

    # just a smoke test:
    pigeons(; target=amodel, n_rounds=8, record=[traces; round_trip; record_default()])

    # model with distributions:
    amodel = AccessibleModel(Base.Fix2(loglike, data), mod0, (
        (@o _.comps[∗].shift) => Uniform(0, 10),
    ))
    
    @test rowtable(amodel) == [
        (param="comps[1].shift", value=1, prior="Distributions.Uniform{Float64}(a=0.0, b=10.0)"),
        (param="comps[2].shift", value=2, prior="Distributions.Uniform{Float64}(a=0.0, b=10.0)"),
        (param="comps[3].shift", value=3, prior="Distributions.Uniform{Float64}(a=0.0, b=10.0)"),
    ]

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
    @test sample_names(pt) == [Symbol("comps[1].shift"), Symbol("comps[2].shift"), Symbol("comps[3].shift"), :log_density]
    ss = samples(pt)
    @test length(ss) == 2^8
    @test ss isa AbstractVector{<:SumFunction}
    @test 0 ≤ ss[1].comps[1].shift ≤ 10

    sp = samples(Particles, pt)
    @test sp isa SumFunction
    @test sp.comps[1].shift isa Particles
    @test 0 ≤ sp.comps[1].shift ≤ 10
end


@testitem "_" begin
    import Aqua
    Aqua.test_all(AccessibleModels)

    import CompatHelperLocal as CHL
    CHL.@check()
end
