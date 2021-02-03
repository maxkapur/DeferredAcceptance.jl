using Permutations
using DelimitedFiles
using Plots
using DeferredAcceptance
using StatsBase

students = readdlm("examples/sysopt/students.dat", Int)
schools = readdlm("examples/sysopt/schools.dat", Int)
n, m = size(schools)
capacities = ones(Int64, m)

descr = "Hybrid market with $n students, $m schools"
println(descr)


schools_STB = STB(schools)
schools_MTB = MTB(schools)
schools_XTB = HTB(schools, 0.5)
schools_WXTB = WTB(schools, students, 0.5)

# Update rank risks
println("Starting STB")
cdf_STB = rank_dist(students, schools_STB, capacities)
println("Starting MTB")
cdf_MTB = rank_dist(students, schools_MTB, capacities)
println("Starting XTB")
cdf_XTB = rank_dist(students, schools_XTB, capacities)
println("Starting WXTB")
cdf_WXTB = rank_dist(students, schools_WXTB, capacities)

TTC_results = TTC_match(students, capacities)[2]
TTC_cmap = countmap(TTC_results)
cdf_TTC = cumsum([get(TTC_cmap, i, 0) for i in 1:m])

LPso_results = vec([students[c, s] for (s, c) in enumerate(readdlm("examples/sysopt/LPSystemOpt.dat", Int))])
LPso_cmap = countmap(LPso_results)
cdf_LPso = cumsum([get(LPso_cmap, i, 0) for i in 1:m])

IPso_results = vec([students[c, s] for (s, c) in enumerate(readdlm("examples/sysopt/IPStableOpt.dat", Int))])
IPso_cmap = countmap(IPso_results)
cdf_IPso = cumsum([get(IPso_cmap, i, 0) for i in 1:m])


p = plot([cdf_STB, cdf_MTB, cdf_XTB, cdf_WXTB, cdf_TTC, cdf_LPso, cdf_IPso],
     label = ["DA-STB" "DA-MTB" "DA-XTB, λ=0.5" "DA-WXTB, λ=0.5" "RSD to top trading cycles" "System welfare opt (TUM LP)" "Stable welfare opt (IP)"],
     lc = [:teal :rebeccapurple :firebrick :olivedrab :orangered :gold :black],
   	 ls = [:dash :dot :dashdot :dash :dot :solid :dashdot],
   	 legend = :bottomright,
   	 title = descr, titlefontsize=11,
   	 xlabel = "rank", ylabel= "number of students")

display(p)

# savefig(p, string("examples/plots/sysopt", n, "s", m, "c.pdf"))
# savefig(p, string("examples/plots/sysopt", n, "s", m, "c.png"))
