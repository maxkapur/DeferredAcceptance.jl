# Basic
assn = [3, 2, 1]
students_inv = [1 1 3;
                2 3 1;
                3 2 2]
@assert TTC(students_inv, assn, verbose=true) == [1, 2, 3]

# Lots of cycles
assn = [1, 3, 2, 4]
students_inv = [1 2 3 4;
                2 1 4 3;
                3 4 1 2;
                4 3 2 1]
@assert TTC(students_inv, assn, verbose=true) == [1, 2, 3, 4]

# Underdemanded
assn = [1, 2]
students_inv = [4 3;
                2 1;
                1 4;
                3 2]
@assert TTC(students_inv, assn, verbose=true) == [2, 1]

# Overdemanded
assn = [1, 2, 2, 3]
students_inv = [3 1 1 2;
                1 2 3 1;
                2 3 2 3]
@assert TTC(students_inv, assn, verbose=true) in ([3, 1, 2, 2], [3, 2, 1, 2])
