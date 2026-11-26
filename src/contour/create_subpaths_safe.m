function [TPENet, sub_paths] =  create_subpaths_safe(TPENet, tool_radius, safe_area, machine_params, direction, reverse_paths, path_interval, conventional)
% CREATE_SUBPATHS_SAFE Agrupa os nós da TPE Net em subcaminhos contínuos.
%
%   [TPENET, SUB_PATHS] = CREATE_SUBPATHS_SAFE(TPENET, TOOL_RADIUS,
%   SAFE_AREA, MACHINE_PARAMS, DIRECTION, REVERSE_PATHS, PATH_INTERVAL,
%   CONVENTIONAL) percorre os nós em níveis (DIRECTION =
%   "external_to_internal" ou "internal_to_external") e encadeia cada nó ao
%   seguinte quando há entrada em corte dentro de SAFE_AREA. SUB_PATHS{k}
%   lista os índices dos nós do k-ésimo subcaminho; TPENET recebe a
%   trajetória (traj_x, traj_y) e a rota de entrada de cada nó.
%   REVERSE_PATHS inverte o sentido dos anéis; CONVENTIONAL orienta os anéis
%   para fresamento discordante (M03). PATH_INTERVAL é o passo entre
%   contornos (padrão: de MACHINE_PARAMS).

    arguments
        TPENet struct
        tool_radius double
        safe_area polyshape
        machine_params struct
        direction string = "internal_to_external"
        reverse_paths logical = false
        path_interval double = NaN
        conventional logical = false
    end

    sub_paths = {};
    if isempty(TPENet)
        return;
    end

    if isnan(path_interval)
        if all(isfield(machine_params, {'tool_diameter', 'overlap'}))
            path_interval = machine_params.tool_diameter * (1 - machine_params.overlap);
        else
            path_interval = 2 * tool_radius;
        end
    end
    % Distância máxima até a entrada do próximo nó
    entry_limit = max(1.5 * path_interval, sqrt(2) * tool_radius);
    max_candidates = 6; % pontos de entrada testados por nó
    
    max_offset = max([TPENet.offset_num]);
    min_offset = min([TPENet.offset_num]);
    
    if strcmpi(direction, "external_to_internal")
        start_levels = min_offset:max_offset;
        get_linked_nodes = @(node) node.children;
    else
        start_levels = max_offset:-1:min_offset;
        get_linked_nodes = @(node) node.parents;
    end
    
    while true
        % Primeiro nó não visitado
        start_id = -1;
        for lvl = start_levels
            cands = find([TPENet.offset_num] == lvl & ~[TPENet.visited]);
            if ~isempty(cands)
                start_id = cands(1); 
                break;
            end
        end
        
        if start_id == -1, break; end
        
        curr_sp = [];
        curr_id = start_id;
        prev_end_pt = [];
        
        while curr_id ~= -1
            if TPENet(curr_id).is_cleanup
                bx = TPENet(curr_id).traj_x(:);
                by = TPENet(curr_id).traj_y(:);
                is_ring = numel(bx) > 2 && bx(1) == bx(end) && by(1) == by(end);
            else
                [bx, by] = boundary(TPENet(curr_id).poly);
                
                nan_idx = find(isnan(bx), 1);
                if ~isempty(nan_idx)
                    bx = bx(1:nan_idx-1);
                    by = by(1:nan_idx-1);
                end
                
                if conventional && numel(bx) > 2
                    % Área com sinal > 0: anti-horário
                    is_ccw = sum(bx .* circshift(by, -1) - circshift(bx, -1) .* by) > 0;
                    want_ccw = isfield(TPENet, 'is_hole') && ~isempty(TPENet(curr_id).is_hole) ...
                        && TPENet(curr_id).is_hole;
                    if is_ccw ~= want_ccw
                        bx = flip(bx);
                        by = flip(by);
                    end
                end
                if reverse_paths
                    bx = flip(bx);
                    by = flip(by);
                end
                if length(bx) > 1 && (bx(1) ~= bx(end) || by(1) ~= by(end))
                    bx(end+1) = bx(1); %#ok<AGROW>
                    by(end+1) = by(1); %#ok<AGROW>
                end
                is_ring = true;
            end

            accepted = false;
            entry_route = zeros(0, 2);

            if isempty(prev_end_pt)
                accepted = true;
            elseif is_ring
                % Anel: entra pelo ponto mais próximo das arestas
                ring = [bx(1:end-1), by(1:end-1)];
                cand = ring_entry_candidates(ring, prev_end_pt, entry_limit, max_candidates);
                for k = 1:size(cand, 1)
                    new_ring = rotate_ring(ring, cand(k, :));
                    route_path = connect_points(prev_end_pt, new_ring(1, :), safe_area, machine_params);
                    if ~isempty(route_path) && ~any(isnan(route_path(:)))
                        bx = new_ring(:, 1);
                        by = new_ring(:, 2);
                        entry_route = route_path(1:end-1, :);
                        accepted = true;
                        break;
                    end
                end
            else
                % Trajetória aberta: entra pelo extremo mais próximo
                d1 = (bx(1)-prev_end_pt(1))^2 + (by(1)-prev_end_pt(2))^2;
                d2 = (bx(end)-prev_end_pt(1))^2 + (by(end)-prev_end_pt(2))^2;
                if d2 < d1
                    bx = flip(bx);
                    by = flip(by);
                end
                pt_target = [bx(1), by(1)];
                if norm(pt_target - prev_end_pt) <= entry_limit
                    route_path = connect_points(prev_end_pt, pt_target, safe_area, machine_params);
                    if ~isempty(route_path) && ~any(isnan(route_path(:)))
                        entry_route = route_path(1:end-1, :);
                        accepted = true;
                    end
                end
            end

            if ~accepted
                break;
            end

            TPENet(curr_id).traj_x = bx;
            TPENet(curr_id).traj_y = by;
            TPENet(curr_id).entry_path = entry_route;
            prev_end_pt = [bx(end), by(end)];
            TPENet(curr_id).visited = true;
            curr_sp(end+1) = curr_id; %#ok<AGROW>
            
            next_id = -1;
            linked_nodes = get_linked_nodes(TPENet(curr_id));
            for p = linked_nodes
                if ~TPENet(p).visited
                    next_id = p; 
                    break;
                end
            end
            curr_id = next_id;
        end
        
        sub_paths{end+1} = curr_sp; %#ok<AGROW>
    end
