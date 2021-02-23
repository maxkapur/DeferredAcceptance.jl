using Plots
using StatsBase
include("Dynamic.jl")

all(assn_r1[2] .≥ assn_r2[2]) ? println("✓ Rankwise dominance holds") : println("✗ Rankwise dominance fails")
diff_ = assn_r1[2] - assn_r2[2]
println("Sum-of-ranks improvement: ", sum(diff_))

dist_cmap = countmap(diff_)
rank_hist = [get(dist_cmap, i, 0) for i in 0:maximum(keys(dist_cmap))]

descr = "Two-round dynamic reassignment with $n students, $m schools, γ = $γ"

p = plot(0:maximum(keys(dist_cmap)), rank_hist, seriestype=:bar,
         c=:rebeccapurple,
         legend=false,
         title=descr, titlefontsize=11,
         xlabel="decrease in rank of assigned school", ylabel= "number of students")

display(p)

readline()

q = plot([assn_r1[2], [0, m + 1]], [assn_r2[2], [0, m + 1]],
         seriestype=[:scatter :line],
         lc=[nothing :dimgray],
         ls=[:auto :dash],
         c=[:indigo nothing],
         ma=[0.5 0],
         msc=nothing,
         legend=false,
         title=descr, titlefontsize=11,
         xlabel="rank in round 1", ylabel= "rank in round 2")

display(q)

readline()

# savefig(p, string("examples/dynamic/plot-hist.pdf"))
# savefig(p, string("examples/dynamic/plot-hist.png"))
#
# savefig(q, string("examples/dynamic/plot-scatter.pdf"))
# savefig(q, string("examples/dynamic/plot-scatter.png"))
