"""
A collection of functions for solving and analyzing school-choice problems.
See `examples/Tutorial.jl` for usage examples.

Some of the algorithms in this module are optimized for preference lists given
in "permutation" order, and others in "rating" order. Which order is used can be confirmed
by inspecting each function call. If the input calls for `students`, then the function
expects "rating" order, where if column `i` of students is `[3, 1, 2]`, this implies that
school 1 is `i`'s 3rd choice, school 2 is her 1st choice, and school 3 is her 2nd choice.
If the input calls for `students_inv`, then the expected input is `[2, 3, 1]`, which means
the same. These can be trivially related via `invperm()`.
"""
module DeferredAcceptance

using StatsBase
using LinearAlgebra
using Random
using Combinatorics
using Polyhedra

export singletiebreaking, multipletiebreaking, hybridtiebreaking, welfaretiebreaking, choiceaugmented
export deferredacceptance, nonatomicdeferredacceptance, nonatomicdeferredacceptance_iid, TTC, TTC_match, RSD,
       nonatomicsecant, nonatomictatonnement
export isstable, ismarketclearing, DA_rank_dist
export assignmentfrompreflists, demandfrompreflists, demandfromMNL_iid, demandfromMNL_singlescore,
       demandfrommixedMNL_tscores


include("demandfunctions.jl")
include("discretematch.jl")
include("nonatomic.jl")
include("tiebreakers.jl")


"""
    argsort(vec)

Associate each item in vec with its (descending) rank. Convenience wrapper of `sortperm()`.
"""
function argsort(vec::AbstractArray{<:Real, 1})::AbstractArray{Int, 1}
    return invperm(sortperm(vec))
end


end
