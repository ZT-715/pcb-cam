function rings = split_rings(poly)
% SPLIT_RINGS Separa as fronteiras de um polyshape em anéis fechados.
%
%   RINGS = SPLIT_RINGS(POLY) devolve um cell array com cada contorno de
%   POLY como matriz [N x 2] fechada.

    [xb, yb] = boundary(poly);
    tol = 1e-4;

    nan_indices = find(isnan(xb));
    rings = {};
    start_id = 1;
    for i = 1:length(nan_indices)
        if nan_indices(i) > start_id
            rings{end+1} = [xb(start_id:nan_indices(i)-1), yb(start_id:nan_indices(i)-1)]; %#ok<AGROW>
        end
        start_id = nan_indices(i) + 1;
    end
    if start_id <= length(xb)
        rings{end+1} = [xb(start_id:end), yb(start_id:end)];
    end

    for r = 1:length(rings)
        ring = rings{r};
        if norm(ring(1,:) - ring(end,:)) > tol
            rings{r} = [ring; ring(1,:)];
        end
    end
end
