using JuMP
using CPLEX

include("utils.jl")

arcs, sources, attack_traffic, n, t, cost_VNF, node_cap, arcs_cap, resource_VNF, 
        filtering_cap_VNF = get_data("./instances/instance_1.txt")

A = length(sources)
attack_paths = [all_paths(arcs, sources[a], t) for a in 1:A]
P = maximum(length.(attack_paths))
penalty = 100
M = 1e5   # Constante Big-M


# ------------------------------
# Fonction qui résout la formulation duale du problème bi-niveau modélisé sur les arcs
# Ne résout pas le problème dans son entier mais place seulement les VNF 
# étant donné un chemin optimal du hacker

function bi_level_dual_arc_formulation(arcs, sources, n, t, attack_paths, attack_traffic, 
            arcs_cap, node_cap, cost_VNF, filtering_cap_VNF, penalty)

    model = Model(CPLEX.Optimizer)

    # Variables
    @variable(model, y[i in 1:n] >= 0, Int)
    @variable(model, x[i in 1:n, j in 1:n] >= 0)
    @variable(model, lambda[i in 1:n, j in 1:n] >= 0)
    @variable(model, mu[s in sources])
    @variable(model, theta[i in 1:n])
    @variable(model, delta[i in 1:n, j in 1:n], Bin)

    # Function Objectif
    @objective(model, Min, sum(cost_VNF[i] * y[i] for i in 1:n) + penalty * sum(x[i, t] for i in 1:n))

    # Ressource du noeud 
    @constraint(model, [i in 1:n], filtering_cap_VNF * y[i] <= node_cap[i])

    # Pas de VNF aux sources ou sur la cible
    @constraint(model, [i in sources], y[i] == 0)
    @constraint(model, y[t] == 0)

    # Contraintes du Primal
    @constraint(model, [i in 1:n, j in 1:n], x[i, j] <= arcs_cap[i][j])
    @constraint(model, [s in sources], sum(x[s, j] for j in 1:n if arcs[s][j] == 1) == attack_traffic[s])
    @constraint(model, [i in 3:n-1], sum(x[j, i] for j in 1:n if arcs[j][i] == 1) == sum(x[i, j] for j in 1:n if arcs[i][j] == 1) + filtering_cap_VNF * y[i])

    # Contraintes de KKT
    for i in 1:n
        for j in 1:n
            # Représente la contrainte à appliquer pour chaque arc (i,j)
            @constraint(model,
                arcs[i][j] * ifelse(j == t, 1, 0) - lambda[i, j] + sum(mu[s] * arcs[i][j] * ifelse(i == s, 1, 0) for s in sources) - theta[i] + theta[j] == 0
            )
        end
    end
    @constraint(model, [i in 1:n, j in 1:n], x[i, j] - arcs_cap[i][j] <= M * (1 - delta[i, j]))
    @constraint(model, [i in 1:n, j in 1:n], lambda[i, j] <= M * delta[i, j])

    optimize!(model)

    feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(model) == MOI.OPTIMAL

    if feasibleSolutionFound
        println("\n=== Coût total ===")
        println(JuMP.objective_value(model))
        println("\n=== Placement des VNF ===")
        for i in 1:n
            if value(y[i]) > 0.5
                println("VNF au nœud: $(i) : $(value(y[i])) VNF de capacité $filtering_cap_VNF")
            end
        end
    else 
        println("Infeasible")
    end
end


bi_level_dual_arc_formulation(arcs, sources, n, t, attack_paths, attack_traffic, arcs_cap, 
        node_cap, cost_VNF, filtering_cap_VNF, penalty)