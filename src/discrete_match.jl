"""
    DA(students, schools, capacities; verbose, rev)

Given an array of student preferences, where `students[i, j]` indicates the
rank that student `j` gave to school `i`, and an array of the transposed
shape indicating the schools' rankings over the students, uses
student-proposing DA to compute a stable assignment. Returns a vector of
schools corresponding to each student (`m + 1` indicates unassigned) and a
list of the student rankings associated with each match. Both sets of
preferences must be strict; use `STB()` or similar to preprocess
if your data does not satisfy this.

Set `rev=true` to use school-proposing DA instead.
"""
function DA(students        ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
            schools         ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
            capacities_in   ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}};
            verbose         ::Bool=false,
            rev             ::Bool=false)
    n, m = size(schools)
    @assert (m,) == size(capacities_in)  "Dim mismatch between schools and capacities"
    @assert (m, n) == size(students)     "Dim mismatch between schools and students"

    done = false
    nit = 0

    students_inv = mapslices(invperm, students, dims=1)
    schools_inv = mapslices(invperm, schools, dims=1)

    if rev == false
        capacities = vcat(capacities_in, n)  # For students who never get assigned
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
                    curr_assn[s] = get(students_inv, CartesianIndex(students[c, s] + 1, s), m + 1)
                end
            end
        end
        verbose ? println("DA terminated in $nit iterations") : nothing

        return curr_assn, [get(students, CartesianIndex(c, s), m + 1) for (s, c) in enumerate(curr_assn)]

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

        return students_assn, [get(students, CartesianIndex(c, s), m + 1) for (s, c) in enumerate(students_assn)]
    end
end

"""
    cycle_DFS(edges)

Given the edges of a graph (in dictionary form), uses depth-first search
to find cycles. Assumes all cycles are node disjoint.
"""
function cycle_DFS(edges::Dict{Int, Int})::Set{Array{Int,1}}
    if isempty(edges)
        return Set{Vector{Int}}()
    end

    nodes = union(edges...) # try union(keys(edges), values(edges))
    visited = Dict{Int, Bool}((i, false) for i in nodes)
    out = Set{Vector{Int}}()
    for nd in nodes
        if !visited[nd]
            curr_node = nd
            stack = Vector{Int}()
            while true
                if curr_node == :deadend
                    break
                elseif curr_node in stack
                    visited[curr_node] = true
                    push!(out, stack[findfirst( x -> x == curr_node, stack):end])
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
    TTC(students_inv, assn; verbose)

Uses the top-trading cycles allocation to find the market core, given an initial
assignment. The implementation follows Nisan et al. (2007), §10.3.
"""
function TTC(students_inv   ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
             assn           ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}};
             verbose        ::Bool=false,
            )::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}}
    (m, n) = size(students_inv)
    @assert (n, ) == size(assn) "Size mismatch between students_inv and assn"

    prev_assn = copy(assn)
    curr_assn = copy(assn)
    swaps_done = falses(n)

    for k in 1:(m - 1)
        verbose ? println("Searching for Pareto-improving cycles at rank $k") : nothing
        verbose ? println("Current assignment: $curr_assn") : nothing

        swap_requests = Dict{Int, Int}()
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
    RSD(students_inv, capacities)

Random serial dictatorship mechanism for one-sided matching (i.e. schools have neutral
preferences).
"""
function RSD(students_inv   ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
             capacities_in  ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}},
            )::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}}
    (m, n) = size(students_inv)
    @assert (m, ) == size(capacities_in) "Size mismatch between students_inv and capacities"

    capacities = copy(capacities_in)
    assn = ones(Int, n)

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
    TTC_match(students, capacities; verbose)

Uses TTC to find a heuritically optimal one-sided school assignment. Seeds with RSD.
"""
function TTC_match(students     ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                   capacities   ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}};
                   verbose      ::Bool=false,
                  )::Tuple{Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}},
                           Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}}}
    (m, n) = size(students)
    students_inv = mapslices(invperm, students, dims=1)
    assn_ = RSD(students_inv, capacities)
    assn = TTC(students_inv, assn_, verbose=verbose)

    return assn, [get(students, CartesianIndex(c, s), m + 1) for (s, c) in enumerate(assn)]
end


"""
    DA_rank_dist(students, schools, capacities; verbose, rev)

Convenience function that runs DA and outputs the cumulative rank
distribution data.
"""
function DA_rank_dist(students      ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                      schools       ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                      capacities    ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}};
                      verbose       ::Bool=false,
                      rev           ::Bool=false,
                     )::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}}
    (n, m) = size(schools)
    dist_cmap = countmap(DA(students, schools, capacities, verbose=verbose, rev=rev)[2])
    rank_hist = [get(dist_cmap, i, 0) for i in 1:m]

    return cumsum(rank_hist)
end


"""
    isstable(students, schools, capacities, assn; verbose)

Test if a discrete matching is stable. Allows for ties in school rankings.
"""
function isstable(students      ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                  schools       ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                  capacities    ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}},
                  assn          ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}};
                  verbose       ::Bool=false,
                 )::Bool
    crit = trues(3)
    (m, n) = size(students)
    @assert (n, m) == size(schools)   "Dim mismatch between students and schools"
    @assert (m,) == size(capacities)  "Dim mismatch between data and capacities"
    @assert (n,) == size(assn)        "Dim mismatch between data and assn"
    x = falses(m, n)

    for (s, c) in enumerate(assn)
        if c ≤ m
            x[c, s] = true
        end
    end

    crit[1] = all(sum(x[:, s]) ≤ 1 for s in 1:n)                # Student feas
    crit[2] = all(sum(x[c, :]) ≤ capacities[c] for c in 1:m)    # School feas
    crit[3] = all(capacities[c] * x[c, s] +                      # Stability
                  capacities[c] * x[:, s]' * (students[:, s] .≤ students[c, s]) +
                  x[c, :]' * (schools[:, c] .≤ schools[s, c]) ≥ capacities[c]
                  for c in 1:m, s in 1:n)

    res = all(crit)

    if verbose
        for (test, pass) in zip(["Student feas. ",
                                 "School feas.  ",
                                 "Stability     "], crit)
            println("$test:  $pass")
        end
    end

    return res
end
