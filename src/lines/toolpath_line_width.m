function lw = toolpath_line_width(path_interval, data_width, width_cm)
% TOOLPATH_LINE_WIDTH Espessura de linha (pt) legível para uma trajetória densa.
%
%   LW = TOOLPATH_LINE_WIDTH(PATH_INTERVAL, DATA_WIDTH, WIDTH_CM) devolve
%   ~35 % do espaçamento entre passes na escala da figura, entre 0,1 e
%   0,8 pt. PATH_INTERVAL e DATA_WIDTH em mm; WIDTH_CM em cm.

    axes_width_pt = 0.85 * width_cm * 72 / 2.54;
    spacing_pt = path_interval * axes_width_pt / max(data_width, eps);
    lw = min(max(0.35 * spacing_pt, 0.1), 0.8);
end
