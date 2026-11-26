function output_data = plan_tool_path(shape, machine_params) %#codegen
% PLAN_TOOL_PATH Trajetória e tempo da remoção de cobre (NCC) de uma área.
%
%   OUTPUT_DATA = PLAN_TOOL_PATH(SHAPE, MACHINE_PARAMS) gera os passes de
%   isolamento e dois desbastes (contornos paralelos e zigue-zague), escolhe
%   o desbaste mais rápido pelo modelo de tempo e o liga ao isolamento.
%   MACHINE_PARAMS vem de OPERATION_PARAMS. OUTPUT_DATA tem trajectory
%   ([N x 2], NaN = conexão aérea), total_time, contour_time, zigzag_time,
%   iso_time e winner (1 = contornos, 2 = zigue-zague).

    verbose = isfield(machine_params, 'verbose') && machine_params.verbose;

    tool_radius = machine_params.tool_diameter * 0.5;
    path_interval = machine_params.tool_diameter * (1 - machine_params.overlap);
    if isfield(machine_params, 'overlap_lines') && ~isempty(machine_params.overlap_lines)
        line_interval = machine_params.tool_diameter * (1 - machine_params.overlap_lines);
    else
        line_interval = path_interval;
    end
    ncc_margin = path_interval * machine_params.contour_passes;

    % Desbaste por contornos, isolamento (discordante) e zigue-zague
    sequence_contour = contour_parallel(shape, tool_radius, ncc_margin, path_interval, machine_params, false, false, 0, false);
    sequence_isolation = contour_parallel(shape, tool_radius, 0.0, path_interval, machine_params, false, true, machine_params.contour_passes, false, true);
    sequence_zigzag = parallel_lines(shape, tool_radius, ncc_margin - path_interval, line_interval, machine_params, true, false);

    traj_mat_contour = sequence_contour';
    traj_mat_iso = sequence_isolation';
    traj_mat_zigzag = sequence_zigzag';

    % Tempos
    traj_contour_data = process_nonstop_trajectory( ...
        traj_mat_contour, ...
        machine_params.eps, machine_params.F_cmd, machine_params.F_rapid, ...
        machine_params.F_z, machine_params.A_max, machine_params.depth, ...
        machine_params.travel_height);
    contour_time = sum(traj_contour_data.time);

    if verbose
        fprintf('Tempo para NCC por contornos: %f s\n', contour_time);
    end
    
    traj_zigzag_data = process_nonstop_trajectory(traj_mat_zigzag, ...
        machine_params.eps, machine_params.F_cmd, machine_params.F_rapid, ...
        machine_params.F_z, machine_params.A_max, machine_params.depth, ...
        machine_params.travel_height);
    zigzag_time = sum(traj_zigzag_data.time);

    if verbose
        fprintf('Tempo NCC por ziguezague: %f s\n', zigzag_time);
    end

    traj_isolation_data = process_nonstop_trajectory(traj_mat_iso, ...
        machine_params.eps, machine_params.F_cmd, machine_params.F_rapid, ...
        machine_params.F_z, machine_params.A_max, machine_params.depth, ...
        machine_params.travel_height);
    iso_time = sum(traj_isolation_data.time);

    % Desbaste mais rápido, ligado ao isolamento
    if zigzag_time < contour_time
        winner_sequence = traj_mat_zigzag;
        winner = 2;
    else
        winner_sequence = traj_mat_contour;
        winner = 1;
    end

    pt_end_winner = winner_sequence(end, :);
    pt_start_iso = traj_mat_iso(1, :);
    safe_space = polybuffer(shape, -tool_radius - 1e-5, 'JointType', 'square');
    route_path = connect_points(pt_end_winner, pt_start_iso, safe_space, machine_params);
    final_trajectory = [winner_sequence; route_path; traj_mat_iso(2:end, :)];

    traj_connection = process_nonstop_trajectory(final_trajectory, ...
        machine_params.eps, machine_params.F_cmd, machine_params.F_rapid, ...
        machine_params.F_z, machine_params.A_max, machine_params.depth, ...
        machine_params.travel_height);
    total_time = sum(traj_connection.time);

    if verbose
        fprintf('Tempo total para produção: %f s\n', total_time);
    end

    output_data.trajectory = final_trajectory;
    output_data.total_time = total_time;
    output_data.contour_time = contour_time;
    output_data.zigzag_time = zigzag_time;
    output_data.iso_time = iso_time;
    output_data.winner = winner;
end

