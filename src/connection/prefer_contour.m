function [use_contour, t_contour, t_air] = prefer_contour(contour_path, machine_params)
% PREFER_CONTOUR Decide entre conexão em corte (contorno/reta) e conexão aérea.
%
%   [USE_CONTOUR, T_CONTOUR, T_AIR] = PREFER_CONTOUR(CONTOUR_PATH,
%   MACHINE_PARAMS) compara o tempo de CONTOUR_PATH em corte com o de uma
%   conexão aérea entre os mesmos extremos. Sem parâmetros da máquina,
%   compara comprimentos. Com MACHINE_PARAMS.conexao = "aerea", usa sempre
%   a conexão aérea.

    p_start = contour_path(1, :);
    p_end = contour_path(end, :);
    air_path = [p_start; NaN, NaN; p_end];

    t_contour = connection_time(contour_path, machine_params);
    t_air = connection_time(air_path, machine_params);

    if isnan(t_contour) || isnan(t_air)
        len = sum(sqrt(sum(diff(contour_path, 1, 1).^2, 2)));
        air_cost = 0;
        if isstruct(machine_params) && isfield(machine_params, 'travel_height')
            air_cost = 3 * machine_params.travel_height;
        end
        use_contour = len <= norm(p_end - p_start) + air_cost;
    else
        use_contour = t_contour <= t_air;
    end
    if isstruct(machine_params) && isfield(machine_params, 'conexao') && machine_params.conexao == "aerea"
        use_contour = false;
    end
end
