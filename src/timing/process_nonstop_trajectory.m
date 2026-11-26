function trajectory_data = process_nonstop_trajectory(toolpath_xy, eps_tcp, v_cut, v_rapid, v_z, modelo, z_cut, z_travel, start_in_air, end_in_air)
% PROCESS_NONSTOP_TRAJECTORY Processa os caminhos XY em movimentos XYZ e
% calcula o tempo de execução na CNC.
%
%   TOOLPATH_XY:  Caminho XY com NaN separando trechos de corte.
%   EPS_TCP:      Erro TCP máximo nos cantos (mm), da equação de Ward.
%   V_CUT:        Velocidade de corte (mm/s).
%   V_RAPID:      Velocidade de viagem aérea (mm/s).
%   V_Z:          [V_Z_MAX] ou [V_Z_MAX V_PLUNGE]: velocidade máxima do eixo
%                 Z e avanço de mergulho comandado. Mergulho a
%                 min(V_PLUNGE, V_Z_MAX) e retração a min(V_RAPID, V_Z_MAX),
%                 como no G-code (GENERATE_GCODE). Sem V_PLUNGE, o mergulho
%                 usa V_CUT.
%   MODELO:       Configuração da máquina (MODELO_MAQUINA_PADRAO). Um
%                 escalar é aceito como aceleração igual nos três eixos,
%                 com os demais parâmetros padrão.
%   Z_CUT:        Altura de corte (mm).
%   Z_TRAVEL:     Altura de viagem (mm).
%   START_IN_AIR: (opcional, padrão true) parte da altura de viagem e
%                 mergulha no primeiro ponto; false = já está em corte.
%   END_IN_AIR:   (opcional, padrão true) retrai ao final.
%
%   O tempo é calculado por TEMPO_MODELO_MAQUINA. Com START_IN_AIR =
%   END_IN_AIR = false, o tempo é o de um trecho intermediário, usado para
%   comparar alternativas de conexão.

    if nargin < 9, start_in_air = true; end
    if nargin < 10, end_in_air = true; end

    if isstruct(modelo)
        cfg = modelo;
    else
        cfg = modelo_maquina_padrao();
        cfg.a_eixos = modelo(1) * [1 1 1];
    end
    cfg.eps_tcp = eps_tcp;

    [points_xyz, v_cmd] = expand_toolpath(toolpath_xy, v_cut, v_rapid, v_z, ...
        z_travel, z_cut, start_in_air, end_in_air);
    r = tempo_modelo_maquina(points_xyz, v_cmd, cfg);

    trajectory_data.points_xyz = points_xyz;
    trajectory_data.distances = r.distances;
    trajectory_data.velocities = r.velocities;
    trajectory_data.angles_next = r.angulo;
    trajectory_data.alpha_out = r.alpha_out;
    trajectory_data.alpha_in = r.alpha_in;
    trajectory_data.time = r.time;
    trajectory_data.time_kinematic = r.time_kinematic;
    trajectory_data.t_min = r.t_min;
end

function [points_xyz, velocities] = expand_toolpath(toolpath_xy, v_cut, v_rapid, v_z, z_travel, z_cut, start_in_air, end_in_air)
% Trajetória 2.5D com a velocidade comandada de cada segmento, a partir
% dos separadores NaN e do estado da ferramenta (no ar ou em corte).
% VELOCITIES(i) é a velocidade do segmento POINTS(i) -> POINTS(i+1).

    v_z_max = v_z(1);
    if numel(v_z) >= 2
        v_plunge = min(v_z(2), v_z_max);
    else
        v_plunge = min(v_cut, v_z_max);
    end
    v_retract = min(v_rapid, v_z_max);

    num_points = size(toolpath_xy, 1);
    pts = zeros(num_points * 2 + 1, 3);
    vel = zeros(num_points * 2 + 1, 1);     % velocidade para chegar ao ponto
    n = 0;
    is_in_air = start_in_air;

    for i = 1:num_points
        pt = toolpath_xy(i, :);
        if isnan(pt(1)) || isnan(pt(2))
            if ~is_in_air && n > 0
                is_in_air = true;
                n = n + 1; pts(n, :) = [pts(n-1, 1:2), z_travel]; vel(n) = v_retract;
            end
        elseif is_in_air
            n = n + 1; pts(n, :) = [pt, z_travel]; vel(n) = v_rapid;    % viagem
            n = n + 1; pts(n, :) = [pt, z_cut];    vel(n) = v_plunge;   % mergulho
            is_in_air = false;
        else
            n = n + 1; pts(n, :) = [pt, z_cut]; vel(n) = v_cut;         % corte
        end
    end
    if ~is_in_air && end_in_air && n > 0
        n = n + 1; pts(n, :) = [pts(n-1, 1:2), z_travel]; vel(n) = v_retract;
    end

    if n == 0
        points_xyz = zeros(0, 3); velocities = zeros(0, 1); return;
    end
    pts = pts(1:n, :); vel = vel(1:n);

    % Remove pontos sobrepostos ao último ponto mantido
    keep = true(n, 1); last = 1;
    for i = 2:n
        if norm(pts(i, :) - pts(last, :)) < 1e-5
            keep(i) = false;
        else
            last = i;
        end
    end
    points_xyz = pts(keep, :);
    velocities = vel(keep);
    velocities = velocities(2:end);
end
