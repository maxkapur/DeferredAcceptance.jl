using Permutations
using DelimitedFiles

(n, m_pop, m_unp) = (40, 0, 40)

m = m_pop + m_unp

students = vcat(hcat((randperm(m_pop) for i in 1:n)...),
					 m_pop .+ hcat((randperm(m_unp) for i in 1:n)...))

schools = ones(Int64, n, m)

writedlm("students.dat", students)
writedlm("schools.dat", schools)
	
open("data.dat", "w") do io
	write(io, "students: \n[")
	writedlm(io, students, " ")
	
	write(io, "]\n\nschools: \n[")
	writedlm(io, schools)
	write(io, "]")
end