function TPENet = create_tpenet(shape, tool_radius, margin, path_interval, limit_passes, passes, joint_type)
% CREATE_TPENET Rede de contornos paralelos (TPE Net) de uma área.
%
%   TPENET = CREATE_TPENET(SHAPE, TOOL_RADIUS, MARGIN, PATH_INTERVAL,
%   LIMIT_PASSES, PASSES) gera os offsets internos de SHAPE espaçados de
%   PATH_INTERVAL. Cada contorno fechado é um nó, ligado aos nós do nível
%   anterior que o contêm (parents/children). Regiões não cortadas entre
%   níveis viram nós de limpeza (is_cleanup). Com LIMIT_PASSES, para após
%   PASSES níveis (isolamento). JOINT_TYPE é a junção dos offsets
%   ('square', padrão; 'round' ou 'miter').
arguments
    shape polyshape;
    tool_radius double;
    margin double;
    path_interval double;
    limit_passes = false;
    passes = 3;
    joint_type = 'square';
end

    % is_hole: o anel contorna uma ilha de material
    TPENet = struct('id', {}, 'poly', {}, 'is_cleanup', {}, 'traj_x', {}, 'traj_y', {}, ...
                    'offset_num', {}, 'parents', {}, 'children', {}, 'visited', {}, ...
                    'entry_path', {}, 'is_hole', {});

    % Offsets calculados em paralelo, em lotes
    pool = backgroundPool;
    batch_size = 5;
    buffer_futures = parallel.FevalFuture.empty(0, 1);

    for i = 1:batch_size
        dist = -tool_radius - margin - (i - 1) * path_interval;
        buffer_futures(i) = parfeval(pool, @polybuffer, 1, shape, dist, 'JointType', joint_type);
    end

    offset_num = 1;
    tpe_counter = 1;
    tpe_by_offset = {}; 

    current_path = fetchOutputs(buffer_futures(1));

    while area(current_path) > 1e-5
        regs = regions(current_path);
        current_level_ids = [];

        % Nós regulares
        for i = 1:length(regs)
            nb = numboundaries(regs(i));
            hole_flags = ishole(regs(i));
            for b = 1:nb
                [bx, by] = boundary(regs(i), b);

                filtro = [true; any(diff([bx, by], 1, 1) ~= 0, 2)];
                bx = bx(filtro);
                by = by(filtro);

                sub_poly = polyshape(bx, by);

                TPENet(tpe_counter).id = tpe_counter;
                TPENet(tpe_counter).poly = sub_poly;
                TPENet(tpe_counter).is_cleanup = false;
                TPENet(tpe_counter).is_hole = hole_flags(b);
                TPENet(tpe_counter).offset_num = offset_num;
                TPENet(tpe_counter).parents = [];
                TPENet(tpe_counter).children = [];
                TPENet(tpe_counter).visited = false;

                if offset_num > 1
                    for p_idx = tpe_by_offset{offset_num - 1}
                        if overlaps(TPENet(p_idx).poly, sub_poly)
                            TPENet(tpe_counter).parents(end+1) = p_idx;
                            TPENet(p_idx).children(end+1) = tpe_counter;
                        end
                    end
                end
                current_level_ids(end+1) = tpe_counter;
                tpe_counter = tpe_counter + 1;
            end
        end
        tpe_by_offset{offset_num} = current_level_ids;

        % Próximo nível
        if length(buffer_futures) >= offset_num + 1
            next_path = fetchOutputs(buffer_futures(offset_num + 1));
        else
            dist = -tool_radius - margin - (offset_num) * path_interval;
            next_fut = parfeval(pool, @polybuffer, 1, shape, dist, 'JointType', joint_type);
            buffer_futures(end+1) = next_fut;
            next_path = fetchOutputs(next_fut);
        end

        next_dispatch_idx = offset_num + batch_size;
        dist_dispatch = -tool_radius - margin - (next_dispatch_idx - 1) * path_interval;
        buffer_futures(next_dispatch_idx) = parfeval(pool, @polybuffer, 1, shape, dist_dispatch, 'JointType', joint_type);

        % Região não cortada entre os níveis (nós de limpeza)
        buf_curr = polybuffer(current_path, -tool_radius, 'JointType', joint_type);
        if area(next_path) < 1e-5
            uncut = buf_curr;
        else
            buf_next = polybuffer(next_path, tool_radius, 'JointType', joint_type);
            uncut = subtract(buf_curr, buf_next);
        end

        if area(uncut) > 1e-5
            clean_regs = regions(uncut);
            for cr = 1:length(clean_regs)
                % A limpeza percorre a borda externa da região
                [cx, cy] = outer_ring(clean_regs(cr));
                if numel(cx) < 2
                    continue;
                end

                TPENet(tpe_counter).id = tpe_counter;
                TPENet(tpe_counter).poly = clean_regs(cr);
                TPENet(tpe_counter).is_cleanup = true;
                TPENet(tpe_counter).is_hole = false;
                TPENet(tpe_counter).traj_x = cx;
                TPENet(tpe_counter).traj_y = cy;
                TPENet(tpe_counter).offset_num = offset_num + 1;
                TPENet(tpe_counter).parents = [];
                TPENet(tpe_counter).children = [];
                TPENet(tpe_counter).visited = false;

                for p_idx = tpe_by_offset{offset_num}
                    if overlaps(TPENet(p_idx).poly, clean_regs(cr))
                        TPENet(tpe_counter).parents(end+1) = p_idx;
                        TPENet(p_idx).children(end+1) = tpe_counter;
                    end
                end

                tpe_counter = tpe_counter + 1;
            end
        end

        if area(next_path) < 1e-5
            cancel(buffer_futures(offset_num + 2 : end));
            break;
        end

        current_path = next_path;
        offset_num = offset_num + 1;

        if limit_passes && offset_num > passes
           cancel(buffer_futures(offset_num + 1 : end));
           break;
        end
    end
end


function [cx, cy] = outer_ring(region)
% OUTER_RING Anel externo fechado de uma região (sem furos e sem NaN).
    cx = zeros(0, 1);
    cy = zeros(0, 1);
    holes = ishole(region);
    best = -inf;
    for b = 1:numboundaries(region)
        if holes(b)
            continue;
        end
        [x, y] = boundary(region, b);
        len = sum(hypot(diff(x), diff(y)));
        if len > best
            best = len;
            cx = x;
            cy = y;
        end
    end
    if ~isempty(cx) && (cx(1) ~= cx(end) || cy(1) ~= cy(end))
        cx(end+1) = cx(1);
        cy(end+1) = cy(1);
    end
end
