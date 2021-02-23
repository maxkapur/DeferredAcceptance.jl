#=  Abdulkadiroğlu et al. (2015).       =#

using DeferredAcceptance
using Random

function argsort(vec::AbstractArray{<:Real, 1})::AbstractArray{<:Real, 1}
    return invperm(sortperm(vec))
end

# We assume student volume equals total school capacity.
function target_doer(n, m, samp)

    CADA_disutil = zeros(0)
    STB_disutil = zeros(0)
    strat_disutil = zeros(0)

    for _ in 1:samp
        # All students share a master preference order, but they have utility perturbations
        # within it, so they "target" a school that they have less disutility with.
        students = repeat(randperm(m), 1, n)
        students_dist = rand(n)
        students_dist /= sum(students_dist)

        # Students' target schools
        targets = rand(1:m, n)

        # Each student has slightly better utility than expected at their target school.
        students_disutility = 0. .+ students
        for (s, c) in enumerate(targets)
            students_disutility[c, s] -= rand()
        end

        # Compare outcomes if one group of students simply lies and lists
        # their target school first.
        students_strat = copy(students)
        students_strat[targets[1], 1] = 0
        students_strat[:, 1] = argsort(students_strat[:, 1])

        # Schools begin with neutral preferences
        schools_in = ones(Int, n, m)
        capacities = rand(m)
        capacities /= sum(capacities)

        # Break ties
        schools_CADA = CADA(schools_in, targets)
        schools_STB = STB(schools_in)

        out_CADA = DA_nonatomic(students, students_dist, schools_CADA, capacities)
        out_STB = DA_nonatomic(students, students_dist, schools_STB, capacities)
        out_strat = DA_nonatomic(students_strat, students_dist, schools_STB, capacities)

        append!(CADA_disutil, sum(out_CADA[1][1:m, 1] .* students_disutility[:, 1]))
        append!(STB_disutil, sum(out_STB[1][1:m, 1] .* students_disutility[:, 1]))
        append!(strat_disutil, sum(out_strat[1][1:m, 1] .* students_disutility[:, 1]))
    end
    return CADA_disutil, STB_disutil, strat_disutil
end


function target_doer_discrete(m, cap, samp)
    n = m * cap

    CADA_disutil = zeros(0)
    STB_disutil = zeros(0)
    strat_disutil = zeros(0)

    for _ in 1:samp
        # All students share a master preference order, but they have utility perturbations
        # within it, so they "target" a school that they have less disutility with.
        students = repeat(randperm(m), 1, n)

        # Students' target schools
        targets = rand(1:m, n)

        # Each student has slightly better utility than expected at their target school.
        students_disutility = 0. .+ students
        for (s, c) in enumerate(targets)
            students_disutility[c, s] -= rand()
        end

        # Compare outcomes if student simply lies and lists
        # their target school first.
        students_strat = copy(students)
        students_strat[targets[1], 1] = 0
        students_strat[:, 1] = argsort(students_strat[:, 1])

        # Schools begin with neutral preferences
        schools_in = ones(Int, n, m)
        capacities = ones(Int, m) .* cap

        # Break ties
        schools_CADA = CADA(schools_in, targets)
        schools_STB = STB(schools_in)

        out_CADA = DA(students, schools_CADA, capacities)
        out_STB = DA(students, schools_STB, capacities)
        out_strat = DA(students_strat, schools_STB, capacities)

        append!(CADA_disutil, students_disutility[out_CADA[1][1]])
        append!(STB_disutil, students_disutility[out_STB[1][1]])
        append!(strat_disutil, students_disutility[out_strat[1][1]])
    end
    return CADA_disutil, STB_disutil, strat_disutil
end
