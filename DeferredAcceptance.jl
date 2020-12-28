using StatsBase
using Random


# """
# Returns a boolean vector shaped like input indicating where the
# n largest entries are located. Currently unused.
# """
# function nlargest(vec, n)
#     out = falses(size(vec))
#     out[partialsortperm(vec, 1:n, rev=true)] .= true
#     return out
# end

function argsort(vec)
    return invperm(sortperm(vec))
end


"""
Given schools' ranked preference lists, which may contain ties,
breaks ties using the single tiebreaking rule by generating
a column of floats, adding this column to each column of arr,
and ranking the result columnwise.
"""
function STB(arr)
    add = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])
    return mapslices(argsort, arr + add, dims=1)
end


"""
Given schools' ranked preference lists, which may contain ties,
breaks ties using the multiple tiebreaking rule by adding to arr
a column of random floats having the same shape, then ranking the
result columnwise.
"""
function MTB(arr)
	# Given schools' ranked preference lists, which contain ties,
	# breaks ties using the multiple tiebreaking rule by adding a
	# float to each entry and ranking the result columnwise.
    add = rand(Float64, size(arr))
    return mapslices(argsort, arr + add, dims=1)
end


"""
Given schools' ranked preference lists, which may contain ties,
breaks ties using a hybrid tiebreaking rule as indicated by
entries of blend. blend should be a row vector with one entry
on [0, 1] for each col in arr. 0 means that school will use STB,
1 means MTB, and a value in between yields a convex combination
of the rules, which produces interesting results but has not yet
been theoretically analyzed. If blend is a scalar, the same value
will be used at all schools. Undefined behavior for values outside
the [0, 1] interval.
"""
function HTB(arr, blend; return_add=false::Bool)
	add_STB = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])
	add_MTB = rand(Float64, size(arr))
	add = (1 .- blend) .* add_STB + blend .* add_MTB
	if return_add
		return mapslices(argsort, arr + add, dims=1), add
	else
		return mapslices(argsort, arr + add, dims=1)
	end
end


"""
Given schools' ranked preference lists, which contain ties,
first breaks ties using student welfare, then breaks subsequent
ties using a hybrid tiebreaking rule indicated by entries of blend.
Or in "equity" mode, breaks ties by minimizing student welfare, which
gives priority in DA to students whose current assignment is poor.
See ?HTB for an explanation of how to configure blend.
"""
function WTB(schools, students, blend; equity=false::Bool, return_add=false::Bool)
	add_welfare = equity ? -1 * students' / size(schools)[1] : students' / size(schools)[1]
    add_STB = (1 / size(schools)[1]) *
              repeat(rand(Float64, size(schools)[1]), 1, size(schools)[2])
	add_MTB = (1 / size(schools)[1]) *
              rand(Float64, size(schools))
	add = add_welfare +
		  (1 .- blend) .* add_STB + blend .* add_MTB
	if return_add
		return mapslices(argsort, schools + add, dims=1), add
	else
		return mapslices(argsort, schools + add, dims=1)
    end
end


