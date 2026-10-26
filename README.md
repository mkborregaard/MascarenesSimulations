# Simulations of mascarene species extinction

To run: 

1. Clone the repository 
2. Get the landcover change data for the period (will be available online eventually)
3. Run julia (1.11 or later) in the project repository, then `activate` and `instantiate` the project
4. Run the script in `scripts/simulation.jl`

## Dependencies

DynamicGrids, Dispersal and LandscapeChange come from forks at
[mkborregaard/DynamicGrids.jl](https://github.com/mkborregaard/DynamicGrids.jl),
[mkborregaard/Dispersal.jl](https://github.com/mkborregaard/Dispersal.jl) and
[mkborregaard/LandscapeChange.jl](https://github.com/mkborregaard/LandscapeChange.jl)
(the `maintained` branch, set in `[sources]` in `Project.toml`). Each fork merges
its upstream branch weekly. `Pkg.update()` picks up the newest commits, and CI
checks the tests against them every week.

