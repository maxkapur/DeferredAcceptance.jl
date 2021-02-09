using DeferredAcceptance
using Test, Random

@testset "Throws" begin
    @testset "Dim mismatches" begin
        @test_throws AssertionError DA([1 2; 2 1], [1 2; 2 1; 3 3], [1, 1, 1])
        @test_throws AssertionError TTC_match([1 2; 2 1; 3 3], [5, 6])
        @test_throws AssertionError CADA([1 2; 2 1; 3 3], [1, 2])
    end
end


@testset "Discrete matches" begin
    samp = 10

    @testset "Tiny TTC" begin
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

    @testset "TTC instability" begin
        for _ in 1:samp
            n = rand(100:200)
            m = rand(20:40)
            students = hcat((randperm(m) for i in 1:n)...)
            schools = hcat((randperm(n) for i in 1:m)...)
            capacities = rand(5:10, m)

            assn, rdist = TTC_match(students, capacities)
            @test isstable(students, schools, capacities, assn)==false
        end
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

    @testset "Tiny tiebreaking doesn't fail" begin
        for sch in [schools_STB, schools_MTB, schools_WTB],
            col in eachcol(sch)
            @test all(i in col for i in 1:size(schools)[1])
        end
    end

    @testset "Tiny tiebreaking linear orders agree" begin
        for sch in [schools_STB, schools_MTB, schools_WTB],
            (tb, or) in zip(eachcol(sch), eachcol(schools))
            @test all(diff(or[sortperm(tb)]) .≥ 0)
        end
    end

    @testset "Tiny DA stability" begin
        for sch in [schools_STB, schools_MTB, schools_WTB]
            assn, ranks = DA(students, sch, [3, 2, 2, 3])
            @test isstable(students, sch, capacities, assn)
            # Checks linear orders:
            # @test all([all(diff(schools[:, i][sortperm(col)]) .≥ 0)
            #            for (i, col) in enumerate(eachcol(sch))])
        end
    end

    @testset "Big DA stability, fwd" begin
        for _ in 1:samp
            n = rand(100:200)
            m = rand(20:40)
            students = hcat((randperm(m) for i in 1:n)...)
            schools = hcat((randperm(n) for i in 1:m)...)
            capacities = rand(5:10, m)

            assn, ranks = DA(students, schools, capacities)
            @test isstable(students, schools, capacities, assn)
        end
    end

    @testset "Big DA stability, rev" begin
        for _ in 1:samp
            n = rand(100:200)
            m = rand(20:40)
            students = hcat((randperm(m) for i in 1:n)...)
            schools = hcat((randperm(n) for i in 1:m)...)
            capacities = rand(5:10, m)

            assn, ranks = DA(students, schools, capacities, rev=true)
            @test isstable(students, schools, capacities, assn)
        end
    end

    @testset "CADA stability" begin
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
            @test isstable(students, schools, capacities, assn)
        end
    end

    @testset "DA rank dist" begin
        for _ in 1:samp
            n = rand(100:200)
            m = rand(20:40)
            students = hcat((randperm(m) for i in 1:n)...)
            schools = hcat((randperm(n) for i in 1:m)...)
            capacities = rand(5:10, m)

            out = DA_rank_dist(students, schools, capacities)
            @test out[end] == min(n, sum(capacities))
        end
    end
end

