function t = estimate_time(path_xy, mp)
% ESTIMATE_TIME Tempo estimado (s) de execução de uma trajetória completa.
%
%   T = ESTIMATE_TIME(PATH_XY, MP) usa PROCESS_NONSTOP_TRAJECTORY, com a
%   ferramenta partindo e terminando na altura de viagem.

    if isempty(path_xy) || all(isnan(path_xy(:)))
        t = 0;
        return;
    end
    data = process_nonstop_trajectory(path_xy, mp.eps, mp.F_cmd, mp.F_rapid, ...
        mp.F_z, mp.A_max, mp.depth, mp.travel_height);
    t = sum(data.time);
end
