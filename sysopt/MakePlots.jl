using Permutations
using DelimitedFiles
using Plots
include("../DeferredAcceptance.jl")

students = readdlm("sysopt/students.dat", Int)
schools = readdlm("sysopt/schools.dat", Int)
n, m = size(schools)

descr = "$n students, $m schools"
println(descr)

capacities = ones(Int64, m)


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

StableWelfareOpt_results = vec(readdlm("sysopt/StableWelfareOpt_results.txt", Int))
StableWelfareOpt_cmap = countmap(StableWelfareOpt_results)
cdf_StableWelfareOpt = cumsum([get(StableWelfareOpt_cmap, i, 0) for i in 1:m])

SystemWelfareOpt_results = vec(readdlm("sysopt/SystemWelfareOpt_results.txt", Int))
SystemWelfareOpt_cmap = countmap(SystemWelfareOpt_results)
cdf_SystemWelfareOpt = cumsum([get(SystemWelfareOpt_cmap, i, 0) for i in 1:m])

TTC_results = TTC_match(students, capacities)[2]
TTC_cmap = countmap(TTC_results)
cdf_TTC = cumsum([get(TTC_cmap, i, 0) for i in 1:m])


p = plot([cdf_STB, cdf_MTB, cdf_XTB, cdf_WXTB, cdf_TTC, cdf_StableWelfareOpt, cdf_SystemWelfareOpt],
     label = ["DA-STB" "DA-MTB" "DA-XTB, λ=0.5" "DA-WXTB, λ=0.5" "TTC" "Stable welfare opt" "System welfare opt"],
     lc = [:teal :rebeccapurple :crimson :olivedrab :saddlebrown :gold :dimgray],
   	 ls = [:dash :dot :dash :dot :dash :solid :dashdot],
   	 legend = :bottomright,
   	 title = descr, titlefontsize=11,
   	 xlabel = "rank", ylabel= "number of students")

display(p)

# savefig(p, string("plots/sysopt", n, "s", m, "c.pdf"))
# savefig(p, string("plots/sysopt", n, "s", m, "c.png"))
