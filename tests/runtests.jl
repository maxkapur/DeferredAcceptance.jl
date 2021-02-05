using DeferredAcceptance
using Test, Random

@testset "Throws" begin
    @testset "Dim mismatches" begin
        @test_throws AssertionError DA([1 2; 2 1], [1 2; 2 1; 3 3], [1, 1, 1])
        @test_throws AssertionError TTC_match([1 2; 2 1; 3 3], [5, 6])
        @test_throws AssertionError CADA([1 2; 2 1; 3 3], [1, 2])
    end
end


@testset "Discrete" begin
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
    schools_WTB = WTB(students, schools, rand(4)')
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

    @testset "Big DA stability, fwd" begin
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

    @testset "Big DA stability, rev" begin
        samp = 10

        for _ in 1:samp
            n = rand(100:200)
            m = rand(20:40)
            students = hcat((randperm(m) for i in 1:n)...)
            schools = hcat((randperm(n) for i in 1:m)...)
            capacities = rand(5:10, m)

            assn, ranks = DA(students, schools, capacities, rev=true)
            @test is_stable(students, schools, capacities, assn)
        end
    end

    @testset "CADA stability" begin
        samp = 10

        for _ in 1:samp
            m = rand(10:20)
            cap = rand(5:10)
            n = m * cap

            students = repeat(randperm(m), 1, n)
            targets = rand(1:m, n)

            schools = ones(Int, n, m)
            capacities = ones(Int, m) .* cap

            schools_CADA = CADA(schools, targets)
            assn, rdist = DA(students, schools_CADA, capacities)
            @test is_stable(students, schools, capacities, assn)
        end
    end
end

@testset "Nonatomic DA" begin
    samp = 10

    @testset "Azevedo and Leshno (2016)" begin
        students = [1 2; 2 1]
        students_dist = [0.5, 0.5]
        capacities = [0.25, 0.5]

        assn, rdist, cutoffs = DA_nonatomic(students, students_dist, nothing, capacities;
                                            tol=1e-14, return_cutoffs=true)

        @test cutoffs ≈ [√17 + 1, √17 - 1] ./ 8
    end

    @testset "No school prefs" begin
        for _ in 1:samp
            n = rand(10:20)    # Number of student profiles in continuum
            m = rand(10:20)    # Number of schools
            α = 1 + rand()       # Proportion by which overdemanded mkt is overdemanded
            β = 1 - rand()        # Proportion by which underdemanded mkt is underdemanded

            students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
            students_dist = rand(n)                         # Percentage of total student population
            students_dist /= sum(students_dist)             # associated with each profile

            capacities = rand(m)                            # Percentage of total student population
            capacities /= (α * sum(capacities))

            assn = DA_nonatomic(students, students_dist, nothing, capacities; tol=1e-14)[1]
            @test sum(assn, dims=1) ≈ students_dist'
            @test sum(assn, dims=2)[1:end - 1] ≤ capacities .+ 1e-8

            capacities = rand(m)
            capacities /= (β * sum(capacities))
            assn = DA_nonatomic(students, students_dist, nothing, capacities; tol=1e-14)[1]
            @test sum(assn, dims=1) ≈ students_dist'
            @test sum(assn, dims=2)[1:end - 1] ≤ capacities .+ 1e-5
        end
    end

    @testset "With school prefs" begin
        for _ in 1:samp
            n = rand(10:20)    # Number of student profiles in continuum
            m = rand(10:20)    # Number of schools
            α = 1 + rand()       # Proportion by which overdemanded mkt is overdemanded
            β = 1 - rand()        # Proportion by which underdemanded mkt is underdemanded

            students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
            students_dist = rand(n)                         # Percentage of total student population
            students_dist /= sum(students_dist)             # associated with each profile

            capacities = rand(m)                            # Percentage of total student population
            capacities /= (α * sum(capacities))
            schools = hcat((randperm(n) for i = 1:m)...)

            assn = DA_nonatomic(students, students_dist, schools, capacities; tol=1e-14)[1]
            @test sum(assn, dims=1) ≈ students_dist'
            @test sum(assn, dims=2)[1:end - 1] ≤ capacities .+ 1e-8

            capacities = rand(m)
            capacities /= (β * sum(capacities))
            assn = DA_nonatomic(students, students_dist, schools, capacities; tol=1e-14)[1]
            @test sum(assn, dims=1) ≈ students_dist'
            @test sum(assn, dims=2)[1:end - 1] ≤ capacities .+ 1e-8
        end
    end
end
