function sequence = parallel_lines(shape, tool_radius, margin, step, machine_params, zigzag, is_reverse)
% PARALLEL_LINES Trajetória por retas paralelas de uma área.
%
%   SEQUENCE = PARALLEL_LINES(SHAPE, TOOL_RADIUS, MARGIN, STEP,
%   MACHINE_PARAMS, ZIGZAG, IS_REVERSE) recua SHAPE de TOOL_RADIUS + MARGIN,
%   traça retas espaçadas de STEP na direção de FIND_OPTIMAL_ANGLE e as liga
%   em zigue-zague (ZIGZAG = true) ou em corte unidirecional. Retorna
%   [2 x N] com NaN nas conexões aéreas.
arguments
    shape polyshape;
    tool_radius;
    margin,
    step;
    machine_params;
    zigzag = false;
    is_reverse = false;
end

    if tool_radius + margin > 1e-5
        new_shape = polybuffer(shape, - tool_radius - margin, 'JointType', 'square');
    else 
        new_shape = shape;
    end

    angle = find_optimal_angle(new_shape);
    tpenet = compute_tpe_net(step, angle, new_shape);
    if zigzag
        connected_lines = connect_zigzag_milling(tpenet, new_shape, machine_params, is_reverse);
    else
        connected_lines = connect_oneway_milling(tpenet, new_shape, machine_params, is_reverse);
    end
    plot_toolpath(shape, connected_lines);

    sequence = connected_lines';
end