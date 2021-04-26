using DeferredAcceptance
using Test, Random, LinearAlgebra


@testset "Throws" begin
    @testset "Dim mismatches" begin
        @test_throws AssertionError DA([1 2; 2 1], [1 2; 2 1; 3 3], [1, 1, 1])
        @test_throws AssertionError TTC_match([1 2; 2 1; 3 3], [5, 6])
        @test_throws AssertionError CADA([1 2; 2 1; 3 3], [1, 2])
    end
end


@testset "Discrete input" begin
    @testset "Normal input" begin
        students = [1 2;
                    2 1;
                    3 4;
                    4 3]
        schools = [1 2 2 1;
                   2 1 1 2]
        capacities = [1, 1, 2, 1]

        @test !isempty(DA(students, schools, capacities))
        @test !isempty(TTC_match(students, capacities))
    end

    @testset "UInt input" begin
        students = UInt[1 2;
                        2 1;
                        3 4;
                        4 3]
        schools = [1 2 2 1;
                   2 1 1 2]
        capacities = [1, 1, 2, 1]

        @test !isempty(DA(students, schools, capacities))
        @test !isempty(DA(students, schools, capacities; rev=true))
        @test !isempty(TTC_match(students, capacities))
    end


    @testset "Adjoints" begin
        students = [1 2 3;
                    2 1 3]
        schools = [1 2; 1 2; 2 1]

        capacities = [1, 1, 2]

        @test !isempty(DA(students', schools', capacities))
        @test !isempty(TTC_match(students', capacities))
    end

    @testset "1D input" begin
        students = [1, 3, 2, 4]
        schools = [1, 1, 1, 1]
        capacities = [3, 2, 4, 2]

        @test_broken !isempty(DA(students, schools, capacities))
        @test_broken !isempty(TTC_match(students, capacities))
    end
end


@testset "Discrete matches" begin
    samp = 5

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
        # About 1% of the time TTC chances upon a stable match. Don't worry.
        res = falses(samp)

        for i in 1:samp
            n = rand(100:200)
            m = rand(20:40)
            students = hcat((randperm(m) for i in 1:n)...)
            schools = hcat((randperm(n) for i in 1:m)...)
            capacities = rand(5:10, m)

            assn, rdist = TTC_match(students, capacities)
            res[i] = isstable(students, schools, capacities, assn) == false
        end

        @test sum(res) / samp ≥ .9
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


@testset "Nonatomic input" begin
    @testset "Normal input" begin
        students = [1 2;
                    2 1;
                    3 4;
                    4 3]
        students_dist = [0.4, 0.6]
        schools = [1 2 2 1;
                   2 1 1 2]
        capacities = [.2, .2, .2, .3]

        @test !isempty(DA_nonatomic(students, students_dist, schools, capacities))
        @test !isempty(DA_nonatomic(students, students_dist, nothing, capacities))
    end

    @testset "Adjoints" begin
        students = [1 2 3;
                    2 1 3]
        students_dist = [.1, .9]
        schools = [1 2; 1 2; 2 1]

        capacities = [.1, .6, .1]

        @test !isempty(DA_nonatomic(students', students_dist, schools', capacities))
        @test !isempty(DA_nonatomic(students', students_dist, nothing, capacities))
    end

    @testset "UInt input" begin
        students = UInt[1 2;
                        2 1;
                        3 4;
                        4 3]
        students_dist = [0.4, 0.6]
        schools = UInt[1 2 2 1;
                       2 1 1 2]
        capacities = [.2, .2, .2, .3]

        @test !isempty(DA_nonatomic(students, students_dist, schools, capacities))
        @test !isempty(DA_nonatomic(students, students_dist, nothing, capacities))
    end

    @testset "1D input" begin
        #=  Would actually be nice for this to work, as knowing the allocation given
            that everyone has the same preference order is useful.      =#

        students = [1, 3, 2, 4]
        students_dist = [1.]
        schools = [1, 1, 1, 1]
        capacities = [.1, .6, .1, .2]

        @test_broken !isempty(DA_nonatomic(students, students_dist, schools, capacities))
        @test_broken !isempty(DA_nonatomic(students, students_dist, nothing, capacities))
    end
end


@testset "Nonatomic DA" begin
    samp = 5

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

            D_l = demands_preflists(students, students_dist, cutoffs)
            assn_d, D_d = assn_from_preflists(students_inv, students_dist, cutoffs;
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

            D_l = demands_preflists(students, students_dist, cutoffs)
            assn_d, D_d = assn_from_preflists(students_inv, students_dist, cutoffs;
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


@testset "Funny demand functions" begin
    samp = 5

    @testset "MLN iid" begin

        @testset "WGS" begin
            for _ in 1:samp
                m = rand(5:10)

                qualities = rand(m)

                cutoffs = rand(m)
                delta = copy(cutoffs)

                delta[2:end] .= 1

                demand(cut) = demands_MNL_iid(qualities, cut)

                # When all schools but 1 increase their cutoffs
                out_orig = demand(cutoffs)
                out_pert = demand(cutoffs + rand() * (delta .- cutoffs))

                # 1's demand should increase
                @test out_orig[1] ≤ out_pert[1]
            end
        end

        @testset "Azevedo and Leshno (2016)'s example" begin
            qualities = [1., 1]         # Schools equally preferable
            capacities = [0.25, 0.5]

            demand(cut) = demands_MNL_iid(qualities, cut)

            actual = [√17 + 1, √17 - 1] ./ 8

            @test DA_nonatomic_lite(demand, capacities) ≈ actual
            @test DA_nonatomic_lite(demand, capacities, rev=true) ≈ actual
            @test nonatomic_tatonnement(demand, capacities) ≈ actual
            @test nonatomic_secant(demand, capacities) ≈ actual
        end

        @testset "DA-lite fwd, rev; secant; tatonnement agree" begin
            for _ in 1:samp
                m = rand(5:10)
                qualities = randexp(m)
                capacities = randexp(m)
                capacities ./= (0.5 + rand()) .* sum(capacities)

                demand(cut) = demands_MNL_iid(qualities, cut)

                cutoffs = DA_nonatomic_lite(demand, capacities)

                @test cutoffs ≈
                      DA_nonatomic_lite(demand, capacities; rev=true)
                @test cutoffs ≈
                      nonatomic_tatonnement(demand, capacities)
                @test cutoffs ≈
                      nonatomic_secant(demand, capacities, verbose=false)

                @test ismarketclearing(qualities, capacities, cutoffs)
                @test ismarketclearing(demand, capacities, cutoffs)
            end
        end

    end


    @testset "MLN one test" begin

        @testset "WGS" begin
            m = rand(5:10)

            qualities = rand(m)

            cutoffs = rand(m)
            delta = copy(cutoffs)

            delta[2:end] .= 1

            demand(cut) = demands_MNL_onetest(qualities, cut)

            # When all schools but 1 increase their cutoffs
            out_orig = demand(cutoffs)
            out_pert = demand(cutoffs + rand() * (delta .- cutoffs))

            # 1's demand should increase
            @test out_orig[1] ≤ out_pert[1]
        end

        @testset "Tatonnement clears mkt" begin
            for _ in 1:samp
                m = rand(10:25)
                qualities = rand(m)
                capacities = randexp(m)
                capacities ./= (0.5 + rand()) .* sum(capacities)

                demand(cut) = demands_MNL_onetest(qualities, cut)

                cut = nonatomic_tatonnement(demand, capacities, maxit=800)
                @test ismarketclearing(demand, capacities, cut)
            end
        end
    end


    @testset "p MNL profiles, t tests" begin

        @testset "WGS" begin
            for _ in 1:samp
                m = rand(5:10)
                p = rand(3:5)
                t = rand(3:5)

                qualities = randexp(m, p)
                profile_dist = rand(p)
                profile_dist ./= sum(profile_dist)

                blends = rand(m, t)
                blends ./= sum(blends, dims=2)

                cutoffs = rand(m)

                delta = copy(cutoffs)
                delta[2:end] .= 1

                demand(cut) = demands_pMNL_ttests(qualities, profile_dist, blends, cut)

                # When all schools but 1 increase their cutoffs
                out_orig = demand(cutoffs)
                out_pert = demand(cutoffs + rand() * (delta .- cutoffs))

                # 1's demand should increase
                @test out_orig[1] ≤ out_pert[1] + 1e-3
            end
        end

        @testset "Equivalence with MNL iid" begin
            # We use Monte Carlo integration here, so have to set pretty loose tolerances.

            for _ in 1:samp
                m = rand(5:10)
                qualities = rand(m)
                cutoffs = rand(m)

                out1 = demands_MNL_iid(qualities, cutoffs)

                # This one hangs when using exact mode, due to too many
                # redundant constraints for Polyhedra.jl to figure out.
                out2 = demands_pMNL_ttests(reshape(qualities, :, 1),
                                           [1.],
                                           Matrix{Float64}(I, m, m)[randperm(m), :],
                                           montecarlo=true,
                                           cutoffs)

                @test isapprox(out1, out2, atol=1e-2)
            end
        end

        @testset "Equivalence with MNL one test" begin
            for _ in 1:samp
                m = rand(5:10)
                qualities = rand(m)
                cutoffs = rand(m)

                out1 = demands_MNL_onetest(qualities, cutoffs)

                out2 = demands_pMNL_ttests(reshape(qualities, :, 1),
                                           [1.],
                                           ones(m, 1),
                                           cutoffs)

                @test isapprox(out1, out2, atol=1e-2)
            end
        end

        samp = 3

        @testset "Tatonnement clears mkt" begin
            for _ in 1:samp
                m = rand(5:7)
                p = rand(5:10)
                t = rand(2:4)

                qualities = randexp(m, p)
                profile_dist = rand(p)
                profile_dist ./= sum(profile_dist)

                blends = rand(m, t)
                blends ./= sum(blends, dims=2)

                capacities = randexp(m)
                capacities ./= (0.5 + rand()) .* sum(capacities)

                nit = 1

                # Kinda hacky but works. Use MC for local search then start
                # return precise values later on.
                function demand(cut)
                    if nit < 100
                        nit += 1
                        return demands_pMNL_ttests(qualities, profile_dist, blends, cut,
                                                   montecarlo=true, n_points=1000)
                    else
                        return demands_pMNL_ttests(qualities, profile_dist, blends, cut,
                                                   montecarlo=false)
                    end
                end

                cut = nonatomic_tatonnement(demand, capacities, maxit=200, β=.0, tol=1e-6)

                @test ismarketclearing(demand, capacities, cut, tol=1e-4)
            end
        end

        @testset "Secant clears mkt" begin
            for _ in 1:samp
                m = rand(5:7)
                p = rand(5:10)
                t = rand(2:4)

                qualities = randexp(m, p)
                profile_dist = rand(p)
                profile_dist ./= sum(profile_dist)

                blends = rand(m, t)
                blends ./= sum(blends, dims=2)

                capacities = randexp(m)
                capacities ./= (0.5 + rand()) .* sum(capacities)

                nit = 1

                function demand(cut)
                    if nit < 50
                        nit += 1
                        return demands_pMNL_ttests(qualities, profile_dist, blends, cut,
                                                   montecarlo=true, n_points=1000)
                    else
                        return demands_pMNL_ttests(qualities, profile_dist, blends, cut,
                                                   montecarlo=false)
                    end
                end

                cut = nonatomic_secant(demand, capacities, maxit=200, verbose=false, tol=1e-6)

                @test ismarketclearing(demand, capacities, cut, tol=1e-2)
            end
        end
    end

end
