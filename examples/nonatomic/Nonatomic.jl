#=  For research purposes, it is helpful to consider a nonatomic or continuous form of the
	DA algorithm. Instead of a fixed number of students with individual preferences lists,
	there is a continuum of students drawn from a fixed set of preference profiles. That
	is, a certain proportion of the students have preference list 1, another set has list
	2, etc. Then the school capacities represent the fraction of the total student volume.
	I prefer the term "nonatomic" because it relates this problem to the nonatomic routing
	games used in transportation studies; the "continuum" terminology draws on measure
	theory and is more common in the literature. Refer to Azevedo and Leshno (2016).   =#

using Plots
using DeferredAcceptance
using Random

n = 30          # Number of student profiles in continuum
m = 10          # Number of schools
α = 1.1 	    # Proportion by which overdemanded mkt is overdemanded
β = 0.9 		# Proportion by which underdemanded mkt is underdemanded

#=  This time, we have no school preference orders. Schools are assumed to have a strict
	preference order over the students, but since the students are nonatomic, there is no
	notion of a "particular" student with higher preferability. Instead, schools define a
	minimal cutoff which they steadily increase as more applications come in in order to
	maintain a full roster.								=#

students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
students_dist = rand(n)                         # Percentage of total student population
students_dist /= sum(students_dist)             # associated with each profile

capacities = rand(m)                            # Percentage of total student population
capacities /= (α * sum(capacities))             # that each school can accommodate

#=  The output format is necessarily a little different from DA(). Instead of an assignment
	for each student, we get an array that indicates the volume of students of type j sent
	to school i. The second item in the output term indicates the volume of students whose
	assignment corresponds to each rank.				=#

assn, rdist = DA_nonatomic(students, students_dist, nothing, capacities)
display(assn)
println(rdist)

# Sanity checks. These ineqs. should hold, with at least one of the two middle entries 0.
println("Unassigned students: 0 ≤ ", sum(students_dist) - sum(assn[1:m, :]),
		" ≤ ", sum(assn[m + 1, :]))
println("Remaining capacity:  0 ≤ ", sum(capacities) - sum(assn[1:m, :]),
		" ≤ ", max(sum(capacities) - sum(students_dist), 0))

# Compare with underdemanded market
capacities2 = capacities / (β * sum(capacities))
assn2, rdist2 = DA_nonatomic(students, students_dist, nothing, capacities2)

p = plot([cumsum(rdist), cumsum(rdist2)],
	 	 label=["Overdemanded (α = 1.1)" "Underdemanded (α = 0.9)"],
	 	 title="Cumulative rank distribution in nonatomic DA", titlefontsize=11,
		 lc = [:dodgerblue :olivedrab],
		 legend = :bottomright,
		 xlabel = "rank", ylabel= "volume of students")

# savefig(p, string("examples/plots/nonatomic", n, "s", m, "c.pdf"))
# savefig(p, string("examples/plots/nonatomic", n, "s", m, "c.png"))

#=  Now let's consider the case where schools have a preference order over the student
	profiles. In forward DA, each school's choice is piecewise linear root finding.
	Each school accepts all of the demand from their favorite student profiles until
	its capacity is full; it partially accepts the demand from the marginal profile,
	then rejects all the rest. 						=#

schools = hcat((randperm(n) for i = 1:m)...)

assn_het, rdist_het = DA_nonatomic(students, students_dist, schools, capacities)
assn_het2, rdist_het2 = DA_nonatomic(students, students_dist, schools, capacities2, verbose=true)

q = plot([cumsum(rdist_het), cumsum(rdist_het2)],
	 	 label=["Overdemanded (α = 1.1)" "Underdemanded (α = 0.9)"],
	 	 title="Cumulative rank distribution in nonatomic DA,\nwith heterogenous student preferability",
		 titlefontsize=11,
		 lc = [:dodgerblue :olivedrab],
		 legend = :bottomright,
		 xlabel = "rank", ylabel= "volume of students")
