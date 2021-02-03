#=  Here I replicate a tiny example given in Azevedo and Leshno (2016). Representing each
    student profile as a unit square and highlighting the portions admitted to each school
    gives us insight into the one-to-one correspondence between market-clearing cutoffs
    and stable matches.                                                         =#

using Plots
using Plots.PlotMeasures
using DeferredAcceptance

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

# savefig(p, string("plots/mondrian-nonatomic.pdf"))
# savefig(p, string("plots/mondrian-nonatomic.png"))

# Equivalent discrete problem
n = 100     # Number of students in each profile
students = hcat(repeat([1, 2], 1, n), repeat([2, 1], 1, n))
scores = rand(n * 2, 2)
schools = mapslices(argsort, -scores, dims=1)
capacities = round.(Int, capacities .*= n)
@assert sum(capacities) == 3 * n / 2 "oops"

assn, dist = DA(students, schools, capacities)

colors = [:dodgerblue, :olivedrab, :crimson]
markers = [:triangle, :hexagon, :+]

q = plot(xlims=(0, 1),
         ylims=(0, 1),
         xlabel="Score at school 1",
         ylabel="Score at school 2",
         layout=2,
         size=(800, 470),
         bottom_margin=70px,
         legend=nothing)

scatter!(scores[1:n, 1],
         scores[1:n, 2],
         title=students[:, 1],
         color=colors[assn[1:n]],
         markershape=markers[assn[1:n]],
         msw=0,
         marker=markers[assn[1:n]],
         subplot=1)

scatter!(scores[n + 1:end, 1],
         scores[n + 1:end, 2],
         title=students[:, n + 1],
         color=colors[assn[n + 1:end]],
         markershape=markers[assn[n + 1:end]],
         msw=0,
         subplot=2)

annotate!(1.08, -.25, text("Correspondence between school cutoffs\n"*
                           "and stable assignments, discrete form"), subplot=1)

# savefig(q, string("plots/mondrian-discrete.pdf"))
# savefig(q, string("plots/mondrian-discrete.png"))
