# Run the full invasive/endemic simulation for one island and record it as a gif.
# Usage (from the project root): julia --project=. -t auto scripts/simulation_gif.jl [mus|reu|rod] [outfile] [year_step]

using MascarenesSimulations
using DynamicGrids
using DimensionalData
using GLMakie
GLMakie.activate!(; visible=false)

basepath = MascarenesSimulations.basepath
aggfactor = 16; first_year = 1550; last_year = 2018; extant_extension = 0
pred_keys = (:cat, :black_rat, :norway_rat)
k = Symbol(get(ARGS, 1, "mus"))
outfile = get(ARGS, 2, joinpath(basepath, "simulation_$k.gif"))
landcover_paths = (
    mus=joinpath(basepath, "data/lc_predictions_mus.nc"),
    reu=joinpath(basepath, "data/lc_predictions_reu.nc"),
    rod=joinpath(basepath, "data/lc_predictions_rod.nc"),
)
(; pred_df, introductions_df, island_endemic_tables) = load_tables()
(; masks, dems) = load_rasters()
auxs = load_aux(; masks, dems, landcover_paths, aggfactor, last_year)
(; ruleset, islands) = define_simulations(
    pred_df, introductions_df, island_endemic_tables, auxs, aggfactor;
    replicates=nothing, first_year, last_year, extant_extension, pred_keys,
    pred_pops_aux=map(_ -> nothing, dems),
);
(; init, output_kw) = islands[k];

# Keep per-year predator densities, endemic richness and number of surviving species
npreds = length(pred_keys)
output = TransformedOutput(init; output_kw...) do f
    preds = ntuple(i -> Float32.(getindex.(Array(f.pred_pop), i)), npreds)
    richness = Float32.(sum.(Array(f.endemic_presence)))
    surviving = reduce((a, b) -> a .| b, Array(f.endemic_presence))
    (; preds, richness, nsurviving=count(Tuple(surviving)))
end
@time sim!(output, ruleset; printframe=false)
frames = output.frames
tspan = output_kw.tspan
nspecies = length(first(init.endemic_presence))
println("Endemic species surviving in $(last(tspan)): $(frames[end].nsurviving) / $nspecies")

mask = Array(auxs[k].mask) .=== true
xs, ys = map(collect, lookup(init.pred_pop, (X, Y)))
nanmask(A) = map((a, m) -> m && a > 0 ? a : NaN32, A, mask)
native = auxs[k].lc
native_at(t) = map((x, m) -> m ? x.native : NaN32, parent(native[Ti=At(t)]), mask)
bg = map(m -> m ? 0.0f0 : NaN32, mask)

predmax = map(i -> maximum(fr -> maximum(fr.preds[i]), frames), 1:npreds)
richmax = Float32(nspecies)

fig = Figure(; size=(1500, 820), fontsize=16)
i_obs = Observable(1)
island_name = (mus="Mauritius", reu="Réunion", rod="Rodrigues")[k]
title = lift(i -> "$island_name — $(tspan[i])    (endemic species surviving: $(frames[i].nsurviving)/$nspecies)", i_obs)
Label(fig[0, 1:4], title; fontsize=24, font=:bold)
function mapaxis(pos, ttl)
    ax = Axis(fig[pos...]; title=ttl, aspect=DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    heatmap!(ax, xs, ys, bg; colormap=[:grey85, :grey85], nan_color=:transparent)
    ax
end

ax = mapaxis((1, 1), "Native habitat fraction")
hm = heatmap!(ax, xs, ys, lift(i -> native_at(tspan[i]), i_obs); colormap=:YlGn, colorrange=(0, 1), nan_color=:transparent)
Colorbar(fig[1, 1][1, 2], hm)

titles = map(p -> replace(titlecase(string(p)), "_" => " ") * " density", pred_keys)
for (j, (cmap, ttl)) in enumerate(zip((:Reds, :Blues, :Purples), titles))
    a = mapaxis((1, j + 1), ttl)
    h = heatmap!(a, xs, ys, lift(i -> nanmask(frames[i].preds[j]), i_obs);
        colormap=cmap, colorrange=(0, max(predmax[j], 1f-6)), nan_color=:transparent)
    Colorbar(fig[1, j + 1][1, 2], h)
end

a = mapaxis((2, 1), "Endemic species richness")
h = heatmap!(a, xs, ys, lift(i -> nanmask(frames[i].richness), i_obs);
    colormap=:viridis, colorrange=(0, richmax), nan_color=:transparent)
Colorbar(fig[2, 1][1, 2], h)

ts = Axis(fig[2, 2:4]; title="Total endemic range (species × cells), % of 1550", xlabel="Year", ylabel="%")
occ = [100 * sum(fr.richness) / sum(frames[1].richness) for fr in frames]
lines!(ts, collect(tspan), occ; color=(:grey60, 0.6))
pts = lift(i -> Point2f.(collect(tspan[1:i]), occ[1:i]), i_obs)
lines!(ts, pts; color=:firebrick, linewidth=3)
ylims!(ts, 0, 105)
vlines!(ts, lift(i -> [tspan[i]], i_obs); color=:black, linestyle=:dash)

step = parse(Int, get(ARGS, 3, "2"))
idx = collect(1:step:length(tspan)); last(idx) == length(tspan) || push!(idx, length(tspan))
@time record(fig, outfile, idx; framerate=20) do i
    i_obs[] = i
end
println("Wrote $outfile")
