"""
Truncate a cutoff vector to the probability simplex. Useful because some methods
produce negative cutoffs while iterating.
"""
function cutbox(cut)
    return max.(0, min.(1, cut))
end


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

    cutoffs = cutbox(cutoffs)

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

    cutoffs = cutbox(cutoffs)

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
                         cutoffs     ::AbstractArray{<:AbstractFloat, 1},
                         )::AbstractArray{<:AbstractFloat, 1}
    (m, ) = size(qualities)
    @assert (m, ) == size(cutoffs) "Dim mismatch"
    cutoffs = cutbox(cutoffs)

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
    demands_MNL_onetest(qualities, cutoffs)

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
    @assert (m, ) == size(cutoffs) "Dim mismatch"

    cutoffs = cutbox(cutoffs)

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


# Currently unused.
"""
    numerical_admit_rate(B, cutoffs; n_points=1000)

Numerically compute the admissions rate for each school when school's
blends are the rows of B and scores are iid uniform. That is, compute
the probability that `B[c, :] * x >= cutoffs[c]`, where x is iid uniform.
Uses a meshgrid iterator with (about) `n_points` of evaluation.
"""
function numerical_admit_rate(B         ::AbstractArray{<:AbstractFloat, 2},
                              cutoffs   ::AbstractArray{<:AbstractFloat, 1};
                              n_points  ::Int=1000,
                              )::AbstractArray{<:AbstractFloat, 1}

    (m, n_tests) = size(B)
    density = Int(ceil(n_points ^ (1 / n_tests)))

    ran = range(0, stop=1, length=density)
    admits = zeros(Int, m)

    for x in Iterators.product(repeat([ran], n_tests)...), j in 1:m
        admits[j] += sum(B[j, k] * x[k] for k in 1:n_tests) >= cutoffs[j]
    end

    return admits ./ (density ^ n_tests)
end


"""
    demands_pMNL_ttests(qualities, profile_dist, blends, cutoffs;
                        n_points=10000, verbose=false, montecarlo=false)

Return demand for each school given a set of cutoffs and ignoring capacity, using
multinomial logit choice model with `p` student profiles and `t` test scores
shared among schools.

`qualities` is a `C` by `p` matrix, where `C` is the number of schools. Each column
of `qualities` gives the quality vector with respect to a student profile. This
generalizes `demands_MNL_iid()`.

If an applicant's test score vector is `x`, then her composite score at school
`c` is `blend[c, :] * x`, where `blend[c, :]` is a school-specific convex
combination of the `t` test scores, which we assume are iid uniform. This
generalizes `demands_MNL_onetest()`.

`n_points` is the approximate number of test points to use if `montecarlo` evaluation
is selected. Which method is more effecient depends on the problem dimensions, but
in general, for problems with many schools or tests, consider MC.

Satisfies WGS but not score independence, so equilibrium must be computed using
`nonatomic_tatonnement()`.
"""
function demands_pMNL_ttests(qualities      ::AbstractArray{<:AbstractFloat, 2},
                             profile_dist   ::AbstractArray{<:AbstractFloat, 1},
                             blends         ::AbstractArray{<:AbstractFloat, 2},
                             cutoffs        ::AbstractArray{<:AbstractFloat, 1};
                             montecarlo     ::Bool=false,
                             n_points       ::Int=10000,
                             verbose        ::Bool=false,
                             )::AbstractArray{<:AbstractFloat, 1}
    (m, p) = size(qualities)

    @assert (p, ) == size(profile_dist)     "Dim mismatch between qualities and profile_dist"
    @assert m == size(blends)[1]            "Dim mismatch between qualities and blends"
    @assert (m, ) == size(cutoffs)          "Dim mismatch between qualities and cutoffs"
    @assert sum(profile_dist) ≈ 1           "profile_dist doesn't sum to 1"
    @assert all(sum(blends, dims=2) .≈ 1)   "rows of blends don't sum to 1"

    cutoffs = cutbox(cutoffs)

    (m, t) = size(blends)

    demands = zeros(m)

    γ = exp.(qualities)

    if montecarlo
        density = Int(ceil(n_points ^ (1 / t)))
        sample_size = density ^ t   # approx. n_points

        # To use a grid instead of Monte Carlo. Tends to be less accurate because
        # of bias toward the edges of the cube.
        # ran = range(0, stop=1, length=density)

        # for x in Iterators.product(repeat([ran], t)...)
        for _ in 1:sample_size
            x = rand(t)
            verbose ? println("Student with scores:   ", x) : nothing
            # Consideration set
            C♯ = blends * [x...] .>= cutoffs
            verbose ? println("Has consideration set: ", C♯) : nothing

            if true in C♯
                for s in 1:p
                    coef = profile_dist[s] / sum(γ[d, s] * C♯[d] for d in 1:m)
                    verbose ? println("  For profile $s, coef is $coef") : nothing

                    for c in 1:m
                        if C♯[c]
                            demands[c] += γ[c, s] * coef
                            verbose ? println("    Go to school $c wp $(γ[c, s]) * coef = ",
                                              γ[c, s] * coef) : nothing
                        end
                    end
                end
            end
        end

        return demands ./ sample_size


    else        # Exact method
        bounds = vcat([HalfSpace(-col, 0.) for col in eachcol(I(t))],
                      [HalfSpace(1col, 1.) for col in eachcol(I(t))]) # Need 1 so I allocates

        for C♯ in powerset(1:m)
            if !isempty(C♯)
                # Probability of having this choice set is the volume of
                # this m-dimensional polyhedron.
                hspaces = [c in C♯ ? HalfSpace(-blends[c, :], -cutoffs[c]) :
                              HalfSpace( blends[c, :],  cutoffs[c])
                           for c in 1:m]
                poly = polyhedron(hrep(vcat(bounds, hspaces)))
                vol = volume(poly)

                if vol > 0
                    for s in 1:p
                        mult = vol * profile_dist[s] / sum(γ[C♯, s])

                        for c in C♯
                            demands[c] += mult * γ[c, s]
                        end
                    end
                end
            end
        end

        return demands
    end
end
