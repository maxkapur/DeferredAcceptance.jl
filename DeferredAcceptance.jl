using StatsBase
using Random


"""
Returns a boolean vector shaped like input indicating where the
n largest entries are located.
"""
function nlargest(vec, n)
    inp = copy(vec)
    out = zeros(Bool, length(vec))
    for i in 1:n
        am = argmax(inp)
        out[am] = true
        inp[am] = -1
    end
    return out
end


function argsort(vec)
    return invperm(sortperm(vec))
end


"""
Given schools' ranked preference lists, which contain ties, 
breaks ties using the single tiebreaking rule by generating
a column of floats, adding this column to each column of arr,
and ranking the result columnwise.
"""
function STB(arr)
    add = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])
    return mapslices(argsort, arr + add, dims=1)
end


function MTB(arr)
	# Given schools' ranked preference lists, which contain ties, 
	# breaks ties using the multiple tiebreaking rule by adding a 
	# float to each entry and ranking the result columnwise.
    add = rand(Float64, size(arr))
    return mapslices(argsort, arr + add, dims=1)
end


"""
Given schools' ranked preference lists, which contain ties, 
breaks ties using a hybrid tiebreaking rule as indicated by 
entries of blend. Blend should be a row vector with one entry
on [0, 1] for each col in arr. 0 means that school will use STB,
1 means MTB, and a value in between yields a convex combination
of the rules, which produces interesting results but has not yet
been theoretically analyzed. If blend is a scalar, the same value
will be used at all schools. Undefined behavior for values outside
[0, 1] interval.
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


function DA(students::Array{Int64, 2}, schools::Array{Int64, 2},
            capacities_in::Array{Int64, 1}, verbose=false::Bool)
    students_inv = mapslices(invperm, students, dims=1)
    n, m = size(schools)
    
    capacities = vcat(capacities_in, n)  # For students who never get assigned

    curr_assn = students_inv[1, :]
    done = false
    nit = 0
    
    while !done
        nit += 1
        verbose ? println("Round $nit") : nothing
        done = true
        proposals = zeros(Bool, n, m + 1)
        for (s, C) in enumerate(curr_assn)
            proposals[s, C[1]] = true
        end
        for (c, S) in enumerate(eachcol(proposals))
            n_rejects = sum(S)
            if n_rejects > capacities[c]
                rejections = nlargest(S .* schools[:, c], n_rejects - capacities[c])
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
end


function rank_dist(students, schools, capacities, verbose=false::Bool)
    n, m = size(schools)
    dist_cmap = countmap(DA(students, schools, capacities, verbose)[2])
    rank_hist = [get(dist_cmap, i, 0) for i in 1:m]
    return cumsum(rank_hist)
end
