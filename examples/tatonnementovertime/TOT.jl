#=  Here I try to simulate a realistic college-admissions market, where schools
    start with arbitrary cutoffs and adjust them over time in response to demand.
    At the same time, schools also try to improve their programs, so the equilibrium
    cutoff vector varies dynamically and we get an interesting plot. =#

using DeferredAcceptance
using Plots

m = 6

γ = rand(m)
γ ./= sum(γ)
capacities = 0.8 * ones(m) / m
cutoffs_container = zeros(m, 1)
avg_improvement = .95 .+ 0.1 .* rand(m)
sort!(avg_improvement, rev=true)

"""
Example of a custom demand function. Same as that in `../MNLuniform/` but the
qualities get randomly perturbed each iteration.
"""
function MNL_single_score_demand(cutoffs)
    global cutoffs_container, γ
    cutoffs_container = hcat(cutoffs_container, cutoffs)

    sort_order = sortperm(cutoffs)
    cutoffs[sort_order]

    demands = zeros(m)

    prob_of_th = diff([cutoffs[sort_order]; 1])

    for c in 1:m, d in c:m     # For each score threshold
        demands[sort_order[c]] += prob_of_th[d] *
                                  γ[sort_order[c]] / sum(γ[sort_order[1:d]])
    end

    # println("Qualities:  ", γ)
    γ .*= avg_improvement .+ .1 .* randn(m)
    γ ./= sum(γ)

    return demands
end

# Don't worry about the maxit exceeded warning; equilibrium is in the distant future.
nonatomic_tatonnement(MNL_single_score_demand, capacities, maxit=300, β = 0., verbose=false)

p = plot(cutoffs_container'[2:end, :],
         label = reshape(["p$i, avg. imp. $(round(avg_improvement[i], digits=3))" for i in 1:m], 1, :),
         ls = [:dashdot :dot :solid],
         c = [:crimson :dodgerblue :rebeccapurple :olivedrab :goldenrod :teal],
         title = "Tâtonnement process with $m schools, one score,\nequal capacities, MNL choice, random quality improvements",
         titlefontsize = 12,
         xlabel = "iteration",
         ylabel = "score cutoff",
         ylim = (0, 1),
         legend = :bottom)

# savefig(p, string("examples/tatonnementovertime/plot.pdf"))
# savefig(p, string("examples/tatonnementovertime/plot.png"))
