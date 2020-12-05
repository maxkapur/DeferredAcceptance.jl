#module DirectAssignment

using StatsBase
using Random


#export STB, MTB, DA, rank_cdf


function nlargest(vec, n)
    # Boolean vector shaped like input indicating n largest entries
    inp = copy(vec)
    out = zeros(Bool, length(vec))
    for i in 1:n
        am = argmax(inp)
        out[am] = true
        inp[am] = -1
    end
    return out
end

function argsort(vec)
    return invperm(sortperm(vec))
end

function STB(arr)
    add = repeat(rand(Float64, size(arr)[1]), 1, size(arr)[2])
    return mapslices(argsort, arr + add, dims=1)
end

function MTB(arr)
    add = rand(Float64, size(arr))
    return mapslices(argsort, arr + add, dims=1)
end

function DA(students::Array{Int64, 2}, schools::Array{Int64, 2},
            capacities_in::Array{Int64, 1}, verbose=false::Bool)
    students_inv = mapslices(invperm, students, dims=1)
    n, m = size(schools)
    
    capacities = vcat(capacities_in, n)  # For students who never get assigned

    curr_assn = students_inv[1, :]
    done = false
    nit = 0
    
    while !done
        nit += 1
        verbose ? println("Round $nit") : nothing
        done = true
        proposals = zeros(Bool, n, m + 1)
        for (s, C) in enumerate(curr_assn)
            proposals[s, C[1]] = true
        end
        for (c, S) in enumerate(eachcol(proposals))
            n_rejects = sum(S)
            if n_rejects > capacities[c]
                rejections = nlargest(S .* schools[:, c], n_rejects - capacities[c])
                for (s, r) in enumerate(rejections)
                    if r
                        done = false
                        verbose ? println("  School $c rejects student $s") : nothing
                        curr_assn[s] = get(students_inv, (students[c, s] + 1, s), m + 1)
                    end
                end
            end
        end
    end
    verbose ? println("DA terminated in $nit iterations") : nothing
    return curr_assn, [get(students, (c, s), m + 1) for (s, c) in enumerate(curr_assn)]
end


function rank_dist(students, schools, capacities, verbose=false::Bool)
    n, m = size(schools)
    dist_cmap = countmap(DA(students, schools, capacities, verbose)[2])
    rank_hist = [get(dist_cmap, i, 0) for i in 1:m]
    return cumsum(rank_hist)
end
