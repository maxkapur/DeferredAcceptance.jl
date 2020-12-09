using Permutations
using Plots
include("DeferredAcceptance.jl")



function plotter_more(n, m_pop, m_unp, samp)

	m = m_pop + m_unp

	descr = "$n students, $m schools ($m_pop popular, $m_unp unpopular), $samp samples"
	println(descr)
	
	# All schools have unit capacities
	capacities = ones(Int64, m)

	# Blank rank dists
	cdf_STB = zeros(Int64, m)
	cdf_MTB = zeros(Int64, m)
	cdf_HTB = zeros(Int64, m)
	cdf_XTB = zeros(Int64, m)
	
	# For HTB
	blend = ones(Float64, 1, m) # Use MTB in all schools except
	blend[1:m_pop] .= 0			# the popular schools, which use STB

	for i in 1:samp
		print("$i, ")
		
		# Students unilaterally prefer popular schools to unpopular ones
		# Random ranking otherwise
		students = vcat(hcat((randperm(m_pop) for i in 1:n)...),
				   m_pop .+ hcat((randperm(m_unp) for i in 1:n)...))

		# Schools place all students in single priority category
		schools = ones(Int64, n, m)
		
		# Break ties
		schools_STB = STB(schools)
		schools_MTB = MTB(schools)
		schools_HTB = HTB(schools, blend)
		schools_XTB = HTB(schools, 0.5)

		# Update rank risks
		cdf_STB += rank_dist(students, schools_STB, capacities)
		cdf_MTB += rank_dist(students, schools_MTB, capacities)
		cdf_HTB += rank_dist(students, schools_HTB, capacities)
		cdf_XTB += rank_dist(students, schools_XTB, capacities)
	end

	# Norm rank dists against sample size
	cdf_STB *= 1 / samp
	cdf_HTB *= 1 / samp
	cdf_MTB *= 1 / samp
	cdf_XTB *= 1 / samp

	return plot([cdf_STB, cdf_MTB, cdf_HTB, cdf_XTB],
				label = ["DA-STB" "DA-MTB" "DA-HTB" "DA-XTB, λ=0.5"],
				legend = :bottomright,
				title = descr, titlefontsize=12,
				xlabel = "rank", ylabel= "average number of students")
end


(n, m_pop, m_unp, samp) = (120, 40, 80, 200)

p = plotter_more(n, m_pop, m_unp, samp)
savefig(p, string("plots/hybrid", n, "s", m_pop + m_unp, "c", samp, "n.pdf"))
savefig(p, string("plots/hybrid", n, "s", m_pop + m_unp, "c", samp, "n.png"))

