using Permutations
using Plots
include("DeferredAcceptance.jl")

samp = 8
nms = [(100, 90), (100, 99), (100, 101), (100, 110)]

function plotter(n, m, samp)
    capacities = ones(Int64, m)

    cdf_STB = zeros(Int64, m)
    cdf_MTB = zeros(Int64, m)

    for i in 1:samp
        students = hcat((randperm(m) for i in 1:n)...)
     #   println(students)
        schools = ones(Int64, n, m)
        
        schools_STB = STB(schools)
        schools_MTB = MTB(schools)

        cdf_STB += rank_dist(students, schools_STB, capacities)
        cdf_MTB += rank_dist(students, schools_MTB, capacities)
    end
    
    cdf_STB *= 1 / samp
    cdf_MTB *= 1 / samp
    return plot([cdf_STB, cdf_MTB], label = ["DA-STB" "DA-MTB"])
end

for (i, j) in nms
    p = plotter(i, j, samp)
    savefig(p, string("plots/", i, "s", j, "c.pdf"))
    savefig(p, string("plots/", i, "s", j, "c.png"))
end