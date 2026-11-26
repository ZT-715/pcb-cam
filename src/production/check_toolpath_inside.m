function [n_out, len_out, n_seg] = check_toolpath_inside(path_xy, shape, tool_radius, tol, n_samples)
% CHECK_TOOLPATH_INSIDE Conta os segmentos de corte fora da área permitida.
%
%   [N_OUT, LEN_OUT, N_SEG] = CHECK_TOOLPATH_INSIDE(PATH_XY, SHAPE,
%   TOOL_RADIUS, TOL, N_SAMPLES) amostra cada segmento de corte de PATH_XY
%   e conta os que saem da área permitida ao centro da ferramenta. Retorna
%   o número e o comprimento desses segmentos e o total de segmentos.

    arguments
        path_xy (:, 2) double
        shape polyshape
        tool_radius (1,1) double
        tol (1,1) double = 1e-3
        n_samples (1,1) double = 5
    end

    allowed = polybuffer(shape, -(tool_radius - tol), 'JointType', 'square');

    p1 = path_xy(1:end-1, :);
    p2 = path_xy(2:end, :);
    is_cut = ~any(isnan(p1), 2) & ~any(isnan(p2), 2);
    p1 = p1(is_cut, :);
    p2 = p2(is_cut, :);
    n_seg = size(p1, 1);

    % inpolygon em blocos (memória)
    [ax, ay] = boundary(allowed);
    out = false(n_seg, 1);
    chunk = 2000;
    for t = linspace(0, 1, n_samples)
        q = p1 + t * (p2 - p1);
        for i0 = 1:chunk:n_seg
            i1 = min(i0 + chunk - 1, n_seg);
            out(i0:i1) = out(i0:i1) | ~inpolygon(q(i0:i1, 1), q(i0:i1, 2), ax, ay);
        end
    end

    n_out = sum(out);
    len_out = sum(vecnorm(p2(out, :) - p1(out, :), 2, 2));
end
