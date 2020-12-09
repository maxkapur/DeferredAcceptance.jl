using Permutations
using Plots
include("DeferredAcceptance.jl")

samp = 100
nms = [(5000, 4800)]

function plotter(n, m, samp)
    println("$n students, $m schools, $samp samples")
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

a = time()

println("Time: ", time() - a)

for (i, j) in nms
    p = plotter(i, j, samp)
    savefig(p, string("plots/", i, "s", j, "c", samp, "n.pdf"))
    savefig(p, string("plots/", i, "s", j, "c", samp, "n.png"))
    println("Time: ", time() - a)
end