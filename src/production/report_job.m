function files = report_job(result)
% REPORT_JOB Exibe e salva a tabela de tempos e as figuras de uma produção.
%
%   FILES = REPORT_JOB(RESULT) imprime a tabela de tempos (output.verbose),
%   exibe (output.show_figures) e salva (output.save_figures) o layout, as
%   trajetórias de NCC, o gráfico e o CSV de tempos. FILES tem os caminhos
%   dos arquivos salvos.

    job = result.job;
    files = struct('figures', {{}}, 'csv', '');

    if job.output.verbose
        print_table(result);
    end

    save_figs = isfield(job.output, 'save_figures') && job.output.save_figures;
    if ~job.output.show_figures && ~save_figs
        return;
    end
    vis = 'on';
    if ~job.output.show_figures
        vis = 'off';
    end

    figs = {plot_layout(result, vis), 'layout'};
    face_figs = plot_faces(result, vis);
    figs = [figs; face_figs];
    f_times = plot_times(result, vis);
    if ~isempty(f_times)
        figs = [figs; {f_times, 'tempos'}];
    end

    if save_figs
        if ~isfolder(job.output.dir)
            mkdir(job.output.dir);
        end
        for k = 1:size(figs, 1)
            base = fullfile(job.output.dir, sprintf('%s_%s', job.output.prefix, figs{k, 2}));
            dpi = 300;
            if endsWith(figs{k, 2}, 'ncc')
                dpi = 600;
            end
            exportgraphics(figs{k, 1}, [base '.png'], 'Resolution', dpi);
            exportgraphics(figs{k, 1}, [base '.pdf'], 'ContentType', 'vector');
            files.figures{end+1} = [base '.png'];
        end
        files.csv = write_csv(result);
    end

    if ~job.output.show_figures
        close([figs{:, 1}]);
    end
end

function print_table(result)
    line = repmat('-', 1, 78);
    fprintf('\n%s\n%-34s %-14s %12s %14s\n%s\n', line, 'Operação', 'Algoritmo', ...
        'Cálculo (s)', 'Usinagem', line);
    for k = 1:numel(result.ops)
        op = result.ops(k);
        fprintf('%-34s %-14s %12.2f %14s\n', op.label, '', op.cpu_time, fmt_time(op.machine_time));
        if ~isempty(op.algos)
            a = op.algos;
            mark = {'', ''};
            mark{a.winner} = ' *';
            fprintf('%-34s %-14s %12s %14s\n', '', ['contornos' mark{1}], '', fmt_time(a.contour));
            fprintf('%-34s %-14s %12s %14s\n', '', ['ziguezague' mark{2}], '', fmt_time(a.zigzag));
            fprintf('%-34s %-14s %12s %14s\n', '', 'isolamento', '', fmt_time(a.isolation));
        end
        if ~isempty(op.file)
            fprintf('%-34s -> %s\n', '', op.file);
        end
    end
    fprintf('%s\n%-34s %-14s %12.2f %14s\n%s\n', line, 'Total', '', result.cpu_total, ...
        fmt_time(result.machine_total), line);
    fprintf('* estratégia de desbaste escolhida (contornos ou ziguezague).\n');

    if ~isempty(result.warnings)
        fprintf('\nAvisos:\n');
        fprintf('  - %s\n', result.warnings{:});
    end
    fprintf('\n');
end

function s = fmt_time(t)
    s = sprintf('%d:%05.2f', floor(t / 60), mod(t, 60));
end