@testset "Nonatomic DA" begin
    samp = 10

    @testset "Azevedo and Leshno (2016)'s example'" begin
        students = [1 2; 2 1]
        students_dist = [0.5, 0.5]
        capacities = [0.25, 0.5]

        assn, rdist, cutoffs = DA_nonatomic(students, students_dist, nothing, capacities;
                                            return_cutoffs=true)

        @test cutoffs ≈ [√17 + 1, √17 - 1] ./ 8
        @test ismarketclearing(students, students_dist, capacities, cutoffs)
        @test ismarketclearing(students, students_dist, capacities, [0.1, 0.1])==false
        @test ismarketclearing(students, students_dist, capacities, [0.9, 0.9])==false
    end

    @testset "Assignment and demand operators" begin
        for _ in 1:samp
            n = rand(5:10)    # Number of student profiles in continuum
            m = rand(10:20)    # Number of schools
            α = 0.5 + rand()

            students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
            students_dist = rand(n)                         # Percentage of total student population
            students_dist /= sum(students_dist)             # associated with each profile

            students_inv = mapslices(invperm, students, dims=1)

            capacities = rand(m)
            capacities /= (α * sum(capacities))

            cutoffs = rand(m)       # Should be incorrect

            D_l = demands_from_cutoffs(students, students_dist, cutoffs)
            assn_d, D_d = assn_from_cutoffs(students_inv, students_dist, cutoffs;
                                            return_demands=true)

            @test D_l ≈ D_d
            @test sum(assn_d, dims=1) ≈ students_dist'
            @test ismarketclearing(students, students_dist, capacities, cutoffs)==false
        end
    end

    @testset "Cutoff algorithm market-clearing" begin
        for _ in 1:samp
            n = rand(5:10)    # Number of student profiles in continuum
            m = rand(5:10)    # Number of schools
            α = 0.5 + rand()       # Proportion by which mkt is overdemanded

            students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
            students_dist = rand(n)                         # Percentage of total student population
            students_dist /= sum(students_dist)             # associated with each profile

            capacities = rand(m)                            # Percentage of total student population
            capacities /= (α * sum(capacities))

            students_inv = mapslices(invperm, students, dims=1)
            cutoffs = DA_nonatomic_lite(students, students_dist, capacities)

            D_l = demands_from_cutoffs(students, students_dist, cutoffs)
            assn_d, D_d = assn_from_cutoffs(students_inv, students_dist, cutoffs;
                                            return_demands=true)

            @test D_l ≈ D_d
            @test sum(assn_d, dims=1) ≈ students_dist'
            @test vec(sum(assn_d[1:end - 1, :], dims=2)) ≤ capacities .+ 1e-8
            @test ismarketclearing(students, students_dist, capacities, cutoffs)
        end
    end

    @testset "No school prefs" begin
        for _ in 1:samp
            n = rand(5:10)    # Number of student profiles in continuum
            m = rand(5:10)    # Number of schools
            α = 0.5 + rand()   # Proportion by which mkt is overdemanded

            students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
            students_dist = rand(n)                         # Percentage of total student population
            students_dist /= sum(students_dist)             # associated with each profile

            capacities = rand(m)                            # Percentage of total student population
            capacities /= (α * sum(capacities))

            assn, rdist, cutoffs = DA_nonatomic(students, students_dist, nothing, capacities;
                                                return_cutoffs=true)

            @test sum(assn, dims=1) ≈ students_dist'
            @test sum(assn, dims=2)[1:end - 1] ≤ capacities .+ 1e-4
            @test ismarketclearing(students, students_dist, capacities, cutoffs)
        end
    end

    @testset "With school prefs" begin
        for _ in 1:samp
            n = rand(5:10)    # Number of student profiles in continuum
            m = rand(5:10)    # Number of schools
            α = 0.5 + rand()   # Proportion by which mkt is overdemanded

            students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
            students_dist = rand(n)                         # Percentage of total student population
            students_dist /= sum(students_dist)             # associated with each profile

            capacities = rand(m)                            # Percentage of total student population
            capacities /= (α * sum(capacities))
            schools = hcat((randperm(n) for i = 1:m)...)

            assn = DA_nonatomic(students, students_dist, schools, capacities)[1]

            @test sum(assn, dims=1) ≈ students_dist'
            @test sum(assn, dims=2)[1:end - 1] ≤ capacities .+ 1e-8
        end
    end

    @testset "Reverse nonatomic lite" begin
        for _ in 1:samp
            n = rand(5:10)    # Number of student profiles in continuum
            m = rand(5:10)    # Number of schools
            α = 0.5 + rand()   # Proportion by which mkt is overdemanded

            students = hcat((randperm(m) for i = 1:n)...)   # Student profiles
            students_dist = rand(n)                         # Percentage of total student population
            students_dist /= sum(students_dist)             # associated with each profile

            capacities = rand(m)                            # Percentage of total student population
            capacities /= (α * sum(capacities))

            # Could just use DA_nonatomic_lite here but this tests the wrapper too
            _, _, cutoffs_fwd = DA_nonatomic(students, students_dist, nothing, capacities;
                                             return_cutoffs=true)
            _, _, cutoffs_rev = DA_nonatomic(students, students_dist, nothing, capacities;
                                             return_cutoffs=true, rev=true)

            # Cutoffs should be equal in this idealized case
            @test cutoffs_fwd ≈ cutoffs_rev #atol=1e-6
        end
    end
end
