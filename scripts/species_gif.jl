# Run the full invasive/endemic simulation for one island and record a gif of
# individual endemic species, with cells where each species was lost coloured
# by cause (as in `makie_sim`).
# Usage (from the project root):
#   julia --project=. -t auto scripts/species_gif.jl [mus|reu|rod] [outfile] [year_step] [species]
# where `species` is a comma-separated list, e.g. "Raphus cucullatus,Falco punctatus".
# By default up to 12 species are chosen to cover every trait combination the
# model distinguishes (group and flightlessness), preferring species with a
# recorded extinction date.
using MascarenesSimulations
using DynamicGrids
using DimensionalData
using GLMakie
GLMakie.activate!(; visible=false)

basepath = MascarenesSimulations.basepath
aggfactor = 16; first_year = 1550; last_year = 2018; extant_extension = 0
pred_keys = (:cat, :black_rat, :norway_rat)
k = Symbol(get(ARGS, 1, "mus"))
outfile = get(ARGS, 2, joinpath(basepath, "species_$k.gif"))
step = parse(Int, get(ARGS, 3, "2"))
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

# Species selection
tbl = island_endemic_tables[k]
all_species = collect(string.(propertynames(first(init.endemic_presence))))
tablerow(sp) = findfirst(==(replace(sp, "_" => " ")), tbl.Species)
recorded(r) = tbl[r, "$(k)_extinct"]
function default_species(; n=12)
    rows = tablerow.(all_species)
    groups = ("bird", "reptile", "mammal")
    combos = sort(unique((tbl.Group[r], coalesce(tbl.Flightlessness[r], 0.0)) for r in rows);
        by=c -> (-c[2], something(findfirst(==(c[1]), groups), 4)))
    # Within each trait combination alternate recorded-extinct (earliest first) and extant species
    queues = map(combos) do c
        rs = filter(r -> (tbl.Group[r], coalesce(tbl.Flightlessness[r], 0.0)) == c, rows)
        extinct = sort(filter(r -> !ismissing(recorded(r)), rs); by=r -> recorded(r))
        extant = filter(r -> ismissing(recorded(r)), rs)
        interleaved = Int[]
        for j in 1:max(length(extinct), length(extant))
            j <= length(extinct) && push!(interleaved, extinct[j])
            j <= length(extant) && push!(interleaved, extant[j])
        end
        interleaved
    end
    chosen = Int[]
    while length(chosen) < n && any(!isempty, queues)
        for q in queues
            !isempty(q) && length(chosen) < n && push!(chosen, popfirst!(q))
        end
    end
    [findfirst(sp -> tablerow(sp) == r, all_species) for r in chosen]
end
species_idx = if length(ARGS) >= 4
    map(strip.(split(ARGS[4], ','))) do name
        i = findfirst(sp -> strip(replace(sp, "_" => " ")) == replace(name, "_" => " "), all_species)
        isnothing(i) && error("$name is not an endemic species on $k. Options: $(join(all_species, ", "))")
        i
    end
else
    default_species()
end
nsel = length(species_idx)

# Keep presence and loss causes for the selected species each year
sel = Tuple(species_idx)
output = TransformedOutput(init; output_kw...) do f
    presences = Array(f.endemic_presence)
    causes = Array(f.causes)
    presence = map(i -> getindex.(presences, i), sel)
    cause = map(i -> map(c -> (c[i].cat, c[i].norway_rat, c[i].black_rat), causes), sel)
    (; presence, cause)
end
@time sim!(output, ruleset; printframe=false)
frames = output.frames
tspan = output_kw.tspan

mask = Array(auxs[k].mask) .=== true
native = auxs[k].lc
native_at(t) = map(x -> x.native, parent(native[Ti=At(t)]))

ncells = [count(fr.presence[s]) for fr in frames, s in 1:nsel]
range_pct = 100 .* ncells ./ ncells[1:1, :]
sim_extinct = map(1:nsel) do s
    last_present = findlast(>(0), view(ncells, :, s))
    isnothing(last_present) ? first(tspan) : last_present == length(tspan) ? nothing : tspan[last_present + 1]
end
for (s, i) in enumerate(species_idx)
    rec = recorded(tablerow(all_species[i]))
    println(rpad(all_species[i], 30), "recorded: ", rpad(ismissing(rec) ? "extant" : rec, 12),
        "simulated: ", something(sim_extinct[s], "extant ($(round(Int, range_pct[end, s]))% range)"))
end

# Colours: predator causes are mixed as RGB = (cat, norway rat, black rat), as in `makie_sim`
const PRESENT = RGBAf(0.78, 0.9, 0.76, 1)
const CLEARED = RGBAf(0.87, 0.8, 0.62, 1)
const OTHER = RGBAf(0.55, 0.55, 0.55, 1)
const NONE = RGBAf(0, 0, 0, 0)
function cellcolour(m, present, cause, native)
    m || return NONE
    present && return PRESENT
    s = sum(cause)
    s > 0 && return RGBAf(min.(1.0f0, cause ./ s .* 0.7f0)..., 1.0f0)
    native <= 0.2f0 ? CLEARED : OTHER
end
species_image(i, s) = cellcolour.(mask, frames[i].presence[s], frames[i].cause[s], native_at(tspan[i]))

function trait_label(r)
    fl = coalesce(tbl.Flightlessness[r], 0.0)
    prefix = fl >= 1 ? "flightless " : fl > 0 ? "partly flightless " : ""
    prefix * tbl.Group[r]
end
function record_label(r)
    rec = recorded(r)
    ismissing(rec) ? "extant" : "recorded extinct " * replace(rec, ":" => "–")
end

ncols = min(nsel, 4)
nrows = cld(nsel, ncols)
fig = Figure(; size=(350 * ncols + 100, 360 * nrows + 170), fontsize=14)
i_obs = Observable(1)
island_name = (mus="Mauritius", reu="Réunion", rod="Rodrigues")[k]
Label(fig[0, 1:ncols], lift(i -> "$island_name — $(tspan[i])", i_obs); fontsize=24, font=:bold)
for (s, i) in enumerate(species_idx)
    r = tablerow(all_species[i])
    xlabel = lift(i_obs) do j
        t = tspan[j]
        if !isnothing(sim_extinct[s]) && t >= sim_extinct[s]
            "simulated extinct $(sim_extinct[s])"
        else
            "range $(round(Int, range_pct[j, s]))% of $(first(tspan))"
        end
    end
    ax = Axis(fig[fldmod1(s, ncols)...];
        title=replace(all_species[i], "_" => " "), titlefont=:italic,
        subtitle="$(trait_label(r)) · $(record_label(r))",
        xlabel, aspect=DataAspect(),
    )
    hidedecorations!(ax; label=false); hidespines!(ax)
    image!(ax, lift(j -> species_image(j, s), i_obs); interpolate=false)
end
legend_colours = [PRESENT, RGBAf(0.7, 0, 0, 1), RGBAf(0, 0, 0.7, 1), RGBAf(0, 0.7, 0, 1), CLEARED, OTHER]
legend_labels = ["Present", "Lost: cat", "Lost: black rat", "Lost: Norway rat", "Lost: habitat cleared", "Lost: other"]
Legend(fig[nrows + 1, 1:ncols], [PolyElement(; color=c) for c in legend_colours], legend_labels,
    "Mixed colours: loss caused by several predators"; orientation=:horizontal, framevisible=false, titleposition=:left)

idx = collect(1:step:length(tspan)); last(idx) == length(tspan) || push!(idx, length(tspan))
@time record(fig, outfile, idx; framerate=20) do i
    i_obs[] = i
end
println("Wrote $outfile")
