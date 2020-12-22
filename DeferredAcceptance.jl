using StatsBase
using Random


"""
Returns a boolean vector shaped like input indicating where the
n largest entries are located.
"""
function nlargest(vec, n)
    out = falses(size(vec))
    out[partialsortperm(vec, 1:n, rev=true)] .= true
    return out
end

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
function HTB(arr, blend)
	add_STB = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])
	add_MTB = rand(Float64, size(arr))
	return mapslices(argsort, arr + (1 .- blend) .* add_STB + blend .* add_MTB, dims=1)
end


"""
Given schools' ranked preference lists, which contain ties, 
first breaks ties using student welfare, then breaks subsequent
ties using a hybrid tiebreaking rule indicated by entries of blend.
See ?HTB for an explanation.
"""
function WTB(schools, students, blend)
    out = schools + students' / size(schools)[1]
    add_STB = (1 / size(schools)[1]) *
              repeat(rand(Float64, size(schools)[1]), 1, size(schools)[2])
	add_MTB = (1 / size(schools)[1]) *
              rand(Float64, size(schools))
    return mapslices(argsort, out + (1 .- blend) .* add_STB + blend .* add_MTB, dims=1)
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

	if rev==false
        capacities = vcat(capacities_in, n)  # For students who never get assigned
		students_inv = mapslices(invperm, students, dims=1)
		curr_assn = students_inv[1, :]
		
		while !done
			nit += 1
			verbose ? println("Round $nit") : nothing
			done = true
			proposals = falses(n, m + 1)
			for (s, c) in enumerate(curr_assn)
				proposals[s, c] = true
			end
			for (c, S) in enumerate(eachcol(proposals))
				n_proposals = sum(S)
				if n_proposals > capacities[c]
					rejections = nlargest(S .* schools[:, c], n_proposals - capacities[c])
					for (s, r) in enumerate(rejections)
						if r
							done = false
							verbose ? println("  School $c rejects student $s") : nothing
							curr_assn[s] = get(students_inv, (students[c, s] + 1, s), m + 1)
						end
					end
				end
			end
		end
		verbose ? println("DA terminated in $nit iterations") : nothing
		return curr_assn, [get(students, (c, s), m + 1) for (s, c) in enumerate(curr_assn)]

	else
		schools_inv = mapslices(invperm, schools, dims=1)
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
				n_proposals = sum(C)
				if n_proposals > 1
					rejections = nlargest(C .* students[:, s], n_proposals - 1)
					for (c, r) in enumerate(rejections)
						if r
							done = false
							verbose ? println("  Student $s rejects school $c") : nothing
							not_yet_rejected[s, c] = false
							curr_assn[c] = filter(x -> not_yet_rejected[x, c],
												  schools_inv[:, c])[1:min(end, capacities_in[c])]
						end
					end
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
Convenience function that runs DA and outputs the cumulative rank
distribution data.
"""
function rank_dist(students, schools, capacities; verbose=false::Bool, rev=false::Bool)
    n, m = size(schools)
    dist_cmap = countmap(DA(students, schools, capacities, verbose=verbose, rev=rev)[2])
    rank_hist = [get(dist_cmap, i, 0) for i in 1:m]
    return cumsum(rank_hist)
end
