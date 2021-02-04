using DeferredAcceptance

#=  Most school-choice algorithms start with each side ranking the other
    in terms of preferability. First we input the student preferences.
    Each column is a student, and each row is a school. So, the 2 in cell
    (3, 4) means that student 4 has named school 3 as her 2nd choice. =#
students = [3 3 4 3 4 3 3 3 3 4;
            4 4 3 4 3 4 4 4 4 3;
            2 1 2 2 2 1 2 2 2 2;
            1 2 1 1 1 2 1 1 1 1]

#=  Now we input the school preferences over the students. Notice that the
    shape is transposed: each column is a school, and row a student. This
    format improves computation speed. Also notice that now we have ties:
    for example, school 1 has four students tied for 1st place. You can
    also write the first column as [1, 1, 2, 2, 4, 1, 2, 3, 3, 1]. Basically,
    they just need to be positive integers in descending order of preference. =#
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

# Finally we have the capacities, or number of students each school can accept.
capacities = [3, 2, 2, 3]

#=  Let's use the DA algorithm to find a stable match. The DA algorithm requires
    that both students and schools have strict preferences, so we need to run
    some random tiebreaking to make the school preferences strict. We will use
    STB, which is usually the best choice.        =#
schools_tiebroken = STB(schools)

# Now we run DA.
assn, ranks = DA(students, schools_tiebroken, capacities; verbose=true)

# Make sure the match is stable.
@assert is_stable(students, schools, capacities, assn)

#=  The first output is the assignment. Student 1 goes to school 1, student 2
    goes to school 3, etc. If the market had too many students, we would have
    some students assigned to school 5, which means no school accepted them. =#
println(assn)
# [1, 3, 4, 4, 2, 3, 4, 1, 1, 2]

#=  The second output is the rank each student gave to their assigned school.
    So student 1 got her 3rd choice, student 2 got her 2nd, etc.    =#
println(ranks)
# [3, 1, 1, 1, 3, 1, 1, 3, 3, 3]

# A common measure of utility
println(sum(ranks))
# 22

#=  Since the tiebreaking mechanism involves randomness, you might have
    found a slightly different assignment.

    Now let's try something different. Suppose the schools don't have any
    preferences over the students at all (as in New Orleans). Then we can
    start with an arbitrary assignment and exchange Pareto-improving pairs
    to get a better one. This is called top trading cycles and is a classic
    solution to the "housing market" problem. In school choice, it produces
    an assignment that tends to maximize student welfare.       =#
assn, ranks = TTC_match(students, capacities; verbose=true)

# Same output format
println(assn)
# [2, 3, 4, 4, 2, 1, 4, 1, 1, 3]
println(ranks)
# [4, 1, 1, 1, 3, 3, 1, 3, 3, 2]

# Looks like TTC did a little better, but what are the tradeoffs?
println(sum(ranks))
# 21

is_stable(students, schools, capacities, assn) # Returns false
# Student feas. :  true
# School feas.  :  true
# Stability     :  false
