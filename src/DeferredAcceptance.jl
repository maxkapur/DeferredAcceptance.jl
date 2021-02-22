"""
A collection of functions for solving school-choice problems. See examples/Tutorial.jl
for usage examples.

Some of the algorithms in this module are optimized for preference lists given
in "permutation" order, and others in "rating" order. Which order is used can be confirmed
by inspecting each function call. If the input calls for students, then the function
expects "rating" order, where if column i of students is [3, 1, 2], this implies that
school 1 is i's 3rd choice, school 2 is her 1st choice, and school 3 is her 2nd choice.
If the input calls for students_inv, then the expected input is [2, 3, 1], which means
the same. These can be trivially related via Base.invperm().
"""
module DeferredAcceptance

using StatsBase
using Random
using Combinatorics

export STB, MTB, HTB, WTB, CADA                                    # Tiebreakers
export DA, DA_nonatomic, DA_nonatomic_lite, TTC, TTC_match, RSD    # Matchmakers
export isstable, ismarketclearing, argsort, DA_rank_dist,
       assn_from_cutoffs, demands_from_cutoffs                     # Utilities


"""
    argsort(vec)

Associate each item in vec with its (descending) rank. Convenience wrapper of `sortperm()`;
will probably be superseded by an official function eventually.
"""
function argsort(vec::AbstractArray{<:Real, 1})::AbstractArray{<:Real, 1}
    return invperm(sortperm(vec))
end


"""
    STB(arr)

Given schools' ranked preference lists, which may contain ties,
break ties using the single tiebreaking rule by generating
a column of floats, adding this column to each column of `arr`,
and ranking the result columnwise.
"""
function STB(arr::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}})
    add = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])

    return mapslices(argsort, arr + add, dims=1)
end


"""
    MTB(arr)

Given schools' ranked preference lists, which may contain ties,
break ties using the multiple tiebreaking rule by adding to `arr`
a column of random floats having the same shape, then ranking the
result columnwise.
"""
function MTB(arr::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}})
    # Given schools' ranked preference lists, which contain ties,
    # breaks ties using the multiple tiebreaking rule by adding a
    # float to each entry and ranking the result columnwise.
    add = rand(Float64, size(arr))

    return mapslices(argsort, arr + add, dims=1)
end


"""
    HTB(arr, blend; return_add)

Given schools' ranked preference lists, which may contain ties,
break ties using a hybrid tiebreaking rule as indicated by
entries of `blend`. `blend` should be a row vector with one entry
on ``[0, 1]`` for each column in `arr`. 0 means that school will use STB,
1 means MTB, and a value in between yields a convex combination
of the rules, which produces interesting results but has not yet
been theoretically analyzed. If `blend` is a scalar, use the same value
at all schools. Undefined behavior for values outside
the ``[0, 1]`` interval.

`return_add` is a `Bool` indicating whether to return the tiebreaking numbers
(lottery numbers) as second entry of output tuple.
"""
function HTB(arr        ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
             blend      ::Union{<:AbstractFloat, AbstractArray{<:AbstractFloat}}=0.;
             return_add ::Bool=false)
    @assert size(blend) == () || size(blend) == (1, size(arr)[2]) "Dim mismatch between blend and arr"

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
    CADA(arr, targets, blend_target=0, blend_others=0; return_add)

Tiebreaker function for the choice-augmented deferred acceptance
mechanism described by Abdulkadiroğlu et al. (2015). Primary tiebreaking
is accomplished by allowing students to signal a target school; secondary
ties are broken by independent STB lotteries in the target and other
schools (by default). Or, indicate another mechanism by configuring
`blend_target` and `blend_others`, following `?HTB`.

