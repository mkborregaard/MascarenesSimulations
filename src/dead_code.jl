# Dead code archive
#
# This file collects commented-out or abandoned code that was removed from active source
# files to improve readability. Each section notes its original location.
# This file is NOT included in the module.

# =============================================================================
# FROM src/rules.jl — alternative endemic_recouperation_rule (was lines 50-67)
# Commented out in favour of the ExtirpationRisks NeighborhoodRule approach.
# =============================================================================

# endemic_recouperation_rule = let recouperation_rate_aux=Aux{:recouperation_rate}()
#     Neighbors{:endemic_presence}(Moore(1)) do data, hood, presences, I
#         # any(presences) || return presences
#         recouperation_rate = DG.get(data, recouperation_rate_aux)
#         nbr_sums = foldl(hood; init=Base.reinterpret.(UInt8, zero(first(hood)))) do x, y
#             Base.reinterpret(UInt8, x) + Base.reinterpret(UInt8, y)
#         end
#         map(presences, nbr_sums, recouperation_rate) do p, n_nbrs, rr
#             if p
#                 true
#             elseif n_nbrs > 0
#                 rand(Float32) < (n_nbrs * rr / length(hood))
#             else
#                 false
#             end
#         end
#     end
# end

# =============================================================================
# FROM src/rules.jl — alternative pred_funcs including mouse/pig/wolf_snake/macaque
# (was lines ~246-291, two commented blocks)
# These were earlier parameterisations before settling on the current pred_funcs.
# The second block contained a syntax-error fragment (`1spec .5f0p.urban`).
# =============================================================================

# pred_funcs variant A (included inter-predator competition for mouse, with wolf_snake/macaque):
#
# pred_funcs = (;
#     cat =        p -> 1.0f0p.black_rat + 0.3f0p.norway_rat + 1.0f0p.mouse + 10f0p.urban + 2f0p.cleared,
#     black_rat  = p -> -0.2f0p.cat - 0.1f0p.norway_rat - 0.1f0p.mouse + 0.5f0p.native + 0.3f0p.abandoned + 0.3f0p.forestry + 1p.urban,
#     norway_rat = p -> -0.1f0p.cat - 0.1f0p.black_rat - 0.1f0p.mouse + 1.5f0p.urban - 0.2f0p.native,
#     mouse =      p -> -0.3f0p.cat - 0.2f0p.black_rat - 0.2f0p.norway_rat + 0.8f0p.cleared + 1.5f0p.urban,
#     pig =        p -> 0.0f0p.native - 0.0f3p.abandoned - 2f0p.urban - 1.0f0p.cleared,
#     wolf_snake = p -> -0.2f0p.cat + 0.2f0p.black_rat + 0.3f0p.mouse - 0.5f0p.urban + 0.3f0p.native,
#     macaque =    p -> 1.0f0p.abandoned + 0.7f0p.forestry + 0.4f0p.native - 1.0f0p.urban - 0.8f0p.cleared
# )[pred_keys]

# pred_funcs variant B (simplified, no inter-predator effects):
#
# pred_funcs = (;
#     cat =        p -> 10f0p.urban + 2f0p.cleared,
#     black_rat  = p -> 0.5f0p.native + 0.3f0p.abandoned + 0.3f0p.forestry + 1p.urban,
#     norway_rat = p -> 1.5f0p.urban - 0.2f0p.native,  # note: original had syntax error "1spec .5f0"
#     mouse =      p -> 0.8f0p.cleared + 1.5f0p.urban,
#     pig =        p -> 0.5f0p.native + 0.4f0p.abandoned - 2f0p.urban - 1.0f0p.cleared,
#     wolf_snake = p -> 0.5f0p.urban + 0.3f0p.native,
#     macaque =    p -> 1.0f0p.abandoned + 0.7f0p.forestry + 0.4f0p.native - 1.0f0p.urban - 0.8f0p.cleared
# )[pred_keys]

# =============================================================================
# FROM src/rules.jl — habitat rule (was lines ~395-408)
# Presence dependent on habitat suitability; replaced by clearing_rule.
# =============================================================================

# habitat = let native=Aux{:native}()
#     Cell{:presences}() do data, presences, I
#         hp = get(data, native, I)
#         habitat_requirement = DG.aux(data).habitat_requirement
#         map(presences, habitat_requirement) do present, hs
#             if present
#                 rand() < hp * hs
#             else
#                 false
#             end
#         end
#     end
# end

# =============================================================================
# FROM src/rules.jl — probabilistic clearing_rule alternative (was lines ~418-423)
# Used a probabilistic threshold instead of a hard 20% native cover cutoff.
# =============================================================================

# clearing_rule = let landcover=Aux{:landcover}(), native_needs=native_needs
#     Cell{:endemic_presence}() do data, presences, I
#         lc = get(data, landcover, I)
#         presences .& map((lc, n) -> lc * n > rand(Float32), lc.native, native_needs)
#     end
# end

# =============================================================================
# FROM src/functions.jl — predator_susceptibility with mass_response (was lines ~168-173)
# Earlier version included a mass-based response term.
# =============================================================================

# function predator_susceptibility(mass_response, pred_response, traits)
#     pred_suscept = mapreduce(+, pred_response, traits) do pr, t
#         map(mass_response, pr) do m, p
#             t .* p .* m
#         end
#     end ./ (PRED_SUSCEPT_NORM)
# end

# =============================================================================
# FROM scripts/simulation.jl — pred_pops caching + endemic-only simulation workflow
# (was lines ~76-115)
# This is the intended calibration workflow: run predator dynamics once, cache to
# JLD2, then feed the cached populations into the endemic_ruleset for fast
# repeated optimisation runs. Not yet wired into the active script.
# =============================================================================

# pred_pop_jld = "../cache/pred_pops_$aggfactor.jld2"
# if isfile(pred_pop_jld)
#     _jld = jldopen(pred_pop_jld, "r")
#     pred_pops_aux = _jld["pred_pops_aux"];
#     close(_jld)
# else
#     (; ruleset, rules, pred_ruleset, endemic_ruleset, islands, pred_response) = define_simulations(
#         pred_df, introductions_df, island_endemic_tables, auxs, aggfactor;
#         replicates=nothing, pred_keys, first_year, last_year, extant_extension,
#         pred_pops_aux = map(_ -> nothing, dems),
#     );
#     pred_pops_aux = map(islands) do island
#         (; pred_output, init) = island
#         @time sim!(pred_output, pred_ruleset; proc=SingleCPU(), printframe=true);
#         A = cat(pred_output...; dims=3)
#         DimArray(A, (dims(init.pred_pop)..., dims(pred_output)...))
#     end
#
#     jldsave(pred_pop_jld; pred_pops_aux, pred_response);
# end
# sum(getproperty.(pred_pops_aux.rod[Ti=At(2009)], :cat))

# (; ruleset, rules, pred_ruleset, endemic_ruleset, islands) = define_simulations(
#     pred_df,
#     introductions_df,
#     island_endemic_tables,
#     auxs,
#     aggfactor;
#     replicates=nothing,
#     first_year,
#     last_year,
#     extant_extension,
#     pred_keys,
#     pred_pops_aux,
# );
#
# mkoutput = mk_pred(init, pred_ruleset; landcover=lc_all[k], output_kw...)