end

function cand = ring_entry_candidates(ring, pt, limit, max_candidates)
% RING_ENTRY_CANDIDATES Pontos do anel mais próximos de PT, por aresta.
%   Retorna até MAX_CANDIDATES linhas [aresta, t, x, y] a até LIMIT de PT.
    v1 = ring;
    v2 = ring([2:end, 1], :);
    v12 = v2 - v1;
    L2 = sum(v12.^2, 2);
    t = sum((pt - v1) .* v12, 2) ./ max(L2, eps);
    t = max(0, min(1, t));
    proj = v1 + t .* v12;
    d = vecnorm(proj - pt, 2, 2);

    idx = find(d <= limit);
    [~, order] = sort(d(idx));
    idx = idx(order);

    cand = zeros(0, 4);
    for k = 1:numel(idx)
        q = proj(idx(k), :);
        if ~isempty(cand) && any(vecnorm(cand(:, 3:4) - q, 2, 2) < 1e-6)
            continue;
        end
        cand(end+1, :) = [idx(k), t(idx(k)), q]; %#ok<AGROW>
        if size(cand, 1) >= max_candidates
            break;
        end
    end
end

function new_ring = rotate_ring(ring, cand)
% ROTATE_RING Anel fechado que começa e termina no ponto de entrada CAND.
    n = size(ring, 1);
    i = cand(1);
    q = cand(3:4);
    j = mod(i, n) + 1;

    if norm(q - ring(i, :)) < 1e-6
        new_ring = [ring(i:end, :); ring(1:i-1, :); ring(i, :)];
    elseif norm(q - ring(j, :)) < 1e-6
        new_ring = [ring(j:end, :); ring(1:j-1, :); ring(j, :)];
    else
        if j == 1
            new_ring = [q; ring; q];
        else
            new_ring = [q; ring(j:end, :); ring(1:i, :); q];
        end
    end
end

