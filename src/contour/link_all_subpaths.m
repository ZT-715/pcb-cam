function sequence = link_all_subpaths(TPENet, sub_paths, safe_space, machine_params)
% LINK_ALL_SUBPATHS Ordena e liga os subcaminhos em uma única trajetória.
%
%   SEQUENCE = LINK_ALL_SUBPATHS(TPENET, SUB_PATHS, SAFE_SPACE,
%   MACHINE_PARAMS) escolhe sempre o subcaminho cujo início é o mais
%   próximo do fim do anterior e liga os dois por CONNECT_POINTS (em corte
%   ou aéreo). Retorna [N x 2] com NaN nas conexões aéreas.
    num_sp = length(sub_paths);
    
    function [sx, sy, ex, ey] = get_sp_terminals(sp_idx)
        nodes = sub_paths{sp_idx};
        start_node = TPENet(nodes(1));
        end_node = TPENet(nodes(end));
        sx = start_node.traj_x(1); sy = start_node.traj_y(1);
        ex = end_node.traj_x(end); ey = end_node.traj_y(end);
    end

    function pts = get_sp_points(sp_idx)
        nodes_sp = sub_paths{sp_idx};
        pts = zeros(0, 2);
        has_entry = isfield(TPENet, 'entry_path');
        for jj = 1:length(nodes_sp)
            nid = nodes_sp(jj);
            if jj > 1 && has_entry && ~isempty(TPENet(nid).entry_path)
                pts = [pts; TPENet(nid).entry_path]; %#ok<AGROW>
            end
            pts = [pts; TPENet(nid).traj_x(:), TPENet(nid).traj_y(:)]; %#ok<AGROW>
        end
    end
    
    % Ordem: subcaminho de início mais próximo
    visited_sp = false(1, num_sp);
    linked_sequence = zeros(1, num_sp);
    
    curr_sp = 1;
    visited_sp(curr_sp) = true;
    linked_sequence(1) = curr_sp;
    
    [~, ~, curr_ex, curr_ey] = get_sp_terminals(curr_sp);
    
    for step = 2:num_sp
        min_dist = inf; 
        next_sp = -1;
        
        for cand = 1:num_sp
            if ~visited_sp(cand)
                [sx, sy, ~, ~] = get_sp_terminals(cand);
                dist = sqrt((sx - curr_ex)^2 + (sy - curr_ey)^2);
                if dist < min_dist
                    min_dist = dist; 
                    next_sp = cand;
                end
            end
        end
        
        curr_sp = next_sp;
        visited_sp(curr_sp) = true;
        linked_sequence(step) = curr_sp;
        [~, ~, curr_ex, curr_ey] = get_sp_terminals(curr_sp);
    end

    % Conexões
    sequence_blocks = {};
    
    first_sp = linked_sequence(1);
    sequence_blocks{end+1} = get_sp_points(first_sp);
    
    for step = 1:(num_sp - 1)
        curr_sp = linked_sequence(step);
        next_sp = linked_sequence(step + 1);
        
        [~, ~, curr_ex, curr_ey] = get_sp_terminals(curr_sp);
        [next_sx, next_sy, ~, ~] = get_sp_terminals(next_sp);
        
        next_sp_points = get_sp_points(next_sp);
        
        pt_start = [curr_ex, curr_ey];
        pt_end = [next_sx, next_sy];

        route_path = connect_points(pt_start, pt_end, safe_space, machine_params);
        
        sequence_blocks{end+1} = route_path;
        sequence_blocks{end+1} = next_sp_points;

    end
    
    sequence = cat(1, sequence_blocks{:});
end