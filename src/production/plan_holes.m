function [path, warnings_out] = plan_holes(holes, tool_diameter, overlap, tolerance, machine_params)
% PLAN_HOLES Gera a trajetória de fresamento dos furos (esvaziamento completo).
%
%   [PATH, WARNINGS_OUT] = PLAN_HOLES(HOLES, TOOL_DIAMETER, OVERLAP,
%   TOLERANCE, MACHINE_PARAMS) recebe HOLES [N x 3] = [x, y, diâmetro] e
%   devolve a trajetória [M x 2] (NaN entre furos). Furos maiores que a
%   ferramenta são esvaziados do centro para a borda; os demais recebem um
%   mergulho no centro. A ordem é a do vizinho mais próximo.

    path = zeros(0, 2);
    warnings_out = {};
    if isempty(holes)
        return;
    end

    r_tool = tool_diameter / 2;
    step = tool_diameter * (1 - overlap);

    order = nearest_order(holes(:, 1:2), [0 0]);

    for k = order
        c = holes(k, 1:2);
        d = holes(k, 3);
        hole_path = [];

        if d > tool_diameter + tolerance
            circ = nsidedpoly(64, 'Center', c, 'Radius', d / 2);
            if area(polybuffer(circ, -r_tool - 1e-5, 'JointType', 'square')) > 1e-9
                try
                    hole_path = contour_parallel(circ, r_tool, 0, step, ...
                        machine_params, false, false, 0, false, false, ...
                        "internal_to_external")';
                catch err
                    warnings_out{end+1} = sprintf('Furo em (%.2f, %.2f): esvaziamento falhou (%s).', ...
                        c(1), c(2), err.message); %#ok<AGROW>
                    hole_path = [];
                end
            end
        elseif d < tool_diameter - tolerance
            warnings_out{end+1} = sprintf('Furo em (%.2f, %.2f) menor que a ferramenta.', ...
                c(1), c(2)); %#ok<AGROW>
        end

        if isempty(hole_path) || all(isnan(hole_path(:)))
            hole_path = c;
        end

        path = [path; NaN, NaN; hole_path]; %#ok<AGROW>
    end
end

function order = nearest_order(P, start)
    n = size(P, 1);
    order = zeros(1, n);
    visited = false(n, 1);
    curr = start;
    for i = 1:n
        d = sum((P - curr).^2, 2);
        d(visited) = inf;
        [~, k] = min(d);
        order(i) = k;
        visited(k) = true;
        curr = P(k, :);
    end
end
