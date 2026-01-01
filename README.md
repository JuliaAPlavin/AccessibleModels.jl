# AccessibleModels.jl

# Usage

Define your model object – an arbitrary struct (no dependency on AccessibleModels needed):
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
This model describes a smooth function, sum of squared exponents:
```julia
julia> mod0 = SumFunction((
           ExpFunction(1., 1.),
           ExpFunction(2., 2.),
       ))

julia> lines(0..5, x -> mod0(x))
```
<img width="600" alt="figure1_initial_model" src="https://github.com/user-attachments/assets/2b3e4409-aa7c-4172-ab2e-54e8f7da91bd" />


## Quick UI

And use AccessibleModels.jl to create a Makie UI to adjust their parameters:
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

julia> obj, = SliderGrid(amodel)

julia> lines(0..10, @lift x -> $obj(x))
```

https://github.com/user-attachments/assets/cb4e1176-eac3-4899-b78b-35dbdece5c6f



## Optimization

The same AccessibleModel, just add the loss function.

No need to think about vectors, deconstruct/reconstruct objects manually.
Works with any objects, no magic nor special annotations

```julia
# generate some example data using a "true" model
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

# the only change: pass loglikelihood function
julia> amodel = AccessibleModel(Base.Fix2(loglike, data), mod0, (
           (@o _.comps[∗].shift) => 0..10,
           (@o _.comps[∗].scale) => 0..4,
       ))

julia> using Optimization, OptimizationMetaheuristics

julia> op = OptimizationProblem(amodel)

julia> sol = solve(op, ECA(), amodel)

# get the fitted model - values are close to the true model above:
julia> getobj(sol)
SumFunction((
    ExpFunction(1.983, 3.098),
    ExpFunction(1.574, 7.013)))
```
<img width="600" alt="figure2_optimization_results" src="https://github.com/user-attachments/assets/b711187e-7c15-413a-bee5-15fba33c93c4" />

# MCMC fitting

The exact same AccessibleModel as in the optimization example above. Alternatively, one can specify priors with Distributions.jl distributions instead of intervals.

```julia
julia> using Pigeons

julia> pt = pigeons(target=amodel, record=[traces; round_trip; record_default()])

julia> samples(pt)  # Returns vector of SumFunction objects with sampled parameters
256-element Vector{SumFunction}:
 SumFunction((ExpFunction(1.5, 6.96), ExpFunction(2.05, 2.93)))
 SumFunction((ExpFunction(1.46, 7.04), ExpFunction(2.42, 2.91)))
 SumFunction((ExpFunction(1.43, 6.94), ExpFunction(1.93, 3.17)))
 ⋮
```

Integration w/ MonteCarloMeasurements:
```julia
julia> using MonteCarloMeasurements

# Returns SumFunction with Particles for parameters
# Each parameter becomes a Particles object with uncertainty estimates
julia> mcmc_fitted = samples(Particles, pt)
SumFunction((ExpFunction(1.5 ± 0.5, 5.35 ± 2.0), ExpFunction(1.6 ± 0.6, 4.66 ± 2.0)))
```

Thanks to Julia composability, this model can also be plotted directly with Makie:
```julia
julia> lines!(0..10, x -> mcmc_fitted(x))
julia> band(0..10, x -> mcmc_fitted(x))
```
<img width="600" alt="figure3_mcmc_uncertainty" src="https://github.com/user-attachments/assets/a6dcaf17-86db-4571-91da-f8f01f8487c7" />


```
