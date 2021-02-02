using Permutations
using DelimitedFiles

(n, m_pop, m_unp) = (100, 35, 65)

m = m_pop + m_unp

students = vcat(hcat((randperm(m_pop) for i in 1:n)...),
					 m_pop .+ hcat((randperm(m_unp) for i in 1:n)...))

schools = ones(Int64, n, m)

# writedlm("sysopt/students.dat", students)
# writedlm("sysopt/schools.dat", schools)
