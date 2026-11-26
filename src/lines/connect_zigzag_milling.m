function final_toolpath = connect_zigzag_milling(tpe_nodes, boundaries_poly, machine_params, is_reverse_direction)
% CONNECT_ZIGZAG_MILLING Liga os elementos de reta em zigue-zague.
%
%   FINAL_TOOLPATH = CONNECT_ZIGZAG_MILLING(TPE_NODES, BOUNDARIES_POLY,
%   MACHINE_PARAMS, IS_REVERSE_DIRECTION) encadeia os elementos (linhas
%   [id, linha, x_in, y_in, x_out, y_out] de TPE_NODES) escolhendo, a cada
%   passo, a ligação em corte mais rápida entre o próximo elemento da mesma
%   linha e o da linha seguinte. Os subcaminhos resultantes são ligados por
%   CONNECT_POINTS. Retorna [M x 2] com NaN nas conexões aéreas.

    if isempty(tpe_nodes)
        final_toolpath = [];
        return;
    end

    if is_reverse_direction
        temp_in = tpe_nodes(:, 3:4);
        tpe_nodes(:, 3:4) = tpe_nodes(:, 5:6);
        tpe_nodes(:, 5:6) = temp_in;
    end

    num_nodes = size(tpe_nodes, 1);
    visited = false(num_nodes, 1);
    subpaths = {};
    first_row_id = min(tpe_nodes(:, 2));

    while ~all(visited)
        root_idx = find(~visited, 1);
        visited(root_idx) = true;
        
        current_row = tpe_nodes(root_idx, 2);
        is_forward = mod(current_row - first_row_id, 2) == 0; 
        
        [p_entry, p_exit] = get_node_points(tpe_nodes(root_idx, :), is_forward);
        current_path = [p_entry; p_exit];
        
        while true
            % Candidatos na mesma linha e na seguinte
            cands_intra = find(~visited & tpe_nodes(:, 2) == current_row);
            cands_inter = find(~visited & tpe_nodes(:, 2) == current_row + 1);
            
            [idx_intra, p_in_intra, p_out_intra] = find_closest_candidate(cands_intra, p_exit, tpe_nodes, is_forward);
            
            next_is_forward = ~is_forward;
            [idx_inter, p_in_inter, p_out_inter] = find_closest_candidate(cands_inter, p_exit, tpe_nodes, next_is_forward);
            
            cost_intra = inf;
            path_intra = [];
            if idx_intra ~= -1
                path_intra = connect_points(p_exit, p_in_intra, boundaries_poly, machine_params);
                if ~any(isnan(path_intra(:)))
                    cost_intra = route_cost([p_exit; path_intra], machine_params);
                end
            end
            
            cost_inter = inf;
            path_inter = [];
            if idx_inter ~= -1
                path_inter = connect_points(p_exit, p_in_inter, boundaries_poly, machine_params);
                if ~any(isnan(path_inter(:)))
                    cost_inter = route_cost([p_exit; path_inter], machine_params);
                end
            end
            
            % Sem ligação em corte: encerra o subcaminho
            if isinf(cost_intra) && isinf(cost_inter)
                break;
            end
            
            if cost_intra <= cost_inter
                current_path = [current_path; path_intra; p_out_intra];
                p_exit = p_out_intra;
                visited(idx_intra) = true;
            else
                current_path = [current_path; path_inter; p_out_inter];
                p_exit = p_out_inter;
                current_row = current_row + 1;
                is_forward = next_is_forward;
                visited(idx_inter) = true;
            end
        end
        
        subpaths{end+1} = current_path;
    end

    % Liga os subcaminhos pelo início mais próximo
    final_toolpath = subpaths{1};
    subpaths(1) = [];
    
    while ~isempty(subpaths)
        last_pt = final_toolpath(end, :);
        
        best_idx = 1;
        min_dist = inf;
        
        for i = 1:length(subpaths)
            first_pt = subpaths{i}(1, :);
            dist = norm(last_pt - first_pt);
            
            if dist < min_dist
                min_dist = dist;
                best_idx = i;
            end
        end
        
        target_start = subpaths{best_idx}(1, :);
        route = connect_points(last_pt, target_start, boundaries_poly, machine_params);
        
        final_toolpath = [final_toolpath; route; subpaths{best_idx}(2:end, :)];
        subpaths(best_idx) = [];
    end
end

function cost = route_cost(path_xy, machine_params)
% Tempo da conexão em corte (ou comprimento, sem parâmetros da máquina).
    cost = connection_time(path_xy, machine_params);
    if isnan(cost)
        cost = sum(sqrt(sum(diff(path_xy, 1, 1).^2, 2)));
    end
end

function [p_entry, p_exit] = get_node_points(node_row, is_forward)
    if is_forward
        p_entry = node_row(3:4); 
        p_exit  = node_row(5:6); 
    else
        p_entry = node_row(5:6); 
        p_exit  = node_row(3:4); 
    end
end

function [best_idx, p_in, p_out] = find_closest_candidate(candidates, p_exit, tpe_nodes, is_forward)
% Elemento candidato com entrada mais próxima de P_EXIT.
    best_idx = -1;
    p_in = [];
    p_out = [];
    min_dist = inf;
    
    for c = 1:length(candidates)
        idx = candidates(c);
        [cand_in, cand_out] = get_node_points(tpe_nodes(idx, :), is_forward);
        dist = norm(p_exit - cand_in);
        
        if dist < min_dist
            min_dist = dist;
            best_idx = idx;
            p_in = cand_in;
            p_out = cand_out;
        end
    end
end