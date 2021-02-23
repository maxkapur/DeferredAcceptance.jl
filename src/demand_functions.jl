




"""
    assn_from_preflists(students_inv, students_dist, cutoffs;
                        return_demands=false)

Return assignment associated with given cutoffs and, if `return_demands=true`,
the demands. For demands only, `demands_preflists()` is faster. Ignores
capacity constraints.
"""
function assn_from_preflists(students_inv     ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
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
    demands_preflists(students, students_dist, cutoffs)

Return demand for each school given a set of cutoffs and ignoring capacity, using
given preference lists and assuming iid scores at each school.

Satifies WGS and score independence, so equilibrium can be computed using
`DA_nonatomic_lite()`.
"""
function demands_preflists(students      ::Union{AbstractArray{Int, 2}, AbstractArray{UInt, 2}},
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
    demands_MNL_iid(qualities, cutoffs)

Return demand for each school given a set of cutoffs and ignoring capacity, using
multinomial logit choice model and assuming scores are iid uniform (equivalent
to MTB when schools have no preferences).

Satifies WGS and score independence, so equilibrium can be computed using
`DA_nonatomic_lite()`.
"""
function demands_MNL_iid(qualities   ::AbstractArray{<:AbstractFloat, 1},
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
    demands_MNL_iid(qualities, cutoffs)

Return demand for each school given a set of cutoffs and ignoring capacity, using
multinomial logit choice model and assuming all schools use the same test (equivalent
to STB when schools have no preferences).

Satisfies WGS but not score independence, so equilibrium must be computed using
`nonatomic_tatonnement()`.
"""
function demands_MNL_onetest(qualities   ::AbstractArray{<:AbstractFloat, 1},
                                cutoffs   ::AbstractArray{<:AbstractFloat, 1},
                                )::AbstractArray{<:AbstractFloat, 1}
    (m, ) = size(qualities)
    @assert (m, )== size(cutoffs) "Dim mismatch"

    demands = zeros(m)

    sort_order = sortperm(cutoffs)
    cutoffs[sort_order]

    γ = exp.(qualities)
    demands = zeros(m)

    prob_of_th = diff([cutoffs[sort_order]; 1])

    for c in 1:m, d in c:m     # For each score threshold
        demands[sort_order[c]] += prob_of_th[d] *
                                  γ[sort_order[c]] / sum(γ[sort_order[1:d]])
    end

    return demands
end
