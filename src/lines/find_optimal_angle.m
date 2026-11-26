function opt_angle = find_optimal_angle(poly_in)
% FIND_OPTIMAL_ANGLE Direção das retas paralelas para uma área.
%
%   OPT_ANGLE = FIND_OPTIMAL_ANGLE(POLY_IN) testa as direções das arestas
%   de POLY_IN e escolhe a de menos máximos locais na direção perpendicular
%   (menos divisões da trajetória); no empate, a de menor largura. Em rad.
    [x, y] = boundary(poly_in);
    
    valid_idx = ~isnan(x);
    x = x(valid_idx);
    y = y(valid_idx);
    
    if x(1) == x(end) && y(1) == y(end)
        x(end) = [];
        y(end) = [];
    end
    
    dx = x([2:end, 1]) - x;
    dy = y([2:end, 1]) - y;
    
    angles_rad = mod(atan2(dy, dx), pi);
    
    unique_angles = unique(round(angles_rad, 4));
    
    best_cost = inf;
    opt_angle = 0;
    
    for i = 1:length(unique_angles)
        theta = unique_angles(i);
        
        R = [cos(-theta) -sin(-theta); 
             sin(-theta)  cos(-theta)];
         
        pts_rot = [x, y] * R';
        y_rot = pts_rot(:, 2);
        
        dy_rot = diff([y_rot; y_rot(1)]);
        
        dy_rot(abs(dy_rot) < 1e-6) = []; 
        dir_changes = sign(dy_rot);
        
        % Máximos locais na direção de varredura
        peaks = sum(diff(dir_changes) < 0);
        
        span = max(y_rot) - min(y_rot);
        
        cost = peaks * 1e6 + span;
        
        if cost < best_cost
            best_cost = cost;
            opt_angle = theta;
        end
    end
end