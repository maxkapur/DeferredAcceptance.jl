using Plots
include("Target.jl")


samp = 1000
n = 15         # Number of student profiles. Must be <= m here.
m = 20         # Number of schools.
cap = 20      # For discrete form (unused).

CADA_disutil, STB_disutil, strat_disutil = target_doer(n, m, samp)
# CADA_disutil, STB_disutil, strat_disutil = target_doer_discrete(m, cap, samp)

CADA_improvement = STB_disutil .- CADA_disutil
println(minimum(CADA_improvement))

# a, b = minimum([minimum(o) for o in [CADA_disutil, STB_disutil, strat_disutil]]),
#        maximum([maximum(o) for o in [CADA_disutil, STB_disutil, strat_disutil]])

q = plot([strat_disutil, [0, 5]],
         [STB_disutil, [0, 5]],
        # [CADA_disutil, [a, b]],
         seriestype=[:scatter :line],
         color=[:olivedrab :gray],
         markersize=vcat(sqrt.(max.(0.2 .+ CADA_improvement, 0.2)), 0) .* 5,
         markershape=:circle,
         msw=0,
         ma=[.5 0],
         ls=[:auto :dash],
         title="Choice-augmented deferred acceptance: "*
               "\n$n profiles, $m schools, $samp samples",
         titlefontsize=11,
         xlabel="disutility when strategizing",
         ylabel="disutility under STB",
         legend=false,
         size=(600,600),
         xlims=(-0.05,3.1), ylims=(-0.05,3.1))

annotate!([(3., 0.25, Plots.text("Marker size: improvement"*
                                 "\nbetween CADA and DA-STB.", 8, :right))])

display(q)

savefig(q, string("plots/target", n, "s", m, "c.pdf"))
savefig(q, string("plots/target", n, "s", m, "c.png"))
