function tf = board_transform(outline, job)
% BOARD_TRANSFORM Posiciona o circuito na placa virgem e espelha a face inferior.
%
%   TF = BOARD_TRANSFORM(OUTLINE, JOB) leva o canto da área do recorte a
%   JOB.blank.origin, espelha a face inferior (em "both", em torno de
%   x = size_x/2), cria os furos de alinhamento e verifica se tudo cabe na
%   placa e na área útil da máquina. TF tem as funções top e bottom
%   (@(P) para pontos [N x 2]), env_top, env_bottom, align, has_blank e
%   origin.

    layers = string(job.layers);

    % Placa girada 90°
    if isfield(job.blank, 'rotated') && job.blank.rotated
        rot = @(P) [-P(:, 2), P(:, 1)];
    else
        rot = @(P) P;
    end
    outline = transform_poly(outline, rot);

    env = polybuffer(outline, job.cut.offset_radius + job.mill.tool_diameter / 2);
    [xl, yl] = boundingbox(env);

    has_blank = ~isempty(job.blank.size_x) && ~isempty(job.blank.size_y);

    if (isstring(job.blank.origin) || ischar(job.blank.origin)) && string(job.blank.origin) == "center"
        if ~has_blank
            error('pcb_cam:origin', 'blank.origin = "center" exige blank.size_x e blank.size_y.');
        end
        origin = ([job.blank.size_x, job.blank.size_y] - [diff(xl), diff(yl)]) / 2;
    else
        origin = job.blank.origin(:)';
    end
    tf.origin = origin;
    d = origin - [xl(1), yl(1)];
    translate = @(P) rot(P) + d;

    switch layers
        case "top"
            tf.top = translate;
            tf.bottom = translate;
        case "bottom"
            xc = (xl(1) + xl(2)) / 2;
            mirror_own = @(P) [2 * xc - P(:, 1), P(:, 2)];
            tf.top = translate;
            tf.bottom = @(P) mirror_own(rot(P)) + d;
        case "both"
            sx = job.blank.size_x;
            tf.top = translate;
            tf.bottom = @(P) mirror_x(translate(P), sx);
        otherwise
            error('pcb_cam:layers', 'layers deve ser "top", "bottom" ou "both".');
    end

    switch layers
        case "bottom"
            tf.env_top = transform_poly(env, @(P) P + d);
            tf.env_bottom = transform_poly(env, @(P) [2 * xc - P(:, 1), P(:, 2)] + d);
        case "both"
            tf.env_top = transform_poly(env, @(P) P + d);
            tf.env_bottom = transform_poly(env, @(P) mirror_x(P + d, sx));
        otherwise
            tf.env_top = transform_poly(env, @(P) P + d);
            tf.env_bottom = tf.env_top;
    end
    tf.has_blank = has_blank;
    tf.align = zeros(0, 3);

    if layers == "both"
        tf.align = alignment_holes(job.blank.size_x, job.blank.size_y, ...
            job.align.diameter, job.align.edge_margin);

        % Centro do furo dentro da área útil
        lo = job.blank.margin(:)';
        hi = [job.blank.size_x job.blank.size_y] - job.blank.margin(:)';
        out = any(tf.align(:, 1:2) < lo - 1e-9 | tf.align(:, 1:2) > hi + 1e-9, 2);
        if any(out)
            error('pcb_cam:align_margin', 'Furo de alinhamento sobrepõe a margem da máquina.');
        end
    end

    % Circuito dentro da placa
    if has_blank
        blank_poly = polyshape([0 job.blank.size_x job.blank.size_x 0], ...
                               [0 0 job.blank.size_y job.blank.size_y]);
        envs = {tf.env_top, tf.env_bottom};
        for k = 1:numel(envs)
            if area(subtract(envs{k}, blank_poly)) > 1e-9
                error('pcb_cam:fit', 'O circuito não cabe na placa virgem.');
            end
        end
    end

    % Centro da fresa de recorte dentro da área útil
    if has_blank
        cut_path = polybuffer(outline, job.cut.offset_radius);
        switch layers
            case "bottom"
                paths = {transform_poly(cut_path, @(P) [2 * xc - P(:, 1), P(:, 2)] + d)};
            case "both"
                paths = {transform_poly(cut_path, @(P) P + d), ...
                         transform_poly(cut_path, @(P) mirror_x(P + d, sx))};
            otherwise
                paths = {transform_poly(cut_path, @(P) P + d)};
        end
        lo = job.blank.margin(:)';
        hi = [job.blank.size_x job.blank.size_y] - job.blank.margin(:)';
        for k = 1:numel(paths)
            [px, py] = boundingbox(paths{k});
            if px(1) < lo(1) - 1e-9 || py(1) < lo(2) - 1e-9 || px(2) > hi(1) + 1e-9 || py(2) > hi(2) + 1e-9
                error('pcb_cam:cut_margin', 'Recorte sobrepõe a margem da máquina.');
            end
        end
    end

    if ~isempty(tf.align)
        clearance = job.align.diameter / 2 + job.mill.tool_diameter;
        for k = 1:size(tf.align, 1)
            keep_out = nsidedpoly(64, 'Center', tf.align(k, 1:2), 'Radius', clearance);
            if overlaps(tf.env_top, keep_out) || overlaps(tf.env_bottom, keep_out)
                error('pcb_cam:align_collision', 'Recorte sobrepõe um furo de alinhamento.');
            end
        end
    end
end

function P = mirror_x(P, size_x)
    P(:, 1) = size_x - P(:, 1);
end
