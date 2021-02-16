#=  After Azevedo and Leshno (2016, §IV.A), an example of how in some situations
	schools may be disincentivized to improve their quality.   =#

using DeferredAcceptance

students = [2 1 1 1 1;
			1 2 2 2 2]

# School 2 improves, winning over one applicant
students_delta = [2 2 1 1 1;
				  1 1 2 2 2]

# For illustration purposes
scores = [ 0.95  0.96  0.89  0.83  0.61;
 		   0.97  0.84  0.82  0.9   0.68 ]

schools = mapslices(argsort, 1 .- scores, dims=2)

@assert schools == [2 1 3 4 5;
		            1 3 4 2 5]

capacities = [2, 3]

println("Normal: ",DA(students, schools', capacities)[1])
println("Delta:  ",DA(students_delta, schools', capacities)[1])
# Normal: [2, 1, 1, 2, 2]
# Delta:  [2, 2, 1, 1, 2]

#=  School 2 ends up losing a great student (4), because persuading student 2
	away from school 1 meant that school 1 lowered its cutoff and 4 got in. =#
<<<<<<< HEAD

# Shows that the stable match is unique.
println("Normal-rev: ",DA(students, schools', capacities, rev=true)[1])
println("Delta-rev:  ",DA(students_delta, schools', capacities, rev=true)[1])
# Normal: [2, 1, 1, 2, 2]
# Delta:  [2, 2, 1, 1, 2]
=======
>>>>>>> f296b3067682fdbb3fd323c9e74528d5eb5912bc
