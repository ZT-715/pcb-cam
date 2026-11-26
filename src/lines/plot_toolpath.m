function fig = plot_toolpath(shape, connected_lines, opts)
% PLOT_TOOLPATH Desenha a área de usinagem e a trajetória da ferramenta.
%
%   PLOT_TOOLPATH(SHAPE, CONNECTED_LINES) desenha SHAPE (polyshape) e a
%   trajetória CONNECTED_LINES [N x 2], em que NaN indica retração e
%   viagem aérea até o próximo ponto.
%
%   FIG = PLOT_TOOLPATH(..., Name=Value) aceita:
%     LineWidth    - Espessura das linhas de corte (pt, padrão 0.5; ver
%                    TOOLPATH_LINE_WIDTH).
%     AirLineWidth - Espessura das viagens aéreas (padrão: LineWidth).
%     ShowMarkers  - Marca mergulhos e retrações (padrão true).
%     Visible      - 'on' ou 'off' (padrão 'on').
%     WidthCm      - Largura da figura em cm (padrão 16).

    arguments
        shape
        connected_lines
        opts.LineWidth (1,1) double {mustBePositive} = 0.5
        opts.AirLineWidth double = []
        opts.ShowMarkers (1,1) logical = true
        opts.Visible = 'on'
        opts.WidthCm (1,1) double {mustBePositive} = 16
    end
    if isempty(opts.AirLineWidth)
        opts.AirLineWidth = opts.LineWidth;
    end

    fig = figure('Name', 'Visualização do Caminho de Usinagem', 'Color', 'w', ...
        'Visible', opts.Visible);
    ax = axes(fig);
    hold(ax, 'on');
    box(ax, 'on');
    grid(ax, 'on');
    set(ax, 'FontSize', 9, 'Layer', 'top', 'GridAlpha', 0.15);
    xlabel(ax, 'X (mm)');
    ylabel(ax, 'Y (mm)');

    % 1. Área de usinagem
    h_poly = plot(ax, shape, 'FaceColor', [0.93 0.93 0.93], 'FaceAlpha', 1, ...
        'EdgeColor', [0.45 0.45 0.45], 'LineWidth', max(opts.LineWidth, 0.3), ...
        'DisplayName', 'Área de usinagem');

    handles = h_poly;
    if isempty(connected_lines)
        warning('O caminho de ferramenta está vazio.');
    else
        % 2. Corte
        handles(end+1) = plot(ax, connected_lines(:, 1), connected_lines(:, 2), '-', ...
            'Color', [0.05 0.25 0.65], 'LineWidth', opts.LineWidth, ...
            'DisplayName', 'Corte (ferramenta mergulhada)');

        % 3. Viagens aéreas
        [pt_out, pt_in] = air_moves(connected_lines);
        if ~isempty(pt_out)
            n = size(pt_out, 1);
            ax_x = reshape([pt_out(:, 1), pt_in(:, 1), NaN(n, 1)]', [], 1);
            ax_y = reshape([pt_out(:, 2), pt_in(:, 2), NaN(n, 1)]', [], 1);
            handles(end+1) = plot(ax, ax_x, ax_y, '--', 'Color', [0.85 0.1 0.1], ...
                'LineWidth', opts.AirLineWidth, 'DisplayName', 'Conexão aérea (ferramenta retraída)');

            if opts.ShowMarkers
                handles(end+1) = plot(ax, pt_in(:, 1), pt_in(:, 2), 'v', 'Color', [0.85 0.1 0.1], ...
                    'MarkerFaceColor', [0.85 0.1 0.1], 'MarkerSize', 3, 'DisplayName', 'Mergulho (-Z)');
                handles(end+1) = plot(ax, pt_out(:, 1), pt_out(:, 2), '^', 'Color', [0.1 0.6 0.1], ...
                    'MarkerFaceColor', [0.1 0.6 0.1], 'MarkerSize', 3, 'DisplayName', 'Retração (+Z)');
            end
        end

        % 4. Início e fim
        valid = find(~isnan(connected_lines(:, 1)));
        if ~isempty(valid)
            p0 = connected_lines(valid(1), :);
            p1 = connected_lines(valid(end), :);
            handles(end+1) = plot(ax, p0(1), p0(2), 'o', 'Color', [0.1 0.6 0.1], ...
                'MarkerFaceColor', [0.1 0.6 0.1], 'MarkerSize', 5, 'DisplayName', 'Início');
            handles(end+1) = plot(ax, p1(1), p1(2), 's', 'Color', [0.85 0.1 0.1], ...
                'MarkerFaceColor', [0.85 0.1 0.1], 'MarkerSize', 5, 'DisplayName', 'Fim');
        end
    end

    % 5. Escala igual em X e Y
    axis(ax, 'equal');
    [xl, yl] = data_limits(shape, connected_lines);
    pad = 0.02 * max(diff(xl), diff(yl));
    xlim(ax, xl + [-pad pad]);
    ylim(ax, yl + [-pad pad]);

    % 6. Tamanho da figura proporcional aos dados
    aspect = (diff(yl) + 2 * pad) / (diff(xl) + 2 * pad);
    w = opts.WidthCm;
    h = min(w * aspect, 1.5 * w) + 4;
    set(fig, 'Units', 'centimeters');
    pos = get(fig, 'Position');
    set(fig, 'Position', [pos(1), pos(2), w + 2, h]);

    % 7. Legenda
    legend(ax, handles, 'Location', 'southoutside', 'Orientation', 'horizontal', ...
        'NumColumns', 3, 'FontSize', 8, 'Box', 'off');
    drawnow;

    hold(ax, 'off');
end

function [pt_out, pt_in] = air_moves(P)
% Pares (último ponto antes do NaN, primeiro ponto depois) de cada viagem.
    is_nan = isnan(P(:, 1));
    pt_out = zeros(0, 2);
    pt_in = zeros(0, 2);
    last = [];
    pending = false;
    for i = 1:size(P, 1)
        if is_nan(i)
            pending = ~isempty(last);
        else
            if pending
                pt_out(end+1, :) = last; %#ok<AGROW>
                pt_in(end+1, :) = P(i, :); %#ok<AGROW>
                pending = false;
            end
            last = P(i, :);
        end
    end
end

function [xl, yl] = data_limits(shape, P)
    xl = [inf -inf];
    yl = [inf -inf];
    if isa(shape, 'polyshape') && any([shape.NumRegions] > 0)
        [bx, by] = boundingbox(shape);
        xl = [bx(1) bx(2)];
        yl = [by(1) by(2)];
    end
    if ~isempty(P)
        xl = [min(xl(1), min(P(:, 1))), max(xl(2), max(P(:, 1)))];
        yl = [min(yl(1), min(P(:, 2))), max(yl(2), max(P(:, 2)))];
    end
    if ~all(isfinite([xl yl]))
        xl = [0 1];
        yl = [0 1];
    end
end
