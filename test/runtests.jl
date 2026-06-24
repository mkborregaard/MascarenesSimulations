using Test
using MascarenesSimulations
using MascarenesSimulations: lc_categories, define_simulations, load_tables
using DynamicGrids
using Rasters
using DimensionalData
import LandscapeChange: NamedVector

# ---------------------------------------------------------------------------
# Smoke test: run the full coupled ruleset on a tiny synthetic island.
#
# What this covers:
#   InteractiveCarryCap  – carrying-capacity update from landcover
#   introduction_rule    – point-source predator introductions
#   pred_spread_rule     – stochastic dispersal kernel
#   LogisticGrowth       – predator population growth
#   ExtirpationRisks     – endemic extinction + recolonisation (tuple version)
#   clearing_rule        – habitat-loss extirpation
#
# The 7×7 grid is large enough for the Moore{3} stencil (radius 3 → 7 cells
# minimum) and covers the Mauritius black-rat introduction coordinates.
# ---------------------------------------------------------------------------

@testset "MascarenesSimulations" begin
    @testset "full ruleset on synthetic island" begin
        # Load species/introduction data from the real CSVs (always present in repo)
        (; pred_df, introductions_df, island_endemic_tables) = load_tables()

        # Three predators whose pred_funcs only reference each other + landcover keys
        pred_keys = (:cat, :black_rat, :norway_rat)

        # 7×7 raster that contains both Mauritius intro coords:
        #   black_rat  1560  (57.7228, -20.32)
        #   cat        1688  (57.5012, -20.1597) and (57.7228, -20.32)
        #   norway_rat 1733  (57.5012, -20.1597)
        xs = X(LinRange(57.1, 57.9, 7))
        ys = Y(LinRange(-20.6, -19.95, 7))
        ti = Ti(Sampled(1500:1:2020; sampling=Intervals(Start())))

        mask = Raster(fill(true,  7, 7),       (xs, ys); name=:mask, missingval=false)
        dem  = Raster(fill(100f0, 7, 7),       (xs, ys); name=:DEM,  missingval=0f0)

        # Landcover: all native throughout the whole time axis
        lc_keys = keys(lc_categories)
        LcNV    = NamedVector{lc_keys, length(lc_keys)}
        all_native = LcNV(ntuple(i -> Float32(i == 1), length(lc_keys)))
        lc = Raster(fill(all_native, 7, 7, length(1500:2020)), (xs, ys, ti))

        auxs      = (; mus=(; mask, dem, lc))
        mus_tables = (; mus=island_endemic_tables.mus)

        # Short span: covers the black-rat introduction in year 1560
        sim_def = define_simulations(
            pred_df, introductions_df, mus_tables, auxs, 1;
            pred_keys,
            first_year        = 1558,
            last_year         = 1562,
            extant_extension  = 0,
            pred_pops_aux     = (; mus=nothing),
            replicates        = nothing,
        )

        (; ruleset, islands) = sim_def
        (; output, init)     = islands.mus

        @test_nowarn sim!(output, ruleset; printframe=false)

        # 1558..1562 = 5 stored frames
        @test length(output) == 5

        # Grid keys are present in every output frame
        final = last(output)
        @test hasproperty(final, :endemic_presence)
        @test hasproperty(final, :pred_pop)

        # Black rat was introduced in 1560, so by 1562 pred_pop must be nonzero
        total_pred = sum(sum, final.pred_pop)
        @test total_pred > 0

        # No endemic should have spread *beyond* the land mask
        masked_out = .!mask
        @test all(iszero, final.endemic_presence[masked_out])
    end
end
