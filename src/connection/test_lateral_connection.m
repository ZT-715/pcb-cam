function [is_connected, contour_path] = test_lateral_connection(p_start, p_end, safe_space, machine_params, apply_air_check)
% TEST_LATERAL_CONNECTION Rota entre dois pontos pelo contorno da área segura.
%
%   [IS_CONNECTED, CONTOUR_PATH] = TEST_LATERAL_CONNECTION(P_START, P_END,
%   SAFE_SPACE, MACHINE_PARAMS, APPLY_AIR_CHECK) percorre o anel de
%   SAFE_SPACE que contém os dois pontos, nos dois sentidos, e fica com o
%   mais rápido. Com APPLY_AIR_CHECK (padrão), a rota só é aceita se for
%   mais rápida que uma conexão aérea. CONTOUR_PATH é [N x 2] ou [].

    arguments
        p_start (1, 2) double
        p_end (1, 2) double
        safe_space polyshape
        machine_params struct
        apply_air_check (1, 1) logical = true
    end

    is_connected = false;
    contour_path = [];
    regions = split_rings(safe_space);
    tol = 1e-4;

    % Anel que contém os dois pontos
    for r = 1:length(regions)
        island = regions{r};

        if norm(island(1,:) - island(end,:)) > tol
            island = [island; island(1,:)];
        end

        [new_island, id1, id2] = inject_points(island, p_start, p_end, tol);

        if isempty(new_island)
            continue; 
        end

        ring = new_island(1:end-1, :);

        if id1 == id2
            is_connected = true;
            contour_path = [p_start; p_end];
            return;
        end

        % Os dois sentidos do anel
        if id2 > id1
            pathA = ring(id1:id2, :);
        else
            pathA = [ring(id1:end, :); ring(1:id2, :)];
        end

        if id1 > id2
            pathB = ring(id1:-1:id2, :);
        else
            pathB = [ring(id1:-1:1, :); ring(end:-1:id2, :)];
        end

        pathA = clean_duplicates(pathA);
        pathB = clean_duplicates(pathB);

        % Sentido mais rápido
        costA = connection_time(pathA, machine_params);
        costB = connection_time(pathB, machine_params);
        if isnan(costA) || isnan(costB)
            costA = path_length(pathA);
            costB = path_length(pathB);
        end
        if costA <= costB
            best_path = pathA;
        else
            best_path = pathB;
        end

        if ~apply_air_check || prefer_contour(best_path, machine_params)
            contour_path = best_path;
            is_connected = true;
        end

        return;
    end
end

function [new_island, id1, id2] = inject_points(island, p_start, p_end, tol)
% Insere P_START e P_END como vértices do anel.
    new_island = [];
    id1 = []; 
    id2 = [];
    
    [seg1, t1] = find_segment(island, p_start, tol);
    [seg2, t2] = find_segment(island, p_end, tol);
    
    if isempty(seg1) || isempty(seg2)
        return;
    end
    
    insertions = [seg1, t1, 1; 
                  seg2, t2, 2];
    insertions = sortrows(insertions, [1, 2]);
    
    id1 = -1; id2 = -1;
    
    for i = 1:size(island, 1)-1
        new_island = [new_island; island(i, :)];
        
        idx_ins = find(insertions(:, 1) == i);
        for k = 1:length(idx_ins)
            ins = insertions(idx_ins(k), :);
            if ins(3) == 1
                new_island = [new_island; p_start];
                id1 = size(new_island, 1);
            else
                new_island = [new_island; p_end];
                id2 = size(new_island, 1);
            end
        end
    end
    new_island = [new_island; island(end, :)];
end

function [seg_idx, t] = find_segment(island, pt, tol)
% FIND_SEGMENT Aresta do anel que contém PT (a menos de TOL) e a posição t.
    seg_idx = []; t = [];
    min_dist = inf;
    
    for i = 1:size(island, 1)-1
        v1 = island(i, :);
        v2 = island(i+1, :);
        v12 = v2 - v1;
        L2 = sum(v12.^2);

        if L2 < eps
            dist = norm(pt - v1);
            t_curr = 0;
        else
            v1p = pt - v1;
            t_curr = max(0, min(1, sum(v1p .* v12) / L2));
            proj = v1 + t_curr * v12;
            dist = norm(pt - proj);
        end
        
        if dist < tol && dist < min_dist
            min_dist = dist;
            seg_idx = i;
            t = t_curr;
        end
    end
    
    if min_dist > tol
        seg_idx = [];
    end
end

function clean_path = clean_duplicates(path)
    if size(path, 1) < 2
        clean_path = path;
        return;
    end
    dists = sum(diff(path).^2, 2);
    keep = [true; dists > 1e-6];
    clean_path = path(keep, :);
end

function L = path_length(path)
    if size(path, 1) < 2
        L = 0;
    else
        L = sum(sqrt(sum(diff(path).^2, 2)));
    end
end