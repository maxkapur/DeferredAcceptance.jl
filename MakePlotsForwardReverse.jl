using Permutations
using Plots
include("DeferredAcceptance.jl")


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
	cdf_HTB_f = zeros(Float64, m)
	cdf_HTB_r = zeros(Float64, m)
    cdf_WXTB_f = zeros(Float64, m)
    cdf_WXTB_r = zeros(Float64, m)

	# For HTB and WTB
	blend = ones(Float64, 1, m) # Use MTB in all schools except
	blend[1:m_pop] .= 0			# the popular schools, which use STB

	for i in 1:samp
		# Students unilaterally prefer popular schools to unpopular ones
		# Random ranking otherwise
		students = vcat(hcat((randperm(m_pop) for i in 1:n)...),
				   m_pop .+ hcat((randperm(m_unp) for i in 1:n)...))

		# Schools place all students in single priority category
		schools = ones(Int64, n, m)
		
		# Break ties
		schools_HTB = HTB(schools, blend)
        schools_WXTB = WTB(schools, students, 0.5)

		# Update rank risks
		println("Starting HTB $i, forward")
        cdf_HTB_f += rank_dist(students, schools_HTB, capacities)
		println("Starting HTB $i, reverse")
        cdf_HTB_r += rank_dist(students, schools_HTB, capacities, rev=true)
		println("Starting WXTB $i, forward")
        cdf_WXTB_f += rank_dist(students, schools_WXTB, capacities)
		println("Starting WXTB $i, reverse")
        cdf_WXTB_r += rank_dist(students, schools_WXTB, capacities, rev=true)

        # To display plot as it updates
        display(plot([cdf_HTB_f, cdf_HTB_r, cdf_WXTB_f, cdf_WXTB_r],
				label = ["DA-HTB, forward" "DA-HTB, reverse" "DA-WXTB, forward" "DA-WXTB, reverse"],
                lc = [:dodgerblue :navy :gold :crimson],
                ls = [:dash :dot],
				legend = :bottomright,
				title = descr, titlefontsize=11,
				xlabel = "rank", ylabel= "average number of students"))
	end

	# Norm rank dists against sample size
	for i in [cdf_HTB_f, cdf_HTB_r, cdf_WXTB_f, cdf_WXTB_r]
        i ./= samp
    end

	return plot([cdf_HTB_f, cdf_HTB_r, cdf_WXTB_f, cdf_WXTB_r],
				label = ["DA-HTB, forward" "DA-HTB, reverse" "DA-WXTB, forward" "DA-WXTB, reverse"],
                lc = [:dodgerblue :navy :gold :crimson],
                ls = [:dash :dot],
				legend = :bottomright,
				title = descr, titlefontsize=11,
				xlabel = "rank", ylabel= "average number of students")
end

(n, m_pop, m_unp, samp) = (100, 40, 60, 120)

p = plotter_more(n, m_pop, m_unp, samp)
savefig(p, string("plots/fwrv", n, "s", m_pop + m_unp, "c", samp, "n.pdf"))
savefig(p, string("plots/fwrv", n, "s", m_pop + m_unp, "c", samp, "n.png"))
