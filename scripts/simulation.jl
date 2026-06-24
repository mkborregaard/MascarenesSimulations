# Force remove master environment before activate
# to make sure it works
# deleteat!(Base.LOAD_PATH, 2:3)

using MascarenesSimulations
using DynamicGrids
using GLMakie
using Revise

basepath = MascarenesSimulations.basepath
# Settings

aggfactor = 16
first_year = 1550
last_year = 2018
extant_extension = 0

# Choose predator subset
pred_keys = (:cat, :black_rat, :norway_rat) # (:cat, :black_rat, :norway_rat, :mouse, :pig, :macaque)

# Choose an island
k = :reu
k = :rod
k = :mus

landcover_paths = (
    mus=joinpath(basepath, "data/lc_predictions_mus.nc"),
    reu=joinpath(basepath, "data/lc_predictions_reu.nc"),
    rod=joinpath(basepath, "data/lc_predictions_rod.nc"),
)

# Load data
(; pred_df, introductions_df, island_names, island_endemic_names, island_tables, island_endemic_tables) = load_tables()
(; borders, masks, elevation, dems) = load_rasters()
auxs = load_aux(; masks, dems, landcover_paths, aggfactor, last_year)

# Run full invasive/endemic simulations

# Define rules and outputs
(; ruleset, rules, pred_ruleset, endemic_ruleset, islands) = define_simulations(
    pred_df, 
    introductions_df, 
    island_endemic_tables, 
    auxs, 
    aggfactor; 
    replicates=nothing, 
    first_year, 
    last_year, 
    extant_extension,
    pred_keys,
    pred_pops_aux=map(_ -> nothing, dems),
);
(; output, endemic_output, pred_output, init, output_kw) = islands[k];

# Run
@time sim!(output, ruleset; printframe=true);

# Makie visual simulations
lc_graphic = graphic_landcover(auxs)
mkoutput = makie_sim(init, ruleset; landcover=lc_graphic[k], output_kw..., ncolumns=4)


# If you need to debug performance
# you should get over 20 frames a second for all pred + endemic rules

# using ProfileView
# @profview 1 + 1 # warmup
# sim!(output, ruleset; proc=SingleCPU(), printframe=true, tspan=1550:1551);
# Then profile a single frame
# @profview sim!(output, ruleset; proc=SingleCPU(), printframe=true, tspan=1550:1551);

