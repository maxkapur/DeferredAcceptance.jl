using Permutations
using DelimitedFiles
using Random

(n, m_pop, m_unp) = (100, 35, 65)

m = m_pop + m_unp

students = vcat(hcat((randperm(m_pop) for i in 1:n)...),
					 m_pop .+ hcat((randperm(m_unp) for i in 1:n)...))
schools = ones(Int64, n, m)

for (i, r) in enumerate(schools)
	if rand() > 0.6
		schools[i] += 1
	end
end

writedlm("examples/sysopt/students.dat", students)
writedlm("examples/sysopt/schools.dat", schools)
