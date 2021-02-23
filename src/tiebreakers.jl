# Functions that take in preference lists and return modified versions without ties.

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
