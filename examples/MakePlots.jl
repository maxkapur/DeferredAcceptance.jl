using Permutations
using Plots
include("../DeferredAcceptance.jl")

samp = 5                # Number of markets to try
nms = [(5000, 4800)]    # List of tuples of numbers of students, schools


function plotter(n, m, samp, a)
    capacities = ones(Int64, m)   # Capacity of each school; capacity 1 yields legible graphs

    cdf_STB = zeros(Float64, m)   # Blank rank dists
    cdf_MTB = zeros(Float64, m)

    println("$n students, $m schools, $samp samples")

    for i = 1:samp
        students = hcat((randperm(m) for i = 1:n)...)   # Rankings students gave to the schools
        schools = ones(Int64, n, m)                     # Rankings schools gave to the students; has ties

        schools_STB = STB(schools)                      # Break ties using STB, MTB
        schools_MTB = MTB(schools)

        println("Starting STB $i")
        cdf_STB += rank_dist(students, schools_STB, capacities)         # Run DA and update rank dists
        println("Starting MTB $i")
        cdf_MTB += rank_dist(students, schools_MTB, capacities)

        println("Time: ", time() - a)
        display(plot([cdf_STB, cdf_MTB], label = ["DA-STB" "DA-MTB"]))  # To plot as you go
    end

    cdf_STB *= 1 / samp         # Norm rank dists against sample size
    cdf_MTB *= 1 / samp
    return plot([cdf_STB, cdf_MTB], label = ["DA-STB" "DA-MTB"])
end

a = time()
println("Time: ", time() - a)

for (i, j) in nms
    # p =
    plotter(i, j, samp, a)
    # savefig(p, string("plots/", i, "s", j, "c", samp, "n.pdf"))
    # savefig(p, string("plots/", i, "s", j, "c", samp, "n.png"))
    # println("Time: ", time() - a)
end
