#=  For research purposes, it is helpful to consider a nonatomic or continuous form of the
	DA algorithm. Instead of a fixed number of students with individual preferences lists,
	there is a continuum of students drawn from a fixed set of preference profiles. That
	is, a certain proportion of the students have preference list 1, another set has list
	2, etc. Then the school capacities represent the fraction of the total student volume.
	I prefer the term "nonatomic" because it relates this problem to the nonatomic routing
	games used in transportation studies; the "continuum" terminology draws on measure
	theory and is more common in the literature. Refer to Azevedo and Leshno (2016).   =#

using Plots
include("../DeferredAcceptance.jl")

n = 30         # Number of student profiles in continuum
m = 10         # Number of schools
α = 1.1 	   # Proportion by which market is overdemanded

#=  Notice that we have no school preference orders. Schools are assumed to have a strict
	preference order over the students, but since the students are nonatomic, there is no
	notion of a "particular" student with higher preferability; the algorithm simply
	asserts that a certain percentage of applicants exceeds each school's cutoff.	=#

students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
students_dist = rand(n)                         # Percentage of total student population
students_dist /= sum(students_dist)             # associated with each profile

capacities = rand(m)                            # Percentage of total student population
capacities /= (α * sum(capacities))             # that each school can accommodate

#=  The output format is necessarily a little different from DA(). Instead of an assignment
	for each student, we get an array that indicates the volume of students of type j sent
	to school i. The second item in the output term indicates the volume of students whose
	assignment corresponds to each rank.				=#

assn, rdist = DA_nonatomic(students, students_dist, capacities)
display(assn)
println(rdist)

# Sanity checks. These ineqs. should hold, with at least one of the two middle entries 0.
println("Unassigned students: 0 <= ", sum(students_dist) - sum(assn[1:m, :]),
		" <= ", sum(assn[m + 1, :]))
println("Remaining capacity:  0 <= ", sum(capacities) - sum(assn[1:m, :]),
		" <= ", max(sum(capacities) - sum(students_dist), 0))

# Compare with underdemanded market
capacities2 = capacities / (0.9 * sum(capacities))
assn2, rdist2 = DA_nonatomic(students, students_dist, capacities2)

p = plot([cumsum(rdist), cumsum(rdist2)],
	 	 label=["Overdemanded (α = 1.1)" "Underdemanded (α = 0.9)"],
	 	 title="Cumulative rank distribution in nonatomic DA", titlefontsize=11,
		 lc = [:dodgerblue :olivedrab],
		 legend = :bottomright,
		 xlabel = "rank", ylabel= "volume of students")

savefig(p, string("plots/nonatomic", n, "s", m, "c.pdf"))
savefig(p, string("plots/nonatomic", n, "s", m, "c.png"))
