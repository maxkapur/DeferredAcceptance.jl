#=  Here I replicate a tiny example given in Azevedo and Leshno (2016). Representing each
    student profile as a unit square and highlighting the portions admitted to each school
    gives us insight into the one-to-one correspondence between market-clearing cutoffs
    and stable matches.                                                         =#

using Plots
using Plots.PlotMeasures
include("../DeferredAcceptance.jl")

students = [1 2; 2 1]
students_dist = [1., 1.]

α = 0.75

capacities = rand(2)
capacities *= 2 * α / sum(capacities)

assn, rdist, cutoffs = DA_nonatomic(students, students_dist, nothing, capacities,
                   verbose=true, return_cutoffs=true)

p = plot(xlims=(0, 1),
         ylims=(0, 1),
         xlabel="Score at school 1",
         ylabel="Score at school 2",
         layout=2,
         size=(800, 470),
         bottom_margin=70px,
         legend=nothing)

rect(x, y) = Shape([x, 1, 1, x], [y, y, 1, 1])

plot!([Shape([cutoffs[1], 1, 1, cutoffs[1]], [0, 0, 1, 1]),
       Shape([0, cutoffs[1], cutoffs[1], 0], [cutoffs[2], cutoffs[2], 1, 1])],
      color=[:dodgerblue, :olivedrab],
      title=students[:, 1],
      subplot=1)

plot!([Shape([cutoffs[1], 1, 1, cutoffs[1]], [0, 0, cutoffs[2], cutoffs[2]]),
       Shape([0, 1, 1, 0], [cutoffs[2], cutoffs[2], 1, 1])],
      color=[:dodgerblue, :olivedrab],
      stroke=0,
      title=students[:, 2],
      subplot=2)

annotate!(1.08, -.25, text("Correspondence between school cutoffs and\n"*
      "stable assignments, after Azevedo and Leshno (2016)"), subplot=1)

savefig(p, string("plots/mondrian.pdf"))
savefig(p, string("plots/mondrian.png"))
