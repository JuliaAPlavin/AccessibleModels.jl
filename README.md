# AccessibleModels.jl

**Fit, optimize, and interactively explore models that are arbitrary Julia objects.**

AccessibleModels.jl is a thin layer that connects [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) with popular Julia packages for model fitting, optimization, and visualization:

- **Universal model fitting**: Optimize/fit a model with parameters being any Julia object
- **Wide ecosystem integration**: Works seamlessly with optimization packages (Optimization.jl), Bayesian MCMC sampling (Pigeons.jl), and more
- **Interactive UIs**: Create quick parameter manipulation interfaces with Makie.jl
- **Zero boilerplate**: Just define what your model parameters are, no need to write custom extraction or reconstruction code
- **Flexible**: Model structure and parameter definitions are decoupled, facilitating rapid exploration

## Usage

Define your model object as an arbitrary struct (no dependency on AccessibleModels needed):
```julia
julia> struct ExpFunction{A,B}
           scale::A
           shift::B
       end

julia> struct SumFunction{T}
           comps::T
       end

julia> (m::ExpFunction)(x) = m.scale * exp(-(x - m.shift)^2)

julia> (m::SumFunction)(x) = sum(c -> c(x), m.comps)
```

This model describes a smooth function, sum of exponentials:
```julia
julia> mod0 = SumFunction((
           ExpFunction(1., 1.),
           ExpFunction(2., 2.),
       ))

julia> lines(0..5, x -> mod0(x))
```
<img width="600" alt="figure1_initial_model" src="https://github.com/user-attachments/assets/b4f8ad9f-3c8a-4df4-93da-7e58fb83ec9a" />


## Quick Interactive UI

Use AccessibleModels.jl to create an interactive Makie UI for adjusting model parameters:
```julia
julia> using AccessibleModels, IntervalSets
julia> using GLMakie

julia> mod0 = SumFunction((
           ExpFunction(1., 1.),
           ExpFunction(2., 2.),
       ))

julia> amodel = AccessibleModel(mod0, (
           (@o _.comps[∗].shift) => 0..10,
           (@o _.comps[∗].scale) => 0..4,
       ))

julia> obj, = SliderGrid(fig[1,1], amodel)

julia> lines(fig[1,2], 0..10, @lift x -> $obj(x))
```

https://github.com/user-attachments/assets/bb0aaa03-e9da-4e04-88ce-d69265db8228

### Parameter Specification

The `@o` macro and its syntax come from [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl).

The intuition that should cover the vast majority of scenarios is "just write how you would access the target location normally, replace your object with `_`, and write `@o` in front". For example:
- want to modify `yourobj.a`? write `@o _.a`
- `yourobj[1]` ⇒ `@o _[1]`
- `last(yourobj.a)` ⇒ `@o last(_.a)`

and so on.

See the [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) docs (and [AccessorsExtra.jl](https://github.com/JuliaAPlavin/AccessorsExtra.jl) with more advanced features) for details and more examples.


## Optimization

Use the same AccessibleModel for optimization – just add a loss function.

Key features:
- Optimize any Julia struct directly 🎯
- Works with any Optimization.jl backend 🌐
- Zero boilerplate, No manual parameter extraction/reconstruction code ✨

```julia
# Generate example data using a "true" model
julia> true_model = SumFunction((
           ExpFunction(2.0, 3.0),
           ExpFunction(1.5, 7.0),
       ))
julia> data = [(x=x, y=true_model(x) + 0.2 * randn()) for x in 0:0.5:10]
21-element Vector{@NamedTuple{x::Float64, y::Float64}}:
 (x = 0.0, y = 0.158)
 (x = 0.5, y = -0.172)
 (x = 1.0, y = -0.138)
 <...>

julia> loglike(m::SumFunction, data) = sum(r -> logpdf(Normal(m(r.x), 0.3), r.y), data)

# The only change: add the log-likelihood function
julia> amodel = AccessibleModel(Base.Fix2(loglike, data), mod0, (
           (@o _.comps[∗].shift) => 0..10,
           (@o _.comps[∗].scale) => 0..4,
       ))

julia> using Optimization, OptimizationMetaheuristics

julia> op = OptimizationProblem(amodel)

julia> sol = solve(op, ECA(), amodel)

# Get the fitted model (values are close to the true model above):
julia> getobj(sol)
SumFunction((
    ExpFunction(1.983, 3.098),
    ExpFunction(1.574, 7.013)))
```
<img width="600" alt="figure2_optimization_results" src="https://github.com/user-attachments/assets/9f8ee461-0e70-4da9-9df3-8e56fcb7328e" />

## MCMC Sampling

Use the exact same AccessibleModel as in the optimization example above.
Alternatively, you can specify priors using Distributions.jl distributions instead of intervals (intervals are assumed uniform priors).

```julia
julia> using Pigeons

julia> pt = pigeons(target=amodel, record=[traces; round_trip; record_default()])

julia> samples(pt)  # Returns a vector of SumFunction objects with sampled parameters
256-element Vector{SumFunction}:
 SumFunction((ExpFunction(1.5, 6.96), ExpFunction(2.05, 2.93)))
 SumFunction((ExpFunction(1.46, 7.04), ExpFunction(2.42, 2.91)))
 SumFunction((ExpFunction(1.43, 6.94), ExpFunction(1.93, 3.17)))
 ⋮
```

Integration with MonteCarloMeasurements:
```julia
julia> using MonteCarloMeasurements

# Returns a SumFunction with Particles for parameters
# Each parameter becomes a Particles object with uncertainty estimates
julia> mcmc_fitted = samples(Particles, pt)
SumFunction((ExpFunction(1.5 ± 0.5, 5.35 ± 2.0), ExpFunction(1.6 ± 0.6, 4.66 ± 2.0)))
```

Thanks to Julia's composability, this model can be plotted directly with Makie:
```julia
julia> lines!(0..10, x -> mcmc_fitted(x))
julia> band(0..10, x -> mcmc_fitted(x))
```
<img width="600" alt="figure3_mcmc_uncertainty" src="https://github.com/user-attachments/assets/7750664d-86a2-4e61-b8cc-56d5677743e3" />
