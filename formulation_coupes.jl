using JuMP
using CPLEX

include("utils.jl")

arcs, sources, attack_traffic, n, t, cost_VNF, node_cap, arcs_cap, resource_VNF, 
        filtering_cap_VNF = get_data("./instances/instance_1.txt")

A = length(sources)
attack_paths = [all_paths(arcs, sources[a], t) for a in 1:A]
cost_VNF_by_unit = ceil.(Int, cost_VNF ./ filtering_cap_VNF)

# -----------------------------------------
# Fonction de Coupe minimale sur les noeuds
function min_cut(arcs, sources, n, A, t, attack_paths, attack_traffic, arcs_cap, cost_VNF_by_unit)
    n = length(arcs)
    nodes = 1:n
    node_in = Dict(i => 2i - 1 for i in nodes)
    node_out = Dict(i => 2i for i in nodes)
    N = 2n  # nombre total de nœuds transformés

    # Construction du graphe transformé
    transformed_arcs = []

    # Arcs internes (i_in → i_out)
    for i in nodes
        if i != t
            push!(transformed_arcs, (node_in[i], node_out[i]))
        end
    end

    # Arcs originaux (i_out → j_in)
    for i in nodes, j in nodes
        if arcs[i][j] == 1
            push!(transformed_arcs, (node_out[i], node_in[j]))
        end
    end

    # Capacités des arcs originaux
    BIG = 10^6
    k = Dict{Tuple{Int, Int}, Int}((i, j) => BIG for (i, j) in transformed_arcs)
    c = Dict{Tuple{Int, Int}, Int}((i, j) => BIG for (i, j) in transformed_arcs)


    for i in nodes
        total_flux = sum(any(i in path for path in all_paths(arcs, s, t)) * attack_traffic[s] for s in sources)
        cap_max = sum(arcs_cap[j][i] for j in nodes)
        k[(node_in[i], node_out[i])] = min(cap_max, total_flux)
        c[(node_in[i], node_out[i])] = cost_VNF_by_unit[i]
    end

    # Model Min Cut
    model = Model(CPLEX.Optimizer)

    @variable(model, x[transformed_arcs], Bin)
    @objective(model, Min, sum(c[(i, j)] * k[(i,j)] * x[(i,j)] for (i,j) in transformed_arcs))

    # Les sources ne peuvent pas avoir de VNF
    for s in sources
        @constraint(model, x[(node_in[s], node_out[s])] == 0)
    end

    # Contraintes de coupure : au moins un arc coupé par chemin source - cible
    for a in 1:A
        for path in attack_paths[a]
            transformed_path = []
            for i in 1:length(path)-1
                u = path[i]
                v = path[i+1]
                push!(transformed_path, (node_out[u], node_in[v]))  # arc de transit
            end
            # Ajouter les arcs internes de type i_in → i_out
            for i in path
                if i != t
                    push!(transformed_path, (node_in[i], node_out[i]))
                end
            end
            @constraint(model, sum(x[arc] for arc in transformed_path if arc in transformed_arcs) >= 1)
        end
    end

    # Résolution
    optimize!(model)

    # Affichage de la valeur optimale
    if termination_status(model) == MOI.OPTIMAL
        println("\n=== Coût total ===")
        println(objective_value(model))
    else
        println("Pas de solution optimale trouvée.")
    end

    println("\n=== Placement des VNF ===")
    for arc in transformed_arcs
        if value(x[arc]) > 0.5
            println("VNF au nœud $(div(arc[1] + 1, 2)), de capacité $(k[arc])")
        end
    end
end

min_cut(arcs, sources, n, A, t, attack_paths, attack_traffic, arcs_cap, cost_VNF_by_unit)