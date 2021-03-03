using DeferredAcceptance
using Plots

m = 6

qualities = round.(rand(m), digits=3)
sort!(qualities, rev=true)
capacities = 0.8 * ones(m) / m
cutoffs_container = zeros(m, 1)

"""
Example of a custom demand function. This is actually
equivalent to demands_MNL_onetest(), provided in the DeferredAcceptance module.
"""
function MNL_single_score_demand(cutoffs)
    global cutoffs_container
    cutoffs_container = hcat(cutoffs_container, cutoffs)

    sort_order = sortperm(cutoffs)
    cutoffs[sort_order]

    γ = exp.(qualities)
    demands = zeros(m)

    prob_of_th = diff([cutoffs[sort_order]; 1])

    for c in 1:m, d in c:m     # For each score threshold
        demands[sort_order[c]] += prob_of_th[d] *
                                  γ[sort_order[c]] / sum(γ[sort_order[1:d]])
    end

    return demands
end

nonatomic_tatonnement(MNL_single_score_demand, capacities, maxit=15)

p = plot(cutoffs_container'[2:end, :],
         label = reshape(["p$i, δ = $(qualities[i])" for i in 1:m], 1, :),
         ls = [:dashdot :dot :solid],
         c = [:crimson :dodgerblue :rebeccapurple :olivedrab :goldenrod :teal],
         title = "Tâtonnement process with $m schools, \none score, equal capacities, MNL choice",
         titlefontsize = 12,
         xlabel = "iteration",
         ylabel = "score cutoff",
         ylim = (0, 1))

# savefig(p, string("examples/MNLuniform/plot.pdf"))
# savefig(p, string("examples/MNLuniform/plot.png"))
