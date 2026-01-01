using TestItems
using TestItemRunner
@run_package_tests


@testitem "no-distributions example" begin
    # want to execute this code when Distributions aren't loaded yet, not to trigger the extension
    # see https://github.com/JuliaAPlavin/AccessibleModels.jl/issues/1
    using IntervalSets: (..)
    using Optimization, OptimizationMetaheuristics

    struct ExpFunction{A,B}
        scale::A
        shift::B
    end
    struct SumFunction{T}
        comps::T
    end
    (m::ExpFunction)(x) = m.scale * exp(-(x - m.shift)^2)
    (m::SumFunction)(x) = sum(c -> c(x), m.comps)

    mod0 = SumFunction((
        ExpFunction(1., 1.),
        ExpFunction(2., 2.),
    ))
    amodel = AccessibleModel(Base.Fix2((m, data) -> -abs(m(2) - data), 5), mod0, (
        (@o _.comps[∗].shift) => 0..10,
        (@o _.comps[∗].scale) => 0..4,
    ))

    op = OptimizationProblem(amodel)
    sol = solve(op, ECA(), amodel)
end

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

    # model without any function at all:
    amodel = AccessibleModel(mod0, (
        (@o _.comps[∗].shift) => 0..10,
    ))

    fig = Figure()
    obj, sg = SliderGrid(fig[1,1], amodel)
    obj, sg = SliderGrid(fig[2,1], amodel; width=300)
    @test obj isa Observable
    # @test obj[] == amodel.modelobj


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
        (param="comps[1].shift", value=1.0, prior="Distributions.Uniform{Float64}(a=0.0, b=10.0)"),
        (param="comps[2].shift", value=2.0, prior="Distributions.Uniform{Float64}(a=0.0, b=10.0)"),
        (param="comps[3].shift", value=3.0, prior="Distributions.Uniform{Float64}(a=0.0, b=10.0)"),
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
    # @test obj[] == amodel.modelobj

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

    oldtbl = columntable(amodel)
    newtbl = columntable(@set amodel.modelobj = sp)
    @test newtbl.param == oldtbl.param
    @test newtbl.prior == oldtbl.prior
    @test newtbl.value isa Vector{<:Particles}

    # provide type, not initial value to model:
    amodel = AccessibleModel(Base.Fix2((p, data) -> p.a^2, data), NamedTuple, (
        (@o _.a) => Uniform(0, 10),
    ))
    pt = pigeons(; target=amodel, n_rounds=8, record=[traces; round_trip; record_default()])
    @test sample_names(pt) == [:a, :log_density]
    # smoke test:
    ss = samples(pt)
    sp = samples(Particles, pt)
end

@testitem "P()" begin
    using AccessibleModels: P, Auto
    using IntervalSets

    amodel = AccessibleModel((
        a=P(1..5),
        b=(P([0,1,2,3], 3), P([false, true]))
    ), Auto())

    @test amodel.modelobj === (a=3., b=(3, false))
end

@testitem "slider for discrete distribution" begin
    using Distributions
    using Makie

    amodel = AccessibleModel((a=1, b=2, c=3, d=4, e=5, f=true), (
        (@o _.a) => Uniform(0, 10),
        (@o _.b) => DiscreteUniform(1, 5),
        (@o _.c) => DiscreteNonParametric([1, 2, 5], [0.2, 0.5, 0.3]),
        (@o _.d) => 1:5,
        (@o _.e) => [1,2,5],
        (@o _.f) => [false,true],
    ))
    fig = Figure()
    for val in range(0..10, 55)
        am = @set amodel.modelobj.a = val
        obj, = SliderGrid(fig[1,1], am)
        @test obj[].a ≈ val  atol=1.2*10/300
    end
    for val in 1:5
        am = @set amodel.modelobj.b = val
        obj, = SliderGrid(fig[2,1], am)
        @test obj[].b === val

        am = @set amodel.modelobj.d = val
        obj, = SliderGrid(fig[2,1], am)
        @test obj[].d === val
    end
    for val in [1, 2, 5]
        am = @set amodel.modelobj.c = val
        obj, = SliderGrid(fig[3,1], am)
        @test obj[].c === val

        am = @set amodel.modelobj.e = val
        obj, = SliderGrid(fig[3,1], am)
        @test obj[].e === val
    end
    for val in [false, true]
        am = @set amodel.modelobj.f = val
        obj, = SliderGrid(fig[3,1], am)
        @test obj[].f === val
    end
end

@testitem "slidergrid cache" begin
    using Makie
    using Dictionaries

    @testset for state in [Dict(), Dictionary()]
        amodel = AccessibleModel((a=1, b=0.5), (
            (@o _.a) => 0..10,
            (@o _.b) => -1..1,
        ))
        fig = Figure()

        obj, sls = SliderGrid(fig[1,1], amodel; state)
        @test obj[].a ≈ 1  atol=10/300
        @test obj[].b ≈ 0.5  atol=2/300
        @test isempty(state)

        Makie.set_close_to!(sls[1], 0.6)
        @test obj[].a ≈ 6  atol=10/300
        @test issetequal(keys(state), ["a"])
        @test state["a"] ≈ 6  atol=10/300

        Makie.set_close_to!(sls[1], 0.1)
        @test obj[].a ≈ 1  atol=10/300
        @test issetequal(keys(state), ["a"])
        @test state["a"] ≈ 1  atol=10/300

        obj, sls = SliderGrid(fig[1,1], amodel; state)
        @test obj[].a ≈ 1  atol=10/300
        @test obj[].b ≈ 0.5  atol=2/300
    end
end


@testitem "_" begin
    import Aqua
    Aqua.test_all(AccessibleModels)

    import CompatHelperLocal as CHL
    CHL.@check()
end
