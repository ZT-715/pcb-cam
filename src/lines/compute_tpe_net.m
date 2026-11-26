function tpe_nodes = compute_tpe_net(step, angle, boundaries_poly)
% COMPUTE_TPE_NET Elementos de reta paralelos que cobrem uma área.
%
%   TPE_NODES = COMPUTE_TPE_NET(STEP, ANGLE, BOUNDARIES_POLY) traça retas
%   na direção ANGLE (rad), espaçadas de STEP, e guarda cada trecho dentro
%   de BOUNDARIES_POLY como uma linha [id, linha, x_in, y_in, x_out, y_out].
    tpe_nodes = [];

    % Direção de corte e direção de varredura
    dir_vec = [cos(angle), sin(angle)];
    norm_vec = [-sin(angle), cos(angle)];
    
    [x_bound, y_bound] = boundary(boundaries_poly);
    
    [xlims, ylims] = boundingbox(boundaries_poly);
    bb_verts = [
        xlims(1), ylims(1);
        xlims(2), ylims(1);
        xlims(2), ylims(2);
        xlims(1), ylims(2)
    ];
    
    V_proj = bb_verts * norm_vec';
    U_proj = bb_verts * dir_vec';
    
    V_min = min(V_proj);
    V_max = max(V_proj);
    U_min = min(U_proj);
    U_max = max(U_proj);
    
    v_points = V_min : step : V_max;
    
    node_id = 1;
    
    for row_id = 1:length(v_points)
        v = v_points(row_id);
        
        % Reta que atravessa toda a área
        p_start = (U_min - 1) * dir_vec + v * norm_vec;
        p_end   = (U_max + 1) * dir_vec + v * norm_vec;
        
        [ix, iy] = polyxpoly([p_start(1), p_end(1)], [p_start(2), p_end(2)], x_bound, y_bound);
        
        if length(ix) < 2
            continue;
        end
        
        % Interseções em ordem ao longo da reta
        U_ints = ix * dir_vec(1) + iy * dir_vec(2);
        
        [~, sort_idx] = sort(U_ints);
        ix_sorted = ix(sort_idx);
        iy_sorted = iy(sort_idx);
        
        % Remove interseções repetidas
        coords = [ix_sorted, iy_sorted];
        keep = true(size(coords, 1), 1);
        for k = 2:size(coords, 1)
            if norm(coords(k,:) - coords(k-1,:)) < 1e-5
                keep(k) = false;
            end
        end
        coords = coords(keep, :);
        
        if size(coords, 1) < 2
            continue;
        end
        
        % Trechos dentro da área
        for k = 1:(size(coords, 1) - 1)
            pt_in  = coords(k, :);
            pt_out = coords(k+1, :);
            
            mid_pt = (pt_in + pt_out) / 2;
            
            if isinterior(boundaries_poly, mid_pt(1), mid_pt(2))
                
                tpe_nodes = [tpe_nodes; node_id, row_id, pt_in(1), pt_in(2), pt_out(1), pt_out(2)];
                
                node_id = node_id + 1;
            end
        end
    end
end