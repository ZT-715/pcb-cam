function t = connection_time(path_xy, machine_params)
% CONNECTION_TIME Tempo de execução (s) de um trecho de conexão.
%
%   T = CONNECTION_TIME(PATH_XY, MACHINE_PARAMS) calcula o tempo de PATH_XY
%   [N x 2] (NaN = conexão aérea) com a ferramenta em corte no início e no
%   fim. Retorna NaN se MACHINE_PARAMS não tiver os parâmetros da máquina.

    required = {'eps', 'F_cmd', 'F_rapid', 'F_z', 'A_max', 'depth', 'travel_height'};
    if ~isstruct(machine_params) || ~all(isfield(machine_params, required))
        t = NaN;
        return;
    end

    if size(path_xy, 1) < 2
        t = 0;
        return;
    end

    data = process_nonstop_trajectory(path_xy, ...
        machine_params.eps, machine_params.F_cmd, machine_params.F_rapid, ...
        machine_params.F_z, machine_params.A_max, machine_params.depth, ...
        machine_params.travel_height, false, false);

    t = sum(data.time);
end
