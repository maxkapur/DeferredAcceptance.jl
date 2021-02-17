#=  After Azevedo and Leshno (2016, §IV.A), an example of how in some situations
	schools may be disincentivized to improve their quality.   =#

using DeferredAcceptance

# Might add these functions to the module later.
function quality(assn, capacities, scores)
	(m, ) = size(capacities)
	res = zeros(m)
	for (s, c) in enumerate(assn)
		if c ≤ m
			res[c] += scores[s, c]
		end
	end
	res ./= capacities
	return res
end

function cutoffs(assn, capacities, scores)
	(m, ) = size(capacities)
	res = zeros(m)
	for c in 1:m
		res[c] = minimum(scores[:, c][assn .== c])
	end
	return res
end

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

out_normal = DA(students, schools', capacities)
out_delta = DA(students_delta, schools', capacities)

println("Normal assn:  ", out_normal[1])
println("    Quality:  ", quality(out_normal[1], capacities, scores'))
println("    Cutoffs:  ", cutoffs(out_normal[1], capacities, scores'))
println("Delta:        ", out_delta[1])
println("    Quality:  ", quality(out_delta[1], capacities, scores'))
println("    Cutoffs:  ", cutoffs(out_delta[1], capacities, scores'))
# Normal assn:  [2, 1, 1, 2, 2]
#     Quality:  [0.925, 0.8500000000000001]
#     Cutoffs:  [0.89, 0.68]
# Delta:        [2, 2, 1, 1, 2]
#     Quality:  [0.86, 0.8300000000000001]
#     Cutoffs:  [0.83, 0.68]

#=  School 2 ends up losing a great student (4), because persuading student 2
	away from school 1 meant that school 1 lowered its cutoff and 4 got in. =#

# Shows that the stable match is unique.
println("Normal-rev:   ",DA(students, schools', capacities, rev=true)[1])
println("Delta-rev:    ",DA(students_delta, schools', capacities, rev=true)[1])
# Normal-rev:   [2, 1, 1, 2, 2]
# Delta-rev:    [2, 2, 1, 1, 2]
