"""
    DA_nonatomic_lite(students, students_dist, capacities;
                      verbose, rev, tol)

Nonatomic (continuous) analogue of `DA()`, simplified to return only the score cutoffs
associated with each school, after Azevedo and Leshno (2016).

Students are a continuum of profiles distributed over a fixed set of student preference
lists, and school capacities are fractions of the total student population. Returns
only the cutoffs; use `assn_from_preflists()` to get the match array or `DA_nonatomic()`
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

            demands = demands_preflists(students, students_dist, cutoffs)

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
        cutoffs = max.(0., 1 .- capacities ./ sum(students_dist))

        while done==false
            nit += 1
            done = true

            verbose ? println("\nRound $nit") : nothing

            demands = demands_preflists(students, students_dist, cutoffs)

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
                      verbose, rev, tol, maxit)

Nonatomic (continuous) analogue of `DA()`, simplified to return only the score cutoffs
associated with each school, where demand is given by an arbitrary function that
takes score cutoffs as inputs. This algorithm assumes that student preferability
is independent at each school and that the demand function satisfies weak gross
substitutability. To relax the former assumption, use `nonatomic_tatonnement()`.
"""
function DA_nonatomic_lite(demand      ::Function,
                           capacities  ::AbstractArray{<:AbstractFloat, 1};
                           verbose     ::Bool=false,
                           rev         ::Bool=false,
                           tol         ::AbstractFloat=1e-12,
                           maxit       ::Int=500,
                           )::AbstractArray{<:AbstractFloat, 1}

    (m, ) = size(capacities)

    if !rev
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

    else      # reverse
        # Selfish cutoff: Each school assumes it's everyone's first choice.
        # Thus this is the highest possible cutoff.
        cutoffs = max.(0., 1 .- capacities)

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

When school preferences are not `nothing`, `rev` is a placeholder and reverse mode
has not yet been implemented.

Returns a tuple expressing the assignment as an array, where the `[i, j]`` entry indicates the
measure of students having preference list `j` admitted to school `i` and `i + 1` indicates nonassignment,
and a vector giving the average utility in each preference list.

Set `return_cutoffs=true` to get the score cutoffs associated with the match, after Azevedo
and Leshno (2016). These cutoffs are the state space of the algorithm and therefore more
numerically accurate than the assignment array itself. To get only the cutoffs, use
`DA_nonatomic_lite()` (which this function wraps) or `nonatomic_tatonnement()` (which is not
a DA algorithm but can compute equilibrium cutoffs in a wider range of scenarios).
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
        curr_assn = assn_from_preflists(students_inv, students_dist, cutoffs)

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
            error("No reverse mode yet when schools have pref over students")
        end
    end
end


"""
    nonatomic_secant(demand, capacities; verbose, tol, maxit)

Search for a market-clearing cutoff vector using a modified secant method with
tâtonnement as a fallback when change in demand is small. Less theoretically
legit than `nonatomic_tatonnement()` but tends to make fewer calls to `demand()`.

`demand` is a school demand function that takes cutoffs as input.
"""
function nonatomic_secant(demand      ::Function,
                          capacities  ::AbstractArray{<:AbstractFloat, 1};
                          verbose     ::Bool=false,
                          tol         ::AbstractFloat=1e-12,
                          maxit       ::Int=500,
                          )::AbstractArray{<:AbstractFloat, 1}

    (m, ) = size(capacities)

    UB = max.(0., 1 .- capacities)
    old_cutoffs = rand(m) .* UB
    new_cutoffs = rand(m) .* UB
    # old_cutoffs = zeros(m)
    # new_cutoffs = copy(UB)
    new_excess_demand = demand(old_cutoffs) - capacities

    for nit in 1:maxit
        verbose ? println("Round $nit") : nothing
        old_excess_demand, new_excess_demand = new_excess_demand, demand(new_cutoffs) - capacities

        verbose ? println("  Old cutoff vector: ", round.(old_cutoffs, digits = 4)) : nothing
        verbose ? println("  New cutoff vector: ", round.(new_cutoffs, digits = 4)) : nothing
        verbose ? println("  Excess demand: ", round.(new_excess_demand, digits = 4)) : nothing

        for c in 1:m
            # Fall back to tatonnement when denominator of secant update would
            # be close to zero.
            if isapprox(old_excess_demand[c], new_excess_demand[c], atol=tol)
                verbose ? println("    Updating school $c by tâtonnement because its demand didn't change") : nothing
                old_cutoffs[c], new_cutoffs[c] =
                    new_cutoffs[c], max(0, min(UB[c], new_cutoffs[c] + new_excess_demand[c]))
            else
                old_cutoffs[c], new_cutoffs[c] =
                    new_cutoffs[c],
                    max(0, min(UB[c],
                                 begin
                                     new_cutoffs[c] -
                                     new_excess_demand[c] * (new_cutoffs[c] - old_cutoffs[c]) /
                                     (new_excess_demand[c] - old_excess_demand[c])
                                 end ))
            end
        end

        if nit == maxit
            @warn "Exceeded maximum number of iterations; try tuning parameters"
        end

        # Check if market clears.
        if isapprox(new_cutoffs' * new_excess_demand, 0, atol=tol) &&
           all(new_excess_demand .≤ 0 + tol)
            break
        end
    end

    return cutbox(new_cutoffs)
end


"""
    nonatomic_tatonnement(demand, capacities; verbose, tol, β, maxit)

Search for a market-clearing cutoff vector using a modified tâtonnement process.
Analogous to `DA_nonatomic_lite()` but more robust; `nonatomic_tatonnement()`
converges for any demand function that satisfies weak gross substitutability.

`demand` is a school demand function that takes cutoffs as input.

`β` is a step size parameter, where the step size is `1 / nit ^ β`, where `nit`
is the iteration number.
"""
function nonatomic_tatonnement(demand      ::Function,
                               capacities  ::AbstractArray{<:AbstractFloat, 1};
                               verbose     ::Bool=false,
                               tol         ::AbstractFloat=1e-12,
                               β           ::AbstractFloat=1e-3,
                               maxit       ::Int=500,
                               )::AbstractArray{<:AbstractFloat, 1}

    (m, ) = size(capacities)

    UB = max.(0., 1 .- capacities)
    cutoffs = rand(m) .* UB

    for nit in 1:maxit
        verbose ? println("Round $nit") : nothing
        excess_demand = demand(cutoffs) - capacities

        α = 1 / nit ^ β

        verbose ? println("  Cutoff vector: ", round.(cutoffs, digits = 4)) : nothing
        verbose ? println("  Excess demand: ", round.(excess_demand, digits = 4)) : nothing
        verbose ? println("  Step size:     ", α) : nothing

        new_cutoffs = max.(0, min.(UB, cutoffs + α * excess_demand))

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

    return cutoffs
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
    demands = demands_preflists(students, students_dist, cutoffs)

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

    demands = demands_MNL_iid(qualities, cutoffs)

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
