using DeferredAcceptance
using Test, Random


"""
Test if a discrete matching is stable. Ties OK.
"""
function is_stable(students, schools, capacities, assn)
    crit = trues(3)
    m, n = size(students)
    @assert (n, m) == size(schools)
    @assert (m,) == size(capacities)
    @assert (n,) == size(assn)
    x = falses(m, n)

    for (s, c) in enumerate(assn)
        if c <= m
            x[c, s] = true
        end
    end

    crit[1] = all(sum(x[:, s]) <= 1 for s in 1:n)                # Student feas
    crit[2] = all(sum(x[c, :]) <= capacities[c] for c in 1:m)    # School feas
    crit[3] = all(capacities[c] * x[c, s] +                      # Stability
                  capacities[c] * x[:, s]' * (students[:, s] .<= students[c, s]) +
                  x[c, :]' * (schools[:, c] .<= schools[s, c]) >= capacities[c]
                  for c in 1:m, s in 1:n)

    # for (test, pass) in zip(["Student feas.", "School feas.", "Stability"], crit)
    #     println("$test:  $pass")
    # end

    return all(crit)
end


@testset "TTC" begin
    # Basic
    assn = [3, 2, 1]
    students_inv = [1 1 3;
                    2 3 1;
                    3 2 2]
    @test TTC(students_inv, assn) == [1, 2, 3]

    # Lots of cycles
    assn = [1, 3, 2, 4]
    students_inv = [1 2 3 4;
                    2 1 4 3;
                    3 4 1 2;
                    4 3 2 1]
    @test TTC(students_inv, assn) == [1, 2, 3, 4]

    # Underdemanded
    assn = [1, 2]
    students_inv = [4 3;
                    2 1;
                    1 4;
                    3 2]
    @test TTC(students_inv, assn) == [2, 1]

    # Overdemanded
    assn = [1, 2, 2, 3]
    students_inv = [3 1 1 2;
                    1 2 3 1;
                    2 3 2 3]
    @test TTC(students_inv, assn) in ([3, 1, 2, 2], [3, 2, 1, 2])
end


@testset "Discrete" begin
    students = [3 3 4 3 4 3 3 3 3 4;
                4 4 3 4 3 4 4 4 4 3;
                2 1 2 2 2 1 2 2 2 2;
                1 2 1 1 1 2 1 1 1 1]
    schools = [1 5 7 5;
               1 1 1 1;
               5 1 1 1;
               5 1 1 1;
               10 9 7 8;
               1 5 4 5;
               5 1 4 1;
               8 5 7 8;
               8 9 7 8;
               1 5 4 5]

   schools_STB = STB(schools)
   schools_MTB = MTB(schools)
   schools_WTB = WTB(schools, students, rand(4)')
   capacities = [3, 2, 2, 3]

    @testset "Tiebreaking" begin
        for sch in [schools_STB, schools_MTB, schools_WTB], col in eachcol(sch)
            @test all(i in col for i in 1:size(schools)[1])
            # Add a test to see if the linear orders agree
        end
    end

    @testset "Small DA stability" begin
        for sch in [schools_STB, schools_MTB, schools_WTB]
            assn, ranks = DA(students, sch, [3, 2, 2, 3])
            @test is_stable(students, sch, capacities, assn)
        end
    end

    @testset "Big DA stability" begin
        samp = 10

        for _ in 1:samp
            n = rand(100:200)
            m = rand(20:40)
            students = hcat((randperm(m) for i in 1:n)...)
            schools = hcat((randperm(n) for i in 1:m)...)
            capacities = rand(5:10, m)

            assn, ranks = DA(students, schools, capacities)
            @test is_stable(students, schools, capacities, assn)
        end
    end
end

@testset "Nonatomic DA" begin
    samp = 10

    for _ in 1:samp
        n = rand(10:20)    # Number of student profiles in continuum
        m = rand(10:20)    # Number of schools
        α = 1 + rand()	   # Proportion by which overdemanded mkt is overdemanded
        β = 1 - rand() 	   # Proportion by which underdemanded mkt is underdemanded

        students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
        students_dist = rand(n)                         # Percentage of total student population
        students_dist /= sum(students_dist)             # associated with each profile

        capacities = rand(m)                            # Percentage of total student population
        capacities /= (α * sum(capacities))

        assn = DA_nonatomic(students, students_dist, nothing, capacities)[1]
        @test isapprox(sum(assn, dims=1), students_dist', atol=1e-2)

        capacities = rand(m)
        capacities /= (β * sum(capacities))
        assn = DA_nonatomic(students, students_dist, nothing, capacities)[1]
        @test isapprox(sum(assn, dims=1), students_dist', atol=1e-2)
    end
end
