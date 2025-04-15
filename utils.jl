function all_paths(arcs, start_node, end_node, path=[], paths=[])
    push!(path, start_node)  # Ajouter le nœud actuel au chemin

    if start_node == end_node
        push!(paths, copy(path))  # Si on atteint le but, on enregistre le chemin
    else
        for neighbor in 1:size(arcs, 1)
            if arcs[start_node][neighbor] == 1 && neighbor ∉ path  # Vérifier la connexion et éviter les cycles
                all_paths(arcs, neighbor, end_node, path, paths)
            end
        end
    end

    pop!(path)  # Retirer le dernier nœud pour explorer d'autres chemins
    return paths
end

function get_nodes_with_positive_flow(flow)
    N_flow = Set()
    for i in 1:n
        for a in 1:A
            for p in 1:length(attack_paths[a])
                if i in attack_paths[a][p] && flow[a][p] > 0
                    push!(N_flow, i)
                end
            end
        end
    end
    return N_flow
end

function get_arcs_within_path(path_s_t)
    arcs_path = []
    for a in partition(path_s_t, 2, 1)
        push!(arcs_path, a)
    end
    return arcs_path
end

function get_data(file_path::String)
    arcs = []
    sources = Int[]
    attack_traffic = Int[]
    cost_VNF = Int[]
    node_cap = Int[]
    arcs_cap = []
    n = 0
    t = 0
    resource_VNF = 0
    filtering_cap_VNF = 0

    mode = ""

    open(file_path, "r") do f
        for line in eachline(f)
            line = strip(line)
            if isempty(line) || startswith(line, "#")
                continue
            elseif endswith(line, ":")
                mode = strip(chop(line, tail=1))
            elseif occursin(":", line)
                parts = split(line, ":")
                mode = strip(parts[1])
                data = strip(parts[2])
                if mode == "sources"
                    sources = parse.(Int, split(data))
                elseif mode == "attack_traffic"
                    attack_traffic = parse.(Int, split(data))
                elseif mode == "n"
                    n = parse(Int, data)
                elseif mode == "t"
                    t = parse(Int, data)
                elseif mode == "cost_VNF"
                    cost_VNF = parse.(Int, split(data))
                elseif mode == "node_cap"
                    node_cap = parse.(Int, split(data))
                elseif mode == "resource_VNF"
                    resource_VNF = parse(Int, data)
                elseif mode == "filtering_cap_VNF"
                    filtering_cap_VNF = parse(Int, data)
                end
            else
                if mode == "arcs"
                    push!(arcs, parse.(Int, split(line)))
                elseif mode == "arcs_cap"
                    push!(arcs_cap, parse.(Int, split(line)))
                end
            end
        end
    end

    return (
        arcs=arcs,
        sources=sources,
        attack_traffic=attack_traffic,
        n=n,
        t=t,
        cost_VNF=cost_VNF,
        node_cap=node_cap,
        arcs_cap=arcs_cap,
        resource_VNF=resource_VNF,
        filtering_cap_VNF=filtering_cap_VNF
    )
end
