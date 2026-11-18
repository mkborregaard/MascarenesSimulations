# Record a gif of the land-cover predictions for one island (one-hot category layers per year).
# Usage (from the project root): julia --project=. scripts/landcover_gif.jl [mus|reu|rod] [outfile]
using Rasters, NCDatasets, GLMakie
GLMakie.activate!(; visible=false)

basepath = dirname(@__DIR__)
k = Symbol(get(ARGS, 1, "mus"))
outfile = get(ARGS, 2, joinpath(basepath, "landcover_$k.gif"))
path = joinpath(basepath, "data/lc_predictions_$k.nc")
st = RasterStack(path; lazy=true)
cats = keys(st)  # native, cleared, abandoned, urban, forestry, water (one-hot per land cell)
years = vcat(collect(1600:5:2015), 2017, 2018, 2020)
function category_map(y)
    A = read(st[Ti=Near(y)])
    out = fill(NaN32, size(A[first(cats)]))
    for (i, k) in enumerate(cats)
        out[coalesce.(parent(A[k]), 0x00) .== 0x01] .= i
    end
    out
end
maps = map(category_map, years)
nland = count(!isnan, maps[1])
colours = [colorant"#1b5e20", colorant"#e6c86e", colorant"#a5c27a", colorant"#9e9e9e", colorant"#4a8a7e", colorant"#4a90d9"]
labels = ["Native", "Cleared", "Abandoned", "Urban", "Forestry", "Water"]

fig = Figure(; size=(620, 640), fontsize=14)
i = Observable(1)
island_name = (mus="Mauritius", reu="Réunion", rod="Rodrigues")[k]
ttl = lift(j -> "$island_name land cover — $(years[j])", i)
sub = lift(j -> "native: $(round(Int, 100 * count(==(1), maps[j]) / nland))% of island", i)
ax = Axis(fig[1, 1]; title=ttl, subtitle=sub, aspect=DataAspect(), titlesize=18)
hidedecorations!(ax); hidespines!(ax)
image!(ax, lift(j -> maps[j], i); colormap=cgrad(colours, 6; categorical=true), colorrange=(0.5, 6.5),
    nan_color=:transparent, interpolate=false)
Legend(fig[2, 1], [PolyElement(; color=c) for c in colours], labels; orientation=:horizontal, nbanks=2, framevisible=false)
rowgap!(fig.layout, 4)
record(fig, outfile, eachindex(years); framerate=8) do j
    i[] = j
end
println("Wrote $outfile with $(length(years)) frames")
