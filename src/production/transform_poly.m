function out = transform_poly(poly, point_map)
% TRANSFORM_POLY Aplica uma transformação de pontos a um polyshape.
%
%   OUT = TRANSFORM_POLY(POLY, POINT_MAP) aplica POINT_MAP (@(P) [N x 2])
%   aos vértices de POLY, mantendo furos e ilhas.

    out = poly;
    for k = 1:numel(poly)
        if poly(k).NumRegions == 0
            continue;
        end
        V = point_map(poly(k).Vertices);
        w = warning('off', 'MATLAB:polyshape:repairedBySimplify');
        out(k) = polyshape(V);
        warning(w);
    end
end
