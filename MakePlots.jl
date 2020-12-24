using Permutations
using Plots
include("DeferredAcceptance.jl")

samp = 5
nms = [(5000, 4800)]


function plotter(n, m, samp, a)
    capacities = ones(Int64, m)

    cdf_STB = zeros(Float64, m)
    cdf_MTB = zeros(Float64, m)

    println("$n students, $m schools, $samp samples")

    for i in 1:samp
        students = hcat((randperm(m) for i in 1:n)...)
        schools = ones(Int64, n, m)
        
		schools_STB = STB(schools)
        schools_MTB = MTB(schools)

		println("Starting STB $i")
        cdf_STB += rank_dist(students, schools_STB, capacities)
		println("Starting MTB $i")
        cdf_MTB += rank_dist(students, schools_MTB, capacities)

		println("Time: ", time() - a)
		display(plot([cdf_STB, cdf_MTB], label = ["DA-STB" "DA-MTB"]))  #
    end
    
    # cdf_STB *= 1 / samp
    # cdf_MTB *= 1 / samp
	# return plot([cdf_STB, cdf_MTB], label = ["DA-STB" "DA-MTB"])
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