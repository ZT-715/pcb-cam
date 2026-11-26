function [path, tab_points] = plan_outline_cut(outline, offset_radius, tool_diameter, tab_length, climb)
% PLAN_OUTLINE_CUT Recorte externo da placa com offset positivo e abas.
%
%   [PATH, TAB_POINTS] = PLAN_OUTLINE_CUT(OUTLINE, OFFSET_RADIUS,
%   TOOL_DIAMETER, TAB_LENGTH, CLIMB) percorre o contorno da placa com
%   offset OFFSET_RADIUS: primeiro os recortes internos, depois o externo,
%   com duas abas (esquerda e direita) de largura TAB_LENGTH. CLIMB = true
%   faz corte concordante. PATH é [N x 2] (NaN = retração); TAB_POINTS são
%   os centros das abas.

    arguments
        outline polyshape
        offset_radius (1,1) double {mustBePositive}
        tool_diameter (1,1) double {mustBePositive}
        tab_length (1,1) double {mustBeNonnegative} = 0
        climb (1,1) logical = true
    end

    region = polybuffer(union(outline), offset_radius, 'JointType', 'round');
    holes_flag = ishole(region);

    inner = {};
    outer = {};
    for b = 1:numboundaries(region)
        [x, y] = boundary(region, b);
        ring = [x, y];
        if norm(ring(1, :) - ring(end, :)) > 1e-9
            ring = [ring; ring(1, :)]; %#ok<AGROW>
        end
        if holes_flag(b)
            inner{end+1} = orient(ring, ~climb); %#ok<AGROW>
        else
            outer{end+1} = orient(ring, climb); %#ok<AGROW>
        end
    end

    path = zeros(0, 2);
    tab_points = zeros(0, 2);

    for k = 1:numel(inner)
        path = [path; NaN, NaN; inner{k}]; %#ok<AGROW>
    end

    gap = tab_length + tool_diameter;
    for k = 1:numel(outer)
        ring = outer{k};
        if tab_length <= 0
            path = [path; NaN, NaN; ring]; %#ok<AGROW>
            continue;
        end

        [pieces, tabs] = cut_with_tabs(ring, gap);
        for p = 1:numel(pieces)
            path = [path; NaN, NaN; pieces{p}]; %#ok<AGROW>
        end
        tab_points = [tab_points; tabs]; %#ok<AGROW>
    end
end

function ring = orient(ring, clockwise)
    if ispolycw(ring(:, 1), ring(:, 2)) ~= clockwise
        ring = flipud(ring);
    end
end

function [pieces, tabs] = cut_with_tabs(ring, gap)
% Divide o anel em dois trechos, sem o intervalo GAP em cada aba.
    seg_len = vecnorm(diff(ring, 1, 1), 2, 2);
    s = [0; cumsum(seg_len)];
    perimeter = s(end);

    if 2 * gap >= perimeter
        error('pcb_cam:tabs', 'Abas maiores que o perímetro do recorte.');
    end

    % Abas na altura do centro do contorno
    yc = (min(ring(:, 2)) + max(ring(:, 2))) / 2;
    xr = [min(ring(:, 1)) - 1, max(ring(:, 1)) + 1];
    [xi, yi] = polyxpoly(xr, [yc yc], ring(:, 1), ring(:, 2));
    if numel(xi) < 2
        error('pcb_cam:tabs', 'Não foi possível posicionar as abas.');
    end
    [~, il] = min(xi);
    [~, ir] = max(xi);
    tabs = [xi(il), yi(il); xi(ir), yi(ir)];

    s_left = arc_position(ring, s, tabs(1, :));
    s_right = arc_position(ring, s, tabs(2, :));

    d1 = mod(s_left - s_right, perimeter);
    d2 = perimeter - d1;
    if min(d1, d2) <= gap
        error('pcb_cam:tabs', 'As abas se sobrepõem.');
    end

    pieces = {ring_slice(ring, s, s_right + gap / 2, s_left - gap / 2), ...
              ring_slice(ring, s, s_left + gap / 2, s_right - gap / 2)};
end

function pos = arc_position(ring, s, pt)
% Posição (comprimento de arco) do ponto PT sobre o anel.
    best = inf;
    pos = 0;
    for i = 1:size(ring, 1) - 1
        v1 = ring(i, :);
        v12 = ring(i + 1, :) - v1;
        L2 = sum(v12.^2);
        if L2 < eps
            continue;
        end
        t = max(0, min(1, dot(pt - v1, v12) / L2));
        d = norm(pt - (v1 + t * v12));
        if d < best
            best = d;
            pos = s(i) + t * sqrt(L2);
        end
    end
end

function piece = ring_slice(ring, s, a, b)
% Trecho do anel entre os comprimentos de arco A e B.
    P = s(end);
    a = mod(a, P);
    b = mod(b, P);
    if b <= a
        b = b + P;
    end

    ring2 = [ring; ring(2:end, :)];
    s2 = [s; s(2:end) + P];

    inside = s2 > a & s2 < b;
    piece = [interp_at(ring2, s2, a); ring2(inside, :); interp_at(ring2, s2, b)];
end

function pt = interp_at(ring, s, q)
    i = find(s <= q, 1, 'last');
    if i >= numel(s)
        pt = ring(end, :);
        return;
    end
    t = (q - s(i)) / max(s(i + 1) - s(i), eps);
    pt = ring(i, :) + t * (ring(i + 1, :) - ring(i, :));
end
