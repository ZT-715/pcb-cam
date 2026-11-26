function result = pcb_cam(job)
% PCB_CAM Gera todos os G-codes de produção de uma PCI.
%
%   RESULT = PCB_CAM(JOB) lê os arquivos Gerber/Excellon indicados em JOB
%   (ver DEFAULT_JOB), planeja as operações e grava um arquivo .ngc por
%   operação em JOB.output.dir:
%
%     <prefix>_1_alinhamento.ngc  furos de alinhamento      z_mill     ("both")
%     <prefix>_2_top_ncc.ngc      NCC da face superior      z_engrave  ("top"/"both")
%     <prefix>_3_top_furos.ngc    furos                     z_mill     ("top"/"both")
%     <prefix>_4_bottom_ncc.ngc   NCC da face inferior      z_engrave  ("bottom"/"both")
%     <prefix>_5_bottom_furos.ngc furos (espelhados)        z_mill     ("bottom")
%     <prefix>_6_recorte.ngc      recorte externo com abas  z_mill     (sempre)
%
%   O planejamento usa coordenadas da placa virgem; a margem da máquina
%   (JOB.blank.margin) é subtraída no G-code. Placas com size_x > size_y
%   são giradas 90°.
%
%   RESULT tem ops (operações com trajetória, arquivo e tempos), cpu_total,
%   machine_total, warnings, geometry, job e report_files.

    job = validate_job(job);
    layers = string(job.layers);
    use_top = layers ~= "bottom";
    use_bottom = layers ~= "top";
    verbose = job.output.verbose;

    ops = struct('name', {}, 'label', {}, 'file', {}, 'path', {}, ...
                 'cpu_time', {}, 'machine_time', {}, 'algos', {});
    warnings_out = {};

    % --- 1. Leitura ---
    log_msg(verbose, 'Lendo arquivos...\n');
    t_read = tic;
    ncc_top = polyshape();
    ncc_bottom = polyshape();
    if use_top
        [ncc_top, outline] = read_gerber_ncc(job.files.outline, job.files.top_copper, job.scale);
        copper_ref = job.files.top_copper;
    end
    if use_bottom
        [ncc_bottom, outline_b] = read_gerber_ncc(job.files.outline, job.files.bottom_copper, job.scale);
        if ~use_top
            outline = outline_b;
            copper_ref = job.files.bottom_copper;
        end
    end
    outline = union(outline);
    drills = read_drills(job.files.outline, copper_ref, job.files.drills, job.scale);
    ops(end+1) = make_op('leitura', 'Leitura dos arquivos', '', zeros(0, 2), toc(t_read), 0, []);

    % --- 2. Posicionamento e espelhamento ---
    tf = board_transform(outline, job);
    job.blank.origin = tf.origin;

    mp_ncc = operation_params(job, job.ncc.tool_diameter, job.ncc.z_engrave, ...
        job.ncc.feed_machine, job.ncc.feed_travel, job.ncc.feed_z);
    mp_mill = operation_params(job, job.mill.tool_diameter, job.mill.z_mill, ...
        job.mill.feed_machine, job.mill.feed_travel, job.mill.feed_z);
    hole_tool = job.holes.tool_diameter;
    mp_holes = operation_params(job, hole_tool, job.mill.z_mill, ...
        job.holes.feed_machine, job.mill.feed_travel, job.holes.feed_z);

    % --- 3. Furos de alinhamento ---
    if ~isempty(tf.align)
        log_msg(verbose, 'Planejando furos de alinhamento...\n');
        t0 = tic;
        [p, w] = plan_holes(tf.align, hole_tool, job.holes.overlap, job.holes.tolerance, mp_holes);
        warnings_out = [warnings_out, w];
        ops(end+1) = make_op('1_alinhamento', 'Furos de alinhamento', '', p, toc(t0), ...
            estimate_time(p, mp_holes), []);
    end

    % --- 4. Face superior ---
    geo.ncc_top = polyshape();
    geo.ncc_bottom = polyshape();
    geo.holes = zeros(0, 3);
    if use_top
        geo.ncc_top = transform_poly(ncc_top, tf.top);
        ops = plan_ncc(ops, '2_top_ncc', 'NCC face superior', geo.ncc_top, mp_ncc, verbose);

        if ~isempty(drills)
            log_msg(verbose, 'Planejando furos (face superior)...\n');
            geo.holes = [tf.top(drills(:, 1:2)), drills(:, 3)];
            t0 = tic;
            [p, w] = plan_holes(geo.holes, hole_tool, job.holes.overlap, job.holes.tolerance, mp_holes);
            warnings_out = [warnings_out, w];
            ops(end+1) = make_op('3_top_furos', 'Furos (face superior)', '', p, toc(t0), ...
                estimate_time(p, mp_holes), []);
        end
    end

    % --- 5. Face inferior ---
    if use_bottom
        geo.ncc_bottom = transform_poly(ncc_bottom, tf.bottom);
        ops = plan_ncc(ops, '4_bottom_ncc', 'NCC face inferior', geo.ncc_bottom, mp_ncc, verbose);

        if ~use_top && ~isempty(drills)
            log_msg(verbose, 'Planejando furos (face inferior)...\n');
            geo.holes = [tf.bottom(drills(:, 1:2)), drills(:, 3)];
            t0 = tic;
            [p, w] = plan_holes(geo.holes, hole_tool, job.holes.overlap, job.holes.tolerance, mp_holes);
            warnings_out = [warnings_out, w];
            ops(end+1) = make_op('5_bottom_furos', 'Furos (face inferior)', '', p, toc(t0), ...
                estimate_time(p, mp_holes), []);
        end
    end

    % --- 6. Recorte (na última face produzida) ---
    log_msg(verbose, 'Planejando recorte...\n');
    if use_bottom
        geo.outline = transform_poly(outline, tf.bottom);
    else
        geo.outline = transform_poly(outline, tf.top);
    end
    t0 = tic;
    [p, geo.tabs] = plan_outline_cut(geo.outline, job.cut.offset_radius, ...
        job.mill.tool_diameter, job.cut.tab_length, job.cut.climb);
    ops(end+1) = make_op('6_recorte', 'Recorte externo', '', p, toc(t0), estimate_time(p, mp_mill), []);

    % --- 7. Gravação dos G-codes ---
    for k = 1:numel(ops)
        if isempty(ops(k).path)
            continue;
        end
        if contains(ops(k).name, 'ncc')
            z = job.ncc.z_engrave; fm = job.ncc.feed_machine; ft = job.ncc.feed_travel; fz = job.ncc.feed_z;
        elseif contains(ops(k).name, 'furos') || contains(ops(k).name, 'alinhamento')
            z = job.mill.z_mill; fm = job.holes.feed_machine; ft = job.mill.feed_travel; fz = job.holes.feed_z;
        else
            z = job.mill.z_mill; fm = job.mill.feed_machine; ft = job.mill.feed_travel; fz = job.mill.feed_z;
        end
        % Mergulho e retração limitados pela velocidade do eixo Z
        fz_max = 60 * job.machine.F_z;
        f_plunge = min(fz, fz_max);
        f_retract = min(ft, fz_max);
        % Coordenadas da máquina: sem a margem
        path_out = ops(k).path - job.blank.margin(:)';
        ops(k).file = write_operation_gcode(path_out, z, fm, ft, ...
            job.machine.travel_height, job.output.dir, ...
            sprintf('%s_%s', job.output.prefix, ops(k).name), f_plunge, f_retract);
    end

    geo.align = tf.align;
    geo.env_top = tf.env_top;
    geo.env_bottom = tf.env_bottom;

    result.ops = ops;
    result.cpu_total = sum([ops.cpu_time]);
    result.machine_total = sum([ops.machine_time]);
    result.warnings = warnings_out;
    result.geometry = geo;
    result.job = job;

    result.report_files = report_job(result);