function file = write_csv(result)
% Uma linha por operação e uma por algoritmo de NCC.
    job = result.job;
    op_col = {}; alg_col = {}; cpu_col = []; mach_col = []; winner_col = [];
    for k = 1:numel(result.ops)
        op = result.ops(k);
        op_col{end+1, 1} = op.label; %#ok<AGROW>
        alg_col{end+1, 1} = 'total'; %#ok<AGROW>
        cpu_col(end+1, 1) = op.cpu_time; %#ok<AGROW>
        mach_col(end+1, 1) = op.machine_time; %#ok<AGROW>
        winner_col(end+1, 1) = false; %#ok<AGROW>
        if ~isempty(op.algos)
            names = {'contornos', 'ziguezague', 'isolamento'};
            vals = [op.algos.contour, op.algos.zigzag, op.algos.isolation];
            for a = 1:3
                op_col{end+1, 1} = op.label; %#ok<AGROW>
                alg_col{end+1, 1} = names{a}; %#ok<AGROW>
                cpu_col(end+1, 1) = NaN; %#ok<AGROW>
                mach_col(end+1, 1) = vals(a); %#ok<AGROW>
                winner_col(end+1, 1) = (a == op.algos.winner); %#ok<AGROW>
            end
        end
    end
    op_col{end+1, 1} = 'Total';
    alg_col{end+1, 1} = 'total';
    cpu_col(end+1, 1) = result.cpu_total;
    mach_col(end+1, 1) = result.machine_total;
    winner_col(end+1, 1) = false;

    T = table(op_col, alg_col, cpu_col, mach_col, logical(winner_col), ...
        'VariableNames', {'operacao', 'algoritmo', 'calculo_s', 'usinagem_s', 'escolhido'});
    file = fullfile(job.output.dir, sprintf('%s_tempos.csv', job.output.prefix));
    writetable(T, file);
end

function fig = plot_layout(result, vis)
% Layout na placa virgem; em dupla face, (a) superior e (b) inferior virada.
    job = result.job;
    geo = result.geometry;
    layers = string(job.layers);
    has_blank = ~isempty(job.blank.size_x) && ~isempty(job.blank.size_y);

    cut_path = [];
    cut = find_op(result, '6_recorte');
    if ~isempty(cut)
        cut_path = cut.path;
    end

    % Furos vistos de cada face
    holes_bottom = geo.holes;
    if layers == "both" && ~isempty(holes_bottom)
        holes_bottom(:, 1) = job.blank.size_x - holes_bottom(:, 1);
    end

    panels = {};
    if layers ~= "bottom"
        p = struct('ncc', geo.ncc_top, 'color', [0.2 0.6 0.2], 'ncc_label', 'NCC superior', ...
                   'holes', geo.holes, 'cut', [], 'label', '(a) Face superior');
        if layers == "top"
            p.cut = cut_path;
        end
        panels{end+1} = p;
    end
    if layers ~= "top"
        panels{end+1} = struct('ncc', geo.ncc_bottom, 'color', [0.8 0.2 0.2], ...
            'ncc_label', 'NCC inferior (espelhado)', 'holes', holes_bottom, ...
            'cut', cut_path, 'label', '(b) Face inferior (espelhada)');
    end
    n = numel(panels);

    % Limites: placa virgem ou envelope do recorte
    if has_blank
        xl = [0 job.blank.size_x];
        yl = [0 job.blank.size_y];
    else
        [ex, ey] = boundingbox(union([geo.env_top, geo.env_bottom]));
        xl = ex(:)';
        yl = ey(:)';
    end
    pad = 0.03 * max(diff(xl), diff(yl));
    xl = xl + [-pad pad];
    yl = yl + [-pad pad];

    % Tamanho proporcional aos dados
    width_cm = 16;
    tile_w = width_cm / n;
    aspect = diff(yl) / diff(xl);
    fig = figure('Name', 'Layout da placa', 'Color', 'w', 'Visible', vis, 'Units', 'centimeters');
    pos = get(fig, 'Position');
    set(fig, 'Position', [pos(1), pos(2), width_cm + 2, min(tile_w * aspect, 1.5 * tile_w) + 4.5]);

    t = tiledlayout(fig, 1, n, 'TileSpacing', 'compact', 'Padding', 'compact');
    styles = containers.Map();
    axs = gobjects(1, n);
    for k = 1:n
        ax = nexttile(t);
        axs(k) = ax;
        hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        set(ax, 'FontSize', 9, 'Layer', 'top', 'GridAlpha', 0.15);
        P = panels{k};

        if has_blank
            plot(ax, polyshape([0 job.blank.size_x job.blank.size_x 0], ...
                [0 0 job.blank.size_y job.blank.size_y]), 'FaceColor', [0.85 0.65 0.3], ...
                'FaceAlpha', 0.25, 'EdgeColor', [0.6 0.4 0.1], 'LineWidth', 0.5);
            styles('Placa virgem') = {'patch', [0.85 0.65 0.3], 0.25, [0.6 0.4 0.1]};
        end
        if P.ncc.NumRegions > 0
            plot(ax, P.ncc, 'FaceColor', P.color, 'FaceAlpha', 0.4, 'EdgeColor', 'none');
            styles(P.ncc_label) = {'patch', P.color, 0.4, 'none'};
        end
        if ~isempty(P.cut)
            plot(ax, P.cut(:, 1), P.cut(:, 2), 'k-', 'LineWidth', 0.8);
            styles('Recorte') = {'line', [0 0 0], 0.8, '-'};
        end
        if ~isempty(P.holes)
            draw_circles(ax, P.holes, [0 0.2 0.8]);
            styles('Furos') = {'line', [0 0.2 0.8], 0.6, '-'};
        end
        if ~isempty(geo.align)
            draw_circles(ax, geo.align, [0.85 0.1 0.1]);
            styles('Alinhamento') = {'line', [0.85 0.1 0.1], 0.6, '-'};
        end

        axis(ax, 'equal');
        xlim(ax, xl);
        ylim(ax, yl);
        xlabel(ax, 'X (mm)');
        if k == 1
            ylabel(ax, 'Y (mm)');
        end
        if n > 1
            title(ax, P.label, 'FontSize', 9, 'FontWeight', 'normal');
        end
        hold(ax, 'off');
    end

    % Legenda única (objetos em eixos diferentes)
    order = {'Placa virgem', 'NCC superior', 'NCC inferior (espelhado)', 'Recorte', 'Furos', 'Alinhamento'};
    order = order(cellfun(@(k) isKey(styles, k), order));
    hold(axs(1), 'on');
    proxies = gobjects(1, numel(order));
    for k = 1:numel(order)
        st = styles(order{k});
        if strcmp(st{1}, 'patch')
            proxies(k) = patch(axs(1), NaN, NaN, st{2}, 'FaceAlpha', st{3}, 'EdgeColor', st{4});
        else
            proxies(k) = plot(axs(1), NaN, NaN, st{4}, 'Color', st{2}, 'LineWidth', st{3});
        end
    end
    hold(axs(1), 'off');
    lgd = legend(axs(1), proxies, order, 'Orientation', 'horizontal', ...
        'NumColumns', 3, 'FontSize', 8, 'Box', 'off');
    lgd.Layout.Tile = 'south';
    drawnow;