`return_add` is a `Bool` indicating whether to return the tiebreaking numbers
(lottery numbers) as second entry of output tuple.
"""
function CADA(arr           ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
              targets       ::Union{AbstractArray{Int, 1}, AbstractArray{UInt, 1}},
              blend_target  ::Union{<:AbstractFloat, AbstractArray{<:AbstractFloat}}=0.,
              blend_others  ::Union{<:AbstractFloat, AbstractArray{<:AbstractFloat}}=0.;
              return_add    ::Bool=false)
    @assert (size(arr)[1], ) == size(targets)           "Dim mismatch between arr and targets"
    @assert size(blend_target) == () ||
            size(blend_target) == (1, size(arr)[2])     "Dim mismatch between blend_target and arr"
    @assert size(blend_others) == () ||
            size(blend_others) == (1, size(arr)[2])     "Dim mismatch between blend_others and arr"

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
    WTB(students, schools, blend; equity, return_add)

Given schools' ranked preference lists, which contain ties,
first break ties using student welfare, then break subsequent
ties using a hybrid tiebreaking rule indicated by entries of `blend`.
Or in `equity=true` mode, break ties by minimizing student welfare, which
gives priority in DA to students whose current assignment is poor.
See `?HTB` for an explanation of how to configure `blend`.

`blend=0` is known as the Boston mechanism.

`return_add` is a `Bool` indicating whether to return the tiebreaking numbers
(lottery numbers) as second entry of output tuple.
"""
function WTB(students   ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
             schools    ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
             blend      ::Union{<:AbstractFloat, AbstractArray{<:AbstractFloat}}=0.;
             equity     ::Bool=false,
             return_add ::Bool=false)

    @assert size(schools) == size(students')        "Dim mismatch between students and schools"
    @assert size(blend) == () ||
            size(blend) == (1, size(students)[1])   "Dim mismatch between blends and arr"

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
    assn_from_cutoffs(students_inv, students_dist, cutoffs;
                         return_demands=false)

Return assignment associated with given cutoffs and, if `return_demands=true`,
the demands. For demands only, `demands_from_cutoffs()` is faster. Ignores
capacity constraints. Includes repeated multiplication, so not very numerically
accurate, especially when number of schools is high.
"""
function assn_from_cutoffs(students_inv     ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                           students_dist    ::AbstractArray{<:AbstractFloat, 1},
                           cutoffs          ::AbstractArray{<:AbstractFloat, 1};
                           return_demands   ::Bool=false)
    (m, n) = size(students_inv)
    @assert size(cutoffs) == (m, )        "Dim mismatch between students_inv and cutoffs"
    @assert size(students_dist) == (n, )  "Dim mismatch between students_inv and students_dist"

    assn = zeros(m + 1, n)
    unassigned = copy(students_dist)

    for s in 1:n, c in 1:m
        got_in = unassigned[s] * (1 - cutoffs[students_inv[c, s]])
        assn[students_inv[c, s], s] += got_in
        unassigned[s] -= got_in
    end

    assn[end, :] = unassigned

    if return_demands    # For testing purposes
        demands = sum(assn[1:end - 1, :], dims=2)
        return assn, demands
    else
        return assn
    end
end


"""
    demands_from_cutoffs(students, students_dist, cutoffs)

Return demand for each school given a set of cutoffs and ignoring capacity, using
given preference lists.
"""
function demands_from_cutoffs(students      ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                              students_dist ::AbstractArray{<:AbstractFloat, 1},
                              cutoffs       ::AbstractArray{<:AbstractFloat, 1},
                              )::AbstractArray{<:AbstractFloat, 1}
    (m, n) = size(students)
    @assert size(cutoffs) == (m, )        "Dim mismatch between students and cutoffs"
    @assert size(students_dist) == (n, )  "Dim mismatch between students and students_dist"

    demands = [(1 - cutoffs[c]) * sum(students_dist[s] *
               prod(cutoffs[students[:, s] .< students[c, s]]) for s in 1:n)
               for c in 1:m]

    return demands
end


"""
    demands_from_cutoffs(qualities, cutoffs)

Return demand for each school given a set of cutoffs and ignoring capacity, using
multinomial logit choice model and assuming scores are iid uniform (equivalent
to MTB when schools have no preferences).
"""
function demands_from_cutoffs(qualities   ::AbstractArray{<:AbstractFloat, 1},
                              cutoffs   ::AbstractArray{<:AbstractFloat, 1},
                              )::AbstractArray{<:AbstractFloat, 1}
    (m, ) = size(qualities)
    @assert (m, )== size(cutoffs) "Dim mismatch"
    demands = zeros(m)

    γ = exp.(qualities)

    for c in 1:m
        C_minus_c = setdiff(1:m, c)
        for C♯ ∈ powerset(C_minus_c)
            demands[c] += prod(e in C♯ ? 1 - cutoffs[e] : cutoffs[e] for e in C_minus_c) /
                          (γ[c] + sum(AbstractFloat[γ[d] for d in C♯]))
        end
        demands[c] *= (1 - cutoffs[c]) * γ[c]
    end

    return demands
end


"""
    DA_nonatomic_lite(students, students_dist, capacities;
                      verbose, rev, tol)

Nonatomic (continuous) analogue of `DA()`, simplified to return only the score cutoffs
associated with each school, after Azevedo and Leshno (2016).

Students are a continuum of profiles distributed over a fixed set of student preference
lists, and school capacities are fractions of the total student population. Returns
only the cutoffs; use `assn_from_cutoffs()` to get the match array or `DA_nonatomic()`
for a wrapper function.
"""
function DA_nonatomic_lite(students         ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                           students_dist    ::AbstractArray{<:AbstractFloat, 1},
                           capacities       ::AbstractArray{<:AbstractFloat, 1};
                           verbose          ::Bool=false,
                           rev              ::Bool=false,
                           tol              ::AbstractFloat=1e-12,
                           )::AbstractArray{<:AbstractFloat, 1}
    (m, n) = size(students)

    @assert (m,) == size(capacities)     "Dim mismatch between students and capacities"
    @assert (n,) == size(students_dist)  "Dim mismatch between students and students_dist"

    nit = 0
    done = false

    if !rev
        cutoffs = zeros(m)

        while done==false
            nit += 1
            done = true

            verbose ? println("\nRound $nit") : nothing

            demands = demands_from_cutoffs(students, students_dist, cutoffs)

            for (c, d) in enumerate(demands)
                if d - capacities[c] > tol
                    verbose ? println("  Demand at school $c was $d > capacity $(capacities[c])") : nothing
                    verbose ? println("    Old cutoff:  ", cutoffs[c]) : nothing
                    done = false
                    cutoffs[c] += (1 - capacities[c] / demands[c]) * (1 - cutoffs[c])
                    verbose ? println("    New cutoff:  ", cutoffs[c]) : nothing
                end
            end
        end

    else        # reverse
        # Selfish cutoff: Each school assumes it's everyone's first choice.
        # Thus this is the highest possible cutoff.
        cutoffs = 1 .- capacities ./ sum(students_dist)

        while done==false
            nit += 1
            done = true

            verbose ? println("\nRound $nit") : nothing

            demands = demands_from_cutoffs(students, students_dist, cutoffs)

            for (c, d) in enumerate(demands)
                if cutoffs[c] > 0 && capacities[c] - d > tol   # If school has lots of remaining capacity
                    verbose ? println("  Demand at school $c was $d < capacity $(capacities[c])") : nothing
                    verbose ? println("    Old cutoff:  ", cutoffs[c]) : nothing
                    done = false
                    cutoffs[c] = max(cutoffs[c] + (1 - capacities[c] / demands[c]) * (1 - cutoffs[c]), 0)
                    verbose ? println("    New cutoff:  ", cutoffs[c]) : nothing
                end
            end
        end
    end

    return cutoffs
end



"""
    DA_nonatomic_lite(demand, capacities;
                      verbose, mode=:forward, tol, β, maxit)

Nonatomic (continuous) analogue of `DA()`, simplified to return only the score cutoffs
associated with each school, where demand is given by an arbitrary function that
takes score cutoffs as inputs.

`mode` should be one of:
 -  `:forward`, `:fwd` (forward DA)
 -  `:reverse`, `:rev` (reverse DA)
 -  `:tatonnement`, `:walras`, `:groping`, `:auction` (tâtonnement process; more robust but slower)

In the latter case, `β` is a step size parameter, where the step size is `1 / nit ^ β`,
where `nit` is the iteration number.
"""
function DA_nonatomic_lite(demand      ::Function,
                           capacities  ::AbstractArray{<:AbstractFloat, 1};
                           verbose     ::Bool=false,
                           mode        ::Symbol=:fwd,
                           tol         ::AbstractFloat=1e-12,
                           β           ::AbstractFloat=1e-3,
                           maxit       ::Int=500,
                          )::AbstractArray{<:AbstractFloat, 1}

    (m, ) = size(capacities)

    @assert mode in [:forward, :fwd,
                     :reverse, :rev,
                     :tatonnement, :walras, :groping, :auction]

    if mode in [:forward, :fwd]
        cutoffs = zeros(m)

        for nit in 1:maxit
            done = true

            verbose ? println("\nRound $nit") : nothing

            demands = demand(cutoffs)

            for (c, d) in enumerate(demands)
                if d - capacities[c] > tol
                    verbose ? println("  Demand at school $c was $d > capacity $(capacities[c])") : nothing
                    verbose ? println("    Old cutoff:  ", cutoffs[c]) : nothing
                    done = false
                    cutoffs[c] += (1 - capacities[c] / demands[c]) * (1 - cutoffs[c])
                    verbose ? println("    New cutoff:  ", cutoffs[c]) : nothing
                end
            end

            if done == true
                break
            elseif nit == maxit
                @warn "Exceeded maximum number of iterations; try tuning parameters"
            end
        end

    elseif mode in [:reverse, :rev]        # reverse
        # Selfish cutoff: Each school assumes it's everyone's first choice.
        # Thus this is the highest possible cutoff.
        cutoffs = 1 .- capacities

        for nit in 1:maxit
            done = true
            verbose ? println("\nRound $nit") : nothing

            demands = demand(cutoffs)

            for (c, d) in enumerate(demands)
                if cutoffs[c] > 0 && capacities[c] - d > tol   # If school has lots of remaining capacity
                    verbose ? println("  Demand at school $c was $d < capacity $(capacities[c])") : nothing
                    verbose ? println("    Old cutoff:  ", cutoffs[c]) : nothing
                    done = false
                    cutoffs[c] = max(cutoffs[c] + (1 - capacities[c] / demands[c]) * (1 - cutoffs[c]), 0)
                    verbose ? println("    New cutoff:  ", cutoffs[c]) : nothing
                end
            end

            if done == true
                break
            elseif nit == maxit
                @warn "Exceeded maximum number of iterations; try tuning parameters"
            end
        end

    else         # Tatonnement
        cutoffs = rand(m)

        β = .001

        for nit in 1:maxit
            verbose ? println("Round $nit") : nothing
            excess_demand = demand(cutoffs) - capacities

            α = 1 / nit ^ β

            verbose ? println("  Cutoff vector: ", round.(cutoffs, digits = 4)) : nothing
            verbose ? println("  Excess demand: ", round.(excess_demand, digits = 4)) : nothing
            verbose ? println("  Step size:     ", α) : nothing

            new_cutoffs = max.(0, min.(1, cutoffs + α * excess_demand))

            if nit == maxit
                @warn "Exceeded maximum number of iterations; try tuning parameters"
            end

            if isapprox(new_cutoffs, cutoffs, atol=tol)
                cutoffs = new_cutoffs
                break
            else
                cutoffs = new_cutoffs
            end
        end
    end

    return cutoffs
end


"""
    DA_nonatomic(students, students_dist, schools, capacities;
                 verbose, rev, return_cutoffs, tol)

Nonatomic (continuous) analogue of `DA()`. Students are a continuum of profiles distributed
over a fixed set of student preference lists, and school capacities are fractions of the total
student population. School preferences are optional. If you pass `schools=nothing`, it assumes
that student preferability is uncorrelated with student profile, and the schools simply accept
the best students from each profile. This is the more realistic case; the algorithm is not
incentive compatible if schools can favor students based on the students' preferences.

`rev` is a placeholder and reverse mode has not yet been implemented.

Returns a tuple expressing the assignment as an array, where the `[i, j]`` entry indicates the
measure of students having preference list `j` admitted to school `i` and `i + 1` indicates nonassignment,
and a vector giving the average utility in each preference list.

Set `return_cutoffs=true` to get the score cutoffs associated with the match, after Azevedo
and Leshno (2016). These cutoffs are the state space of the algorithm and therefore more
numerically accurate than the assignment array itself. To get only the cutoffs, use
`DA_nonatomic_lite()` (which this function wraps).
"""
function DA_nonatomic(students          ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                      students_dist     ::AbstractArray{<:AbstractFloat, 1},
                      schools           ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}, Nothing},
                      capacities_in     ::AbstractArray{<:AbstractFloat, 1};
                      verbose           ::Bool=false,
                      rev               ::Bool=false,
                      return_cutoffs    ::Bool=false,
                      tol               ::AbstractFloat=1e-12)
    m, n = size(students)
    @assert (m,) == size(capacities_in)         "Dim mismatch between students and capacities"
    @assert (n,) == size(students_dist)         "Dim mismatch between students and students_dist"
    @assert schools == nothing || rev == false  "Reverse unavailable when schools have prefs"

    done = false
    nit = 0

    if schools == nothing                    # Homogenous student preferability
        students_inv = mapslices(invperm, students, dims=1)

        cutoffs = DA_nonatomic_lite(students, students_dist, capacities_in;
                                    verbose=verbose, rev=rev, tol=tol)
        curr_assn = assn_from_cutoffs(students_inv, students_dist, cutoffs)

        verbose ? println("Cutoffs: ", cutoffs) : nothing
        DA_rank_dist = sum([col[students_inv[:, i]] for (i, col) in enumerate(eachcol(curr_assn))])
        append!(DA_rank_dist, sum(curr_assn[m + 1, :]))

        if return_cutoffs
            return curr_assn, DA_rank_dist, cutoffs
        else
            return curr_assn, DA_rank_dist
        end

    else            # Schools have preference order over student types
        @assert (n, m) == size(schools) "Dim mismatch between schools and students"

        students_inv = mapslices(invperm, students, dims=1)
        schools_inv = mapslices(invperm, schools, dims=1)
        if rev == false
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
                            if capacity_remaining ≥ curr_assn[c, s]
                                capacity_remaining -= curr_assn[c, s]
                                verbose ? print("\n    Accepting demand of ", curr_assn[c, s],
                                                " from profile $s; remaining capacity ",
                                                capacity_remaining) : nothing
                            else
                                done = false
                                prop_to_reject = 1 - capacity_remaining / curr_assn[c, s]
                                verbose ? print("\n    Demand from profile $s was ", curr_assn[c, s],
                                        "; rejecting $prop_to_reject of it") : nothing
                                next_school_id = get(students_inv, CartesianIndex(students[c, s] + 1, s), m + 1)
                                curr_assn[next_school_id, s] += prop_to_reject * curr_assn[c, s]
                                curr_assn[c, s] *= 1 - prop_to_reject
                                capacity_remaining = 0
                            end
                        end
                    end
                end
            end

            verbose ? println("\nDA terminated in $nit iterations") : nothing
            DA_rank_dist = sum([col[students_inv[:, i]] for (i, col) in enumerate(eachcol(curr_assn))])
            append!(DA_rank_dist, sum(curr_assn[m + 1, :]))

            return curr_assn, DA_rank_dist

        else
            print("Reverse hasn't been implemented yet")
        end
    end
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


"""
    ismarketclearing(students, students_dist, capacities, cutoffs;
                     tol=1e-6)

Check if a set of cutoffs is market clearing with respect to the given nonatomic
market. Nonatomic analogue of `isstable()` by Lemma 1 of Azevedo and Leshno (2016).
"""
function ismarketclearing(students      ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
                          students_dist ::AbstractArray{<:AbstractFloat, 1},
                          capacities    ::AbstractArray{<:AbstractFloat, 1},
                          cutoffs       ::AbstractArray{<:AbstractFloat, 1};
                          verbose       ::Bool=false,
                          tol           ::AbstractFloat=1e-6,
                         )::Bool
    demands = demands_from_cutoffs(students, students_dist, cutoffs)

    crit = falses(2)

    crit[1] = isapprox(sum(demands), min(sum(students_dist), sum(capacities)), atol=tol)
    crit[2] = all(demands .≤ capacities .+ tol)

    res = all(crit)

    if verbose
        for (test, pass) in zip(["Market clearing ",
                                 "School feas.    "], crit)
            println("$test:  $pass")
        end
    end

    return res
end


"""
    ismarketclearing(qualities, capacities, cutoffs;
                     tol=1e-6)

Check if a set of cutoffs is market clearing with respect to the given nonatomic
market. Nonatomic analogue of `isstable()` by Lemma 1 of Azevedo and Leshno (2016).
"""
function ismarketclearing(qualities     ::AbstractArray{<:AbstractFloat, 1},
                          capacities    ::AbstractArray{<:AbstractFloat, 1},
                          cutoffs       ::AbstractArray{<:AbstractFloat, 1};
                          verbose       ::Bool=false,
                          tol           ::AbstractFloat=1e-6,
                         )::Bool

    demands = demands_from_cutoffs(qualities, cutoffs)

    crit = falses(2)

    crit[1] = isapprox(sum(demands), min(1., sum(capacities)), atol=tol)
    crit[2] = all(demands .≤ capacities .+ tol)

    res = all(crit)

    if verbose
        for (test, pass) in zip(["Market clearing ",
                                 "School feas.    "], crit)
            println("$test:  $pass")
        end
    end

    return res
end


"""
    ismarketclearing(qualities, capacities, cutoffs;
                     tol=1e-6)

Check if a set of cutoffs is market clearing with respect to the given nonatomic
market. Nonatomic analogue of `isstable()` by Lemma 1 of Azevedo and Leshno (2016).
"""
function ismarketclearing(demand        ::Function,
                          capacities    ::AbstractArray{<:AbstractFloat, 1},
                          cutoffs       ::AbstractArray{<:AbstractFloat, 1};
                          verbose       ::Bool=false,
                          tol           ::AbstractFloat=1e-6,
                         )::Bool

    demands = demand(cutoffs)

    crit = falses(2)

    crit[1] = isapprox(sum(demands), min(1., sum(capacities)), atol=tol)
    crit[2] = all(demands .≤ capacities .+ tol)

    res = all(crit)

    if verbose
        for (test, pass) in zip(["Market clearing ",
                                 "School feas.    "], crit)
            println("$test:  $pass")
        end
    end

    return res
end


end