end

function ops = plan_ncc(ops, name, label, ncc, mp, verbose)
% Planeja o NCC de uma face e acrescenta a operação.
    if ncc.NumRegions == 0 || area(ncc) < 1e-9
        log_msg(verbose, '%s: região vazia, operação ignorada.\n', label);
        return;
    end
    log_msg(verbose, 'Planejando %s...\n', label);
    t0 = tic;
    out = plan_tool_path(ncc, mp);
    algos = struct('contour', out.contour_time, 'zigzag', out.zigzag_time, ...
                   'isolation', out.iso_time, 'winner', out.winner);
    ops(end+1) = make_op(name, label, '', out.trajectory, toc(t0), out.total_time, algos);
end

function op = make_op(name, label, file, path, cpu_time, machine_time, algos)
    op = struct('name', name, 'label', label, 'file', file, 'path', path, ...
                'cpu_time', cpu_time, 'machine_time', machine_time, 'algos', algos);
end

function log_msg(verbose, varargin)
    if verbose
        fprintf(varargin{:});
    end
end

function job = validate_job(job)
% Completa JOB com os valores padrão e verifica os campos.
    defaults = default_job();
    job = fill_defaults(job, defaults);

    layers = string(job.layers);
    if ~any(layers == ["top", "bottom", "both"])
        error('pcb_cam:layers', 'layers deve ser "top", "bottom" ou "both".');
    end
    job.layers = layers;

    must_exist(job.files.outline);
    if layers ~= "bottom"
        must_exist(job.files.top_copper);
    end
    if layers ~= "top"
        must_exist(job.files.bottom_copper);
    end
    job.files.drills = cellstr(job.files.drills);
    for k = 1:numel(job.files.drills)
        must_exist(job.files.drills{k});
    end

    if job.ncc.z_engrave >= 0 || job.mill.z_mill >= 0
        error('pcb_cam:depth', 'Profundidades devem ser negativas.');
    end
    if job.machine.F_z <= 0 || job.ncc.feed_z <= 0 || job.mill.feed_z <= 0
        error('pcb_cam:feed', 'Avanços devem ser positivos.');
    end
    if job.machine.travel_height <= 0
        error('pcb_cam:depth', 'Altura de viagem deve ser positiva.');
    end
    if job.ncc.tool_diameter <= 0 || job.mill.tool_diameter <= 0 || job.cut.offset_radius <= 0
        error('pcb_cam:tool', 'Diâmetros e offset devem ser positivos.');
    end
    if isempty(job.holes.tool_diameter)
        job.holes.tool_diameter = job.mill.tool_diameter;
    end
    if ~isfield(job.holes, 'feed_machine') || isempty(job.holes.feed_machine)
        job.holes.feed_machine = job.mill.feed_machine;
    end
    if ~isfield(job.holes, 'feed_z') || isempty(job.holes.feed_z)
        job.holes.feed_z = job.mill.feed_z;
    end
    if job.holes.feed_machine <= 0 || job.holes.feed_z <= 0
        error('pcb_cam:feed', 'Avanços devem ser positivos.');
    end
    if isstring(job.blank.origin) || ischar(job.blank.origin)
        if string(job.blank.origin) ~= "center"
            error('pcb_cam:origin', 'blank.origin deve ser [x0 y0] >= 0 ou "center".');
        end
    elseif numel(job.blank.origin) ~= 2 || any(job.blank.origin < 0)
        error('pcb_cam:origin', 'blank.origin deve ser [x0 y0] >= 0 ou "center".');
    end
    if numel(job.blank.margin) ~= 2 || any(job.blank.margin < 0)
        error('pcb_cam:margin', 'blank.margin deve ser [mx my] >= 0.');
    end
    if layers == "both" && (isempty(job.blank.size_x) || isempty(job.blank.size_y))
        error('pcb_cam:blank', 'Dupla face exige blank.size_x e blank.size_y.');
    end

    % Curso em Y maior que em X: placa com X > Y é girada 90°
    job.blank.rotated = false;
    if ~isempty(job.blank.size_x) && ~isempty(job.blank.size_y) ...
            && job.blank.size_x > job.blank.size_y
        [job.blank.size_x, job.blank.size_y] = deal(job.blank.size_y, job.blank.size_x);
        job.blank.rotated = true;
    end
end

function must_exist(f)
    if isempty(f) || ~isfile(f)
        error('pcb_cam:file', 'Arquivo não encontrado: %s', string(f));
    end
end

function s = fill_defaults(s, d)
% Preenche campos ausentes de S com os valores de D (recursivo).
    fn = fieldnames(d);
    for k = 1:numel(fn)
        f = fn{k};
        if ~isfield(s, f)
            s.(f) = d.(f);
        elseif isstruct(d.(f)) && isstruct(s.(f))
            s.(f) = fill_defaults(s.(f), d.(f));
        end
    end
end
