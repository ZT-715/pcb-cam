function final_toolpath = connect_oneway_milling(tpe_nodes, boundaries_poly, machine_params, is_reverse_direction)
% CONNECT_ONEWAY_MILLING Liga os elementos de reta em corte unidirecional.
%
%   FINAL_TOOLPATH = CONNECT_ONEWAY_MILLING(TPE_NODES, BOUNDARIES_POLY,
%   MACHINE_PARAMS, IS_REVERSE_DIRECTION) corta todos os elementos no mesmo
%   sentido. Na mesma linha, contorna obstáculos em corte quando possível;
%   entre linhas e entre subcaminhos, a ferramenta é retraída. Retorna
%   [M x 2] com NaN nas conexões aéreas.

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

    while ~all(visited)
        root_idx = find(~visited, 1);
        visited(root_idx) = true;
        
        current_row = tpe_nodes(root_idx, 2);
        p_exit = tpe_nodes(root_idx, 5:6);
        
        current_path = [tpe_nodes(root_idx, 3:4); p_exit];
        
        while true
            % Próximo elemento da mesma linha, contornando o obstáculo
            next_in_row_idx = find(~visited & tpe_nodes(:, 2) == current_row, 1);
            
            if ~isempty(next_in_row_idx)
                p_next_in = tpe_nodes(next_in_row_idx, 3:4);
                
                [is_connected, contour_path] = test_lateral_connection(p_exit, p_next_in, boundaries_poly, machine_params);
                
                if is_connected
                    current_path = [current_path; contour_path(2:end, :); tpe_nodes(next_in_row_idx, 5:6)];
                    p_exit = tpe_nodes(next_in_row_idx, 5:6);
                    visited(next_in_row_idx) = true;
                    continue;
                end
            end
            
            % Próxima linha, com retração
            next_row_candidates = find(~visited & tpe_nodes(:, 2) == current_row + 1);
            
            if isempty(next_row_candidates)
                break;
               
            else
                next_row_idx = next_row_candidates(1);
                
                p_in_new = tpe_nodes(next_row_idx, 3:4);
                p_exit_new = tpe_nodes(next_row_idx, 5:6);

                current_path = [current_path; NaN, NaN; p_in_new; p_exit_new];
                
                p_exit = p_exit_new;
                current_row = current_row + 1;
                visited(next_row_idx) = true;
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
        
        final_toolpath = [final_toolpath; NaN, NaN; subpaths{best_idx}];
        subpaths(best_idx) = [];
    end
end