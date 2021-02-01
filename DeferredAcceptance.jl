using StatsBase
using Random


"""
Some of the algorithms in this module are optimized for preference lists given
in "permutation" order, and others in "rating" order. Which order is used can be confirmed
by inspecting each function call. If the input calls for students, then the function
expects "rating" order, where if column i of students is [3, 1, 2], this implies that
school 1 is i's 3rd choice, school 2 is her 1st choice, and school 3 is her 2nd choice.
If the input calls for students_inv, then the expected input is [2, 3, 1], which means
the same.
"""


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
Tiebreaker function for the choice-augmented deferred acceptance
mechanism described by Abdulkadiroğlu et al. (2015). Primary tiebreaking
is accomplished by allowing students to signal a target school; secondary
ties are broken by independent STB lotteries in the target and other
schools (by default). Or, indicate another mechanism by configuring
blend_target and blend_others.
"""
function CADA(arr, targets, blend_target=0, blend_others=0;
			  return_add=false::Bool)
	add_STB_target = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])
	add_MTB_target = rand(Float64, size(arr))
	add_target = (1 .- blend_target) .* add_STB_target +
				 blend_target .* add_MTB_target
	add_target = mapslices(argsort, add_target, dims=1) / size(arr)[1]

	add_STB_others = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])
	add_MTB_others = rand(Float64, size(arr))
	add_others = (1 .- blend_others) .* add_STB_others +
	             blend_others .* add_MTB_others
	add_others /= size(arr)[1]

	add = (1 .+ copy(add_others)) / 2
	for (s, c) in enumerate(targets)
		add[s, c] = add_target[s, c] / 2
	end

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
	@assert (m,) == size(capacities_in)
	@assert (m, n) == size(students) "Shape mismatch between schools and students"
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
over a fixed set of student preference lists, and school capacities are fractions of the total
student population. School preferences are optional. If you pass schools=nothing, it assumes
that student preferability is uncorrelated with student profile, and the schools simply accept
the best students from each profile. This is the more realistic case; the algorithm is not
incentive compatible if schools can favor students based on the students' preferences.
"""
function DA_nonatomic(students::Array{Int, 2}, students_dist::Array{Float64, 1},
					  schools::Union{Array{Int, 2}, Nothing}, capacities_in::Array{Float64, 1};
					  verbose=false::Bool, rev=false::Bool, return_cutoffs=false::Bool, tol=1e-8)
    m, n = size(students)
	@assert (m,) == size(capacities_in)
	@assert (n,) == size(students_dist)
	done = false
	nit = 0

	if schools==nothing					# Homogenous student preferability
		students_inv = mapslices(invperm, students, dims=1)

		if rev==false
	        capacities = vcat(capacities_in, sum(students_dist))  # For students who never get assigned

			proposals = zeros(Float64, m + 1, n)
			for (s, C) in enumerate(eachcol(students_inv))
				proposals[C[1], s] = students_dist[s]
			end

			# Each entry indicates the volume of students from type j assigned to school i
			curr_assn = copy(proposals)

			# Equiv. to 1 - cutoff, where cutoff is the minimum percentile a student must score
			# on a given school's test to be admitted.
			yields = ones(m + 1)

			while !done
				nit += 1
				verbose ? println("\n\nRound $nit") : nothing
				done = true

				proposals_above_cutoff = curr_assn + yields .* (proposals - curr_assn)
				demands = sum(proposals, dims = 2)

				for c in 1:m	# Reject bin (c = m + 1) is never overdemanded
					if demands[c] - capacities[c] > tol
						done = false
						new_yield_c = yields[c] * capacities[c] / sum(proposals_above_cutoff[c, :])
						verbose ? print("\n  Total demand for school $c was ", demands[c],
							", but capacity is ", capacities[c],
							"\n  Updating yield from ", yields[c],
							" to $new_yield_c and rejecting") : nothing

						curr_assn[c, :] = new_yield_c * proposals_above_cutoff[c, :] / yields[c]
						rejections_c = proposals[c, :] - curr_assn[c, :]
						yields[c] = new_yield_c

						for (s, d) in enumerate(rejections_c)
							if d > 0
								verbose ? print("\n     $d from $s") : nothing
								next_school_id = get(students_inv, (students[c, s] + 1, s), m + 1)
								proposals[next_school_id, s] += d
								proposals[c, s] -= d
							end
						end
					end
				end

				# Update reject bin
				curr_assn[m + 1, :] = proposals[m + 1, :]
			end
			cutoffs = (1 .- yields)[1:end - 1]

			verbose ? println("\nDA terminated in $nit iterations") : nothing
			verbose ? println("Cutoffs: ", cutoffs) : nothing
			rank_dist = sum([col[students_inv[:, i]] for (i, col) in enumerate(eachcol(curr_assn))])
			append!(rank_dist, sum(curr_assn[m + 1, :]))
			if return_cutoffs
				return curr_assn, rank_dist, cutoffs
			else
				return curr_assn, rank_dist
			end

		else
			print("Reverse hasn't been implemented yet")
		end

	else			# Schools have preference order over student types
		@assert (n, m) == size(schools) "Shape mismatch between schools and students"
		students_inv = mapslices(invperm, students, dims=1)
		schools_inv = mapslices(invperm, schools, dims=1)
		if rev==false
			capacities = vcat(capacities_in, sum(students_dist))  # For students who never get assigned

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
				for c in 1:m    # Reject bin (c = m + 1) is never overdemanded
					if demands[c] - capacities[c] > tol
						capacity_remaining = capacities[c]
						verbose ? print("\n  Total demand for school $c was ", demands[c],
								", but capacity is ", capacities[c]) : nothing
						for s in filter(i->curr_assn[c, i] > 0, schools_inv[:, c])
							if capacity_remaining >= curr_assn[c, s]
								capacity_remaining -= curr_assn[c, s]
								verbose ? print("\n    Accepting demand of ", curr_assn[c, s],
												" from profile $s; remaining capacity ",
												capacity_remaining) : nothing
							else
								done = false
								prop_to_reject = 1 - capacity_remaining / curr_assn[c, s]
								verbose ? print("\n    Demand from profile $s was ", curr_assn[c, s],
										"; rejecting $prop_to_reject of it") : nothing
								next_school_id = get(students_inv, (students[c, s] + 1, s), m + 1)
								curr_assn[next_school_id, s] += prop_to_reject * curr_assn[c, s]
								curr_assn[c, s] *= 1 - prop_to_reject
								capacity_remaining = 0
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


