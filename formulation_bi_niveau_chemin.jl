using JuMP
using CPLEX
using IterTools

include("utils.jl")

arcs, sources, attack_traffic, n, t, cost_VNF, node_cap, arcs_cap, resource_VNF, 
        filtering_cap_VNF = get_data("./instances/instance_1.txt")


A = length(sources)
attack_paths = [all_paths(arcs, sources[a], t) for a in 1:A]
P = maximum(length.(attack_paths))


function master_problem(uncertainty_set)
    m = Model(CPLEX.Optimizer)
    set_silent(m)

    @variable(m, y[1:n] >= 0, Int) # Nombre de VNF au noeud i

    # Capacité des noeuds
    @constraint(m, [i in 1:n], resource_VNF * y[i] <= node_cap[i])
    # Filtrage par les VNF de tout le flot malveillant
    @constraint(m, [f in uncertainty_set], sum(y[i] for i in get_nodes_with_positive_flow(f)) * filtering_cap_VNF >= sum(f[a][p] for a in 1:A for p in 1:length(attack_paths[a])))
    # Pas de VNF aux sources ni aux cibles
    @constraint(m, y[t] == 0)
    @constraint(m, [i in sources], y[i] == 0)

    # Minimisation du coût d'installation
    @objective(m, Min, sum(cost_VNF[i] * y[i] for i in 1:n))

    optimize!(m)

    if primal_status(m) == MOI.FEASIBLE_POINT
        opt = JuMP.objective_value(m)
        y_opt = JuMP.value.(y)
        # Affichage de la valeur optimale
        println("=== Coût problème maître ===")
        println(opt)
        println("=== Placement des VNF ===")
        for i in 1:n
            if y_opt[i] > 0
                println("VNF au nœud $i de capacité $(y_opt[i]*filtering_cap_VNF)")
            end
        end
    else
        println("Pas de solution optimale trouvée.")
        return -1, -1, -1
    end
    return opt, y_opt
end

function sub_problem(y)
    m = Model(CPLEX.Optimizer)
    set_silent(m)

    @variable(m, f[1:A, 1:P] >= 0) # Flot malveillant
    @variable(m, v[1:n], Bin) # Un flot positif passe-t-il par le noeud i ? 
    @variable(m, PHI[1:n, 1:n] >= 0) # Quantité de capacité de VNF du noeud i utilisé sur l'arc (i, j)

    # Capacité des attaques
    @constraint(m, [a in 1:A], sum(f[a, p] for p in 1:length(attack_paths[a])) <= attack_traffic[a])
    @constraint(m, [a in 1:A, p in length(attack_paths[a])+1:P], f[a, p] == 0)
    # Capacités des arcs
    @constraint(m, [i in 1:n, j in 1:n; arcs[i][j] == 1], sum(f[a, p] for a in 1:A for p in 1:length(attack_paths[a]) if (i, j) in get_arcs_within_path(attack_paths[a][p])) <= arcs_cap[i][j] + PHI[i, j])
    @constraint(m, [i in 1:n], sum(PHI[i, j] for j in 1:n if arcs[i][j] == 1) <= y[i] * filtering_cap_VNF)
    # Filtrage par les VNF
    @constraint(m, [i in 1:n], sum(f[a, p] for a in 1:A for p in 1:length(attack_paths[a]) if i in attack_paths[a][p]) <= sum(attack_traffic[a] for a in 1:A) * v[i])

    # Maximisation du flot atteignant la cible
    @objective(m, Max, sum(f[a, p] for a in 1:A for p in 1:length(attack_paths[a])) - filtering_cap_VNF * sum(y[i] * v[i] for i in 1:n))

    optimize!(m)

    if primal_status(m) == MOI.FEASIBLE_POINT
        opt = JuMP.objective_value(m)
        f_opt = JuMP.value.(f)
        v_opt = JuMP.value.(v)
        PHI_opt = JuMP.value.(PHI)

        println("\n=== Coût sous problem ===")
        println(opt)
        println("=== Construction du flot malveillant ===")
        for a in 1:A
            for p in 1:length(attack_paths[a])
                if value(f_opt[a, p]) > 0
                    println("flot malveillant de valeur $(value(f_opt[a, p])) pour l'attaque $a sur le chemin $(attack_paths[a][p])")
                end
            end
        end
    else
        println("Pas de solution optimale trouvée.")
        return -1, -1, -1, -1
    end
    return opt, f_opt, v_opt, PHI_opt
end

function column_generation_model()
    init_f = Tuple([0.0 for _ in 1:length(attack_paths[a])] for a in 1:A)
    y_opt = Vector{Float64}
    sub_opt = nothing
    master_opt = nothing
    number_of_it = 0
    uncertainty_set = []
    push!(uncertainty_set, init_f)
    stop = false
    while !stop
        println("\n=== Iteration $number_of_it ====")
        number_of_it += 1
        master_opt, y_opt = master_problem_3_bis(uncertainty_set)
        if y_opt == -1
            break
        end
        sub_opt, f_opt, v_opt, PHI_opt = sub_problem_3_bis(y_opt)
        if f_opt == -1
            break
        end
        # Si du flot malveillant atteint la cible, on continue
        if sub_opt > 0
            push!(uncertainty_set, Tuple(f_opt[i, :] for i in 1:length(sources)))
        else
            stop = true
        end
    end
    println("\n=== Solution finale ===")
    println("Coût : $master_opt")
    println("Nombre d'itérations : $number_of_it")
    for i in 1:n
        if y_opt[i] > 0
            println("VNF au nœud $i de capacité $(y_opt[i]*filtering_cap_VNF)")
        end
    end
    return master_opt, y_opt, sub_opt, number_of_it
end

column_generation_model()