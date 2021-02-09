#=  Here I attempt to find approximate extremes of the welfare-equity tradeoff curve. Ashlagi and
    Nikzad (2020) argue that in general, STB mechanisms favor welfare while MTB favors equity. But
    by using student welfare itself as a primary tiebreaker, and STB to break subsequent ties
    (WSTB), we can find an even more welfare-optimal solution in many problems. This solution
    dominates the plain STB solution rankwise in overdemanded markets. Moreover, by *minimizing*
    student welfare as a primary tiebreaker and using MTB as a secondary tiebreaker (EMTB), we can
    find solutions that are arguably more equitable than those produced by MTB. The intuition is
    that students whose current assignment is low on their priority list deserve to be matched
    quickly rather than subjected to further rejection; this results in matches where most of the
    students end up with a match about halfway down their list. The reason these extremes are
    approximate is that when school preferences are weak, finding the welfare-optimal stable
    solution is NP-hard. I solved a few small examples in the ../sysopt/ directory.    =#

using Permutations
using Plots
using Random
using DeferredAcceptance


"""
Plots outcomes for various tiebreaking rules for a market with
the given characteristics.
"""
function plotter_more(n, m_pop, m_unp, samp)
    m = m_pop + m_unp

    descr = "$n students, $m schools ($m_pop popular, $m_unp unpopular), $samp samples"
    println(descr)

    # All schools have unit capacities
    capacities = ones(Int64, m)

    # Blank rank dists
    cdf_STB = zeros(Float64, m)
    cdf_MTB = zeros(Float64, m)
    cdf_WSTB = zeros(Float64, m)        # Welfare, single
    cdf_EMTB = zeros(Float64, m)        # Equity, multiple

    for i in 1:samp
        # Students unilaterally prefer popular schools to unpopular ones
        # Random ranking otherwise
        students = vcat(hcat((randperm(m_pop) for i in 1:n)...),
                   m_pop .+ hcat((randperm(m_unp) for i in 1:n)...))

        # Schools place all students in single priority category
        schools = ones(Int64, n, m)

        # Break ties
        schools_STB = STB(schools)
        schools_MTB = MTB(schools)
        schools_WSTB = WTB(students, schools, 0)
        schools_EMTB = WTB(students, schools, 1, equity=true)

        # Update rank risks
        println("Starting STB $i")
        cdf_STB += DA_rank_dist(students, schools_STB, capacities)
        println("Starting MTB $i")
        cdf_MTB += DA_rank_dist(students, schools_MTB, capacities)
        println("Starting WSTB $i")
        cdf_WSTB += DA_rank_dist(students, schools_WSTB, capacities)
        println("Starting EMTB $i")
        cdf_EMTB += DA_rank_dist(students, schools_EMTB, capacities)
    end

    # Norm rank dists against sample size
    for i in [cdf_STB, cdf_MTB, cdf_WSTB, cdf_EMTB]
        i ./= samp
    end

    return plot([cdf_STB, cdf_MTB, cdf_WSTB, cdf_EMTB],
                label = ["DA-STB" "DA-MTB" "DA-WSTB" "DA-EMTB"],
                lc = [:crimson :dodgerblue :olivedrab :rebeccapurple],
                ls = [:dashdot :dash],
                legend = :bottomright,
                title = descr, titlefontsize=11,
                xlabel = "rank", ylabel= "average number of students")
end

(n, m_pop, m_unp, samp) = (50, 17, 33, 120)

p = plotter_more(n, m_pop, m_unp, samp)
# savefig(p, string("plots/welfeq", n, "s", m_pop + m_unp, "c", samp, "n.pdf"))
# savefig(p, string("plots/welfeq", n, "s", m_pop + m_unp, "c", samp, "n.png"))