"""
Given an array of student preferences, where (i, j) indicates the
rank that student j gave to school i, and an array of the transposed
shape indicating the schools' rankings over the students, uses
student-proposing DA to compute a stable assignment. Returns a list of
schools corresponding to each student (m + 1 indicates unassigned) and a
list of the student rankings associated with each match. Both sets of
preferences must be strict; use STB, MTB, HTB, or XTB to preprocess
if your data does not satisfy this.
"""
function DA(students::Array{Int64, 2}, schools::Array{Int64, 2},
            capacities_in::Array{Int64, 1};
			verbose=false::Bool, rev=false::Bool)
    n, m = size(schools)
	done = false
	nit = 0

	students_inv = mapslices(invperm, students, dims=1)
	schools_inv = mapslices(invperm, schools, dims=1)

	if rev==false
        capacities = vcat(capacities_in, n)  # For students who never get assigned
		schools
		curr_assn = students_inv[1, :]

		while !done
			nit += 1
			verbose ? println("Round $nit") : nothing
			done = true
			proposals = falses(n, m + 1)
			for (s, c) in enumerate(curr_assn)
				proposals[s, c] = true
			end
			for (c, S) in enumerate(eachcol(proposals[:, 1:m]))
 				rejections = filter(i->S[i], schools_inv[:, c])[(capacities[c] + 1):end]
				for s in rejections
					done = false
					verbose ? println("  School $c rejects student $s") : nothing
					curr_assn[s] = get(students_inv, (students[c, s] + 1, s), m + 1)
				end
			end
		end
		verbose ? println("DA terminated in $nit iterations") : nothing
		return curr_assn, [get(students, (c, s), m + 1) for (s, c) in enumerate(curr_assn)]

	else
		not_yet_rejected = trues(n, m)
		curr_assn = [schools_inv[:, c][1:q] for (c, q) in enumerate(capacities_in)]

		while !done
			nit += 1
			verbose ? println("Round $nit") : nothing
			done = true
			proposals = falses(m, n) # May not need n+1 here
			for (c, S) in enumerate(curr_assn)
				proposals[c, S] .= true
			end
			for (s, C) in enumerate(eachcol(proposals))
				rejections = filter(i->C[i], students_inv[:, s])[2:end]
				for c in rejections
					done = false
					verbose ? println("  Student $s rejects school $c") : nothing
					not_yet_rejected[s, c] = false
					curr_assn[c] = filter(x -> not_yet_rejected[x, c],
										  schools_inv[:, c])[1:min(end, capacities_in[c])]
				end
			end
		end
		verbose ? println("DA terminated in $nit iterations") : nothing

		# Compute the assignment from students' perspective
		students_assn = m .+ ones(Int, n)
		for (c, S) in enumerate(curr_assn)
			for s in S
				students_assn[s] = c
			end
		end
		return students_assn, [get(students, (c, s), m + 1) for (s, c) in enumerate(students_assn)]
	end
end


"""
Nonatomic (continuous) analogue of DA(). Students are a continuum of profiles distributed
over a fixed set of student profiles, and school capacities are fractions of the total
student population.
"""
function DA_nonatomic(students::Array{Int64, 2}, students_dist::Array{Float64,1},
					  capacities_in::Array{Float64, 1};
					  verbose=false::Bool, rev=false::Bool, tol=1e-8)
    m, n = size(students)
	done = false
	nit = 0

	if rev==false
        capacities = vcat(capacities_in, sum(students_dist))  # For students who never get assigned
		students_inv = mapslices(invperm, students, dims=1)

		# Each entry indicates the volume of students from type j assigned to school i
		curr_assn = zeros(Float64, m + 1, n)
		for (s, C) in enumerate(eachcol(students_inv))
			curr_assn[C[1], s] = students_dist[s]
		end

		while !done
			nit += 1
			verbose ? println("\n\nRound $nit") : nothing
			done = true
			demands = sum(curr_assn, dims = 2)

			for c in 1:m 	# Reject bin (c = m + 1) is never overdemanded
				if (demands[c] > tol) && (demands[c] > capacities[c])
					prop_to_reject = 1 - capacities[c] / demands[c]
					verbose ? print("\n  Total demand for school $c was ", demands[c],
							", but capacity is ", capacities[c],
							"\n  Rejecting $prop_to_reject of students from schools ") : nothing
					for (s, d) in enumerate(curr_assn[c, :])
						if d > 0
							done = false
							verbose ? print("$s ") : nothing
							next_school_id = get(students_inv, (students[c, s] + 1, s), m + 1)
							curr_assn[next_school_id, s] += prop_to_reject * curr_assn[c, s]
							curr_assn[c, s] *= 1 - prop_to_reject
						end
					end
				end
			end
		end

		verbose ? println("\nDA terminated in $nit iterations") : nothing
		rank_dist = sum([col[students_inv[:, i]] for (i, col) in enumerate(eachcol(curr_assn))])
		append!(rank_dist, sum(curr_assn[m + 1, :]))
		return curr_assn, rank_dist

	else
		print("Reverse hasn't been implemented yet")
	end
end


"""
Convenience function that runs DA and outputs the cumulative rank
distribution data.
"""
function rank_dist(students, schools, capacities; verbose=false::Bool, rev=false::Bool)
    n, m = size(schools)
    dist_cmap = countmap(DA(students, schools, capacities, verbose=verbose, rev=rev)[2])
    rank_hist = [get(dist_cmap, i, 0) for i in 1:m]
    return cumsum(rank_hist)
end
