using JuMP
using DelimitedFiles
import GLPK
import Cbc
import Xpress


"""
For research purposes, a utility that finds the optimal stable matching using
integer programming, with commercial Xpress solver as default.
"""
function IP_stable_opt(students::Array{Int64, 2}, schools::Array{Int64, 2},
                    capacities::Array{Int64, 1})
    n, m = size(schools)
    @assert (m,) == size(capacities)
    @assert (m, n) == size(students) "Shape mismatch between schools and students"

    # Open-source, slow for this problem.
    # model = Model(GLPK.Optimizer)
    # set_optimizer_attribute(model, "msg_lev", GLPK.GLP_MSG_ALL)

    # Open source, fast for this problem for no reason.
    model = Model(Cbc.Optimizer)

    # Commercial option; need to have license in your path, but this problem is
    # small enough for the demo version. Fastest.
    # model = Model(Xpress.Optimizer)

    @variable(model, x[1:m, 1:n], Bin)
    @objective(model, Min, sum(x .* students))

    if sum(capacities) ≤ n
        @constraints(model, begin
            student_capacity[s in 1:n], sum(x[:, s]) ≤ 1
            school_capacity[c in 1:m], sum(x[c, :]) == capacities[c]
            stability[c in 1:m, s in 1:n], (capacities[c] * x[c, s] +
                                            capacities[c] * x[:, s]' * (students[:, s] .≤ students[c, s]) +
                                            x[c, :]' * (schools[:, c] .≤ schools[s, c])) ≥ capacities[c]
        end)
    else
        @constraints(model, begin
            student_capacity[s in 1:n], sum(x[:, s]) == 1
            school_capacity[c in 1:m], sum(x[c, :]) ≤ capacities[c]
            stability[c in 1:m, s in 1:n], (capacities[c] * x[c, s] +
                                            capacities[c] * x[:, s]' * (students[:, s] .≤ students[c, s]) +
                                            x[c, :]' * (schools[:, c] .≤ schools[s, c])) ≥ capacities[c]
        end)
    end

    optimize!(model)

    display("Total student disutility: $(objective_value(model))")
    out = value.(x)
    assn = vec(mapslices(col -> findfirst(y -> y > 0.9, col), out, dims = 1))
    return assn
end


"""
Same but without stability constraint.
"""
function LP_system_opt(students::Array{Int64, 2}, schools::Array{Int64, 2},
                    capacities::Array{Int64, 1})
    n, m = size(schools)
    @assert (m,) == size(capacities)
    @assert (m, n) == size(students) "Shape mismatch between schools and students"

    # Open source. Works great for LP case.
    model = Model(GLPK.Optimizer)
    set_optimizer_attribute(model, "msg_lev", GLPK.GLP_MSG_ALL)

    # Open source.
    # model = Model(Cbc.Optimizer)

    # Commercial option.
    # model = Model(Xpress.Optimizer)

    # Constraint matrix is TUM so no integrality constraint.
    @variable(model, 0 ≤ x[1:m, 1:n] ≤ 1)
    @objective(model, Min, sum(x .* students))
    if sum(capacities) ≤ n
        @constraints(model, begin
            student_capacity[s in 1:n], sum(x[:, s]) ≤ 1
            school_capacity[c in 1:m], sum(x[c, :]) == capacities[c]
        end)
    else
        @constraints(model, begin
            student_capacity[s in 1:n], sum(x[:, s]) == 1
            school_capacity[c in 1:m], sum(x[c, :]) ≤ capacities[c]
        end)
    end

    optimize!(model)
    display("Total student disutility: $(objective_value(model))")
    out = value.(x)
    @assert isempty(filter(x -> !(round(x, digits=5) in [0, 1]), out)) "Solution not integral"
    assn = vec(mapslices(col -> findfirst(y -> y > 0.9, col), out, dims = 1))
    return assn
end


students = readdlm("examples/sysopt/students.dat", Int)
schools = readdlm("examples/sysopt/schools.dat", Int)
n, m = size(schools)
capacities = ones(Int64, m)

assn_LP = LP_system_opt(students, schools, capacities)
# GLPK Simplex Optimizer, v4.64
# 200 rows, 10000 columns, 20000 non-zeros
#       0: obj =  0.000000000e+000 inf =  1.000e+002 (100)
#     199: obj =  4.704000000e+003 inf =  0.000e+000 (0)
# Perturbing LP to avoid stalling [400]...
# Removing LP perturbation [1301]...
# *  1301: obj =  2.407000000e+003 inf =  0.000e+000 (0) 8
# OPTIMAL LP SOLUTION FOUND

assn = IP_stable_opt(students, schools, capacities)
# Result - Optimal solution found
#
# Objective value:                2426.00000000
# Enumerated nodes:               0
# Total iterations:               0
# Time (CPU seconds):             15.34
# Time (Wallclock seconds):       15.34
#
# Total time (CPU seconds):       15.38   (Wallclock seconds):       15.38
#
# "Total student disutility: 2426.0"

# writedlm("examples/sysopt/LPSystemOpt.dat", assn_LP)
# writedlm("examples/sysopt/IPStableOpt.dat", assn)
