function connection_path = connect_points(pt_start, pt_end, safe_space, machine_params)
% CONNECT_POINTS Ligação mais rápida entre dois pontos.
%
%   CONNECTION_PATH = CONNECT_POINTS(PT_START, PT_END, SAFE_SPACE,
%   MACHINE_PARAMS) segue a reta onde ela está dentro de SAFE_SPACE e o
%   contorno onde sai dela, e compara o tempo dessa rota em corte com o de
%   uma conexão aérea. Retorna a rota sem PT_START: [p2; ...; PT_END] em
%   corte ou [NaN NaN; PT_END] aérea.

    arguments
        pt_start (1, 2) double
        pt_end (1, 2) double
        safe_space polyshape
        machine_params struct
    end

    [bx, by] = boundary(safe_space);
    [xi, yi] = polyxpoly([pt_start(1), pt_end(1)], [pt_start(2), pt_end(2)], bx, by);
    
    % A reta pode sair da área mesmo sem interseções (extremos no contorno)
    t_mid = [0.25; 0.5; 0.75];
    mid_pts = pt_start + t_mid .* (pt_end - pt_start);
    chord_inside = all(isinterior(safe_space, mid_pts(:, 1), mid_pts(:, 2)));

    if isempty(xi) && chord_inside && isinterior(safe_space, pt_start(1), pt_start(2))
        connection_path = pt_end;
    else
        intersect_pts = unique([xi, yi], 'rows');
        if ~isempty(intersect_pts)
            dists = sum((intersect_pts - pt_start).^2, 2);
            [~, sort_idx] = sort(dists);
            intersect_pts = intersect_pts(sort_idx, :);
        end
        
        route_pts = [pt_start; intersect_pts; pt_end];
        n_pts = size(route_pts, 1);
        valid_connection = true;
        temp_sequence = [];

        % Anel de cada ponto (0 = nenhum)
        rings = split_rings(safe_space);
        ring_id = zeros(n_pts, 1);
        for i = 1:n_pts
            ring_id(i) = find_ring(rings, route_pts(i, :), 1e-4);
        end

        k = 1;
        while k < n_pts
            p1 = route_pts(k, :);
            p2 = route_pts(k+1, :);

            mid_pt = (p1 + p2) / 2;

            if isinterior(safe_space, mid_pt(1), mid_pt(2))
                % Trecho interno: reta
                temp_sequence = [temp_sequence; p2];
                k = k + 1;
            else
                % Trecho externo: contorno até o último ponto do mesmo anel
                j = k + 1;
                if ring_id(k) > 0
                    last_same = find(ring_id(k+1:end) == ring_id(k), 1, 'last');
                    if ~isempty(last_same)
                        j = k + last_same;
                    end
                end

                [is_connected, contour_path] = test_lateral_connection(p1, route_pts(j, :), safe_space, machine_params, false);
                if is_connected
                    temp_sequence = [temp_sequence; contour_path(2:end, :)];
                    k = j;
                else
                    valid_connection = false;
                    break;
                end
            end
        end
        
        if valid_connection
            connection_path = temp_sequence;
        else
            connection_path = [NaN, NaN; pt_end(1), pt_end(2)];
            return;
        end
    end

    % Rota em corte ou conexão aérea, pelo tempo
    if ~prefer_contour([pt_start; connection_path], machine_params)
        connection_path = [NaN, NaN; pt_end(1), pt_end(2)];
    end
end

function ring_idx = find_ring(rings, pt, tol)
% FIND_RING Índice do anel mais próximo de PT, se estiver a menos de TOL.
    ring_idx = 0;
    best = tol;
    for r = 1:length(rings)
        ring = rings{r};
        v1 = ring(1:end-1, :);
        v12 = ring(2:end, :) - v1;
        L2 = sum(v12.^2, 2);
        t = sum((pt - v1) .* v12, 2) ./ max(L2, eps);
        t = max(0, min(1, t));
        d = min(vecnorm(pt - (v1 + t .* v12), 2, 2));
        if d <= best
            best = d;
            ring_idx = r;
        end
    end
end