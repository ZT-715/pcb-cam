function output_path = contour_parallel(shape, tool_radius, margin, path_interval, machine_params, is_reverse, limit_passes, passes, show_plot, conventional, direction)
% CONTOUR_PARALLEL Trajetória por contornos paralelos de uma área.
%
%   OUTPUT_PATH = CONTOUR_PARALLEL(SHAPE, TOOL_RADIUS, MARGIN, PATH_INTERVAL,
%   MACHINE_PARAMS, ...) cria a TPE Net, agrupa os nós em subcaminhos e os
%   liga pela rotina de conexão. Retorna [2 x N] com NaN nas conexões
%   aéreas. Opções: IS_REVERSE, LIMIT_PASSES/PASSES (isolamento),
%   SHOW_PLOT, CONVENTIONAL (fresamento discordante) e DIRECTION
%   ("external_to_internal" ou "internal_to_external").
    arguments
        shape polyshape;
        tool_radius double;
        margin double;
        path_interval double;
        machine_params;
        is_reverse = false;
        limit_passes = false;
        passes = 3;
        show_plot (1,1) logical = true;
        conventional (1,1) logical = false;
        direction (1,1) string = "external_to_internal";
    end

    safe_space  = polybuffer(shape, - tool_radius - 1e-5, 'JointType', 'square');
    
    TPENet0 = create_tpenet(shape, tool_radius, margin, path_interval, limit_passes, passes);
    [TPENet, sub_paths] = create_subpaths_safe(TPENet0, tool_radius, safe_space, machine_params, direction, is_reverse, path_interval, conventional);
    connected_lines = link_all_subpaths(TPENet, sub_paths, safe_space, machine_params);
    if show_plot
        plot_toolpath(shape, connected_lines);
    end

    output_path = connected_lines';
end