"""
Given the edges of a graph (in dictionary form), uses depth-first search
to find cycles. Assumes all cycles are node disjoint.
"""
function cycle_DFS(edges)
    if isempty(edges)
        return Set{Vector{Int64}}()
    end

    nodes = union(edges...)
    visited = Dict{Int64, Bool}((i, false) for i in nodes)
    out = Set{Vector{Int64}}()
    for nd in nodes
        if !visited[nd]
            curr_node = nd
            stack = Vector{Int64}()
            while true
                if curr_node == :deadend
                    break
                elseif curr_node in stack
                    visited[curr_node] = true
                    push!(out, stack[findfirst( x -> x==curr_node, stack):end])
                    break
                else
                    visited[curr_node] = true
                    push!(stack, curr_node)
                    curr_node = get(edges, curr_node, :deadend)
                end
            end
        end
    end
    return out
end


"""
Uses the top-trading cycles allocation to find the market core. The implementation
follows Nisan et al. (2007), §10.3.
"""
function TTC(students_inv::Array{Int64,2}, assn::Array{Int64,1};
             verbose=false::Bool)
    (m, n) = size(students_inv)
    @assert (n, ) == size(assn) "Size mismatch between students_inv and assn"
    prev_assn = copy(assn)
    curr_assn = copy(assn)
    swaps_done = falses(n)

    for k in 1:(m - 1) #max(m - 1, n - 1)
        verbose ? println("Searching for Pareto-improving cycles at rank $k") : nothing
        verbose ? println("Current assignment: $curr_assn") : nothing
        swap_requests = Dict{Int64, Int64}()
        for s in 1:n
            # In the symmetrical case, curr_assn is always a permutation, and you could
            # invert it at the outset for a marginal performance improvement.
            swap_targets = findall(curr_assn .== students_inv[k, s])
            if !isempty(swap_targets) && !swaps_done[s]
                # We can use any index here, but randomness seems fair.
                swap_requests[s] = rand(swap_targets)
            end
        end
        verbose ? println("  Swap requests: $swap_requests") : nothing

        cycles = cycle_DFS(swap_requests)

        for cyc in cycles
            verbose ? println("  Cycle involving students $cyc") : nothing
            for s in cyc
                curr_assn[s] = prev_assn[swap_requests[s]]
                swaps_done[s] = true
            end
        end
    end

    return curr_assn
end


"""
Random serial dictatorship mechanism for one-sided matching (i.e. schools have neutral
preferences).
"""
function RSD(students_inv::Array{Int64,2}, capacities_in::Array{Int64,1})
    (m, n) = size(students_inv)
    @assert (m, ) == size(capacities_in) "Size mismatch between students_inv and capacities"
    capacities = copy(capacities_in)
    assn = ones(Int64, n)
    order = randperm(n)
    for s in order
        for k in 1:(m + 1)
            if k == m + 1
                assn[s] = m + 1
                break
            elseif capacities[students_inv[k, s]] > 0
                assn[s] = students_inv[k, s]
                capacities[assn[s]] -= 1
                break
            else
                k += 1
            end
        end
    end
    return assn
end


"""
Uses TTC to find the optimal one-sided school assignment. Seeds with RSD.
"""
function TTC_match(students, capacities; verbose=false::Bool)
    (m, n) == size(students)
    students_inv = mapslices(invperm, students, dims=1)
    assn_ = RSD(students_inv, capacities)
    assn = TTC(students_inv, assn_, verbose=verbose)
    return assn, [get(students, (c, s), m + 1) for (s, c) in enumerate(assn)]
end
