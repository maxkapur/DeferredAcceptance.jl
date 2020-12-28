include("DeferredAcceptance.jl")

n = 20
m = 50

students = hcat((randperm(m) for i in 1:n)...)
schools = hcat((randperm(n) for i in 1:m)...)
capacities = ones(Int64, m)

out1 = DA(students, schools, capacities; rev=true)
out2 = DA_new(students, schools, capacities; rev=true)

display(out1)
display(out2)