end

function h = draw_circles(ax, holes, color)
    th = linspace(0, 2 * pi, 49)';
    X = []; Y = [];
    for k = 1:size(holes, 1)
        r = holes(k, 3) / 2;
        X = [X; holes(k, 1) + r * cos(th); NaN]; %#ok<AGROW>
        Y = [Y; holes(k, 2) + r * sin(th); NaN]; %#ok<AGROW>
    end
    h = plot(ax, X, Y, '-', 'Color', color, 'LineWidth', 0.6);
end

function figs = plot_faces(result, vis)
% Trajetória de NCC com linhas finas e sem marcadores.
    job = result.job;
    geo = result.geometry;
    faces = {'2_top_ncc', geo.ncc_top, 'top_ncc'; '4_bottom_ncc', geo.ncc_bottom, 'bottom_ncc'};
    width_cm = 16;
    interval = job.ncc.tool_diameter * (1 - job.ncc.overlap);
    figs = cell(0, 2);
    for k = 1:size(faces, 1)
        op = find_op(result, faces{k, 1});
        if ~isempty(op) && ~isempty(op.path)
            [bx, ~] = boundingbox(faces{k, 2});
            lw = toolpath_line_width(interval, diff(bx), width_cm);
            fig = plot_toolpath(faces{k, 2}, op.path, 'LineWidth', lw, ...
                'AirLineWidth', max(lw, 0.3), 'ShowMarkers', false, ...
                'Visible', vis, 'WidthCm', width_cm);
            set(fig, 'Name', op.label);
            figs(end+1, :) = {fig, faces{k, 3}}; %#ok<AGROW>
        end
    end
end

function fig = plot_times(result, vis)
    ops = result.ops([result.ops.machine_time] > 0);
    fig = [];
    if isempty(ops)
        return;
    end
    fig = figure('Name', 'Tempos de usinagem', 'Color', 'w', 'Visible', vis);
    b = barh(categorical({ops.label}, {ops.label}), [ops.machine_time] / 60);
    b.FaceColor = [0.25 0.45 0.7];
    xlabel('Tempo estimado de usinagem (min)');
    grid on;
end

function op = find_op(result, name)
    idx = find(strcmp({result.ops.name}, name), 1);
    if isempty(idx)
        op = [];
    else
        op = result.ops(idx);
    end
end
