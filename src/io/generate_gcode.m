function generate_gcode(sequence_xy, travel_height, depth, feedrate_travel, feedrate_machine, filename, feedrate_plunge, feedrate_retract)
% GENERATE_GCODE Grava uma trajetória XY como G-code.
%
%   GENERATE_GCODE(SEQUENCE_XY, TRAVEL_HEIGHT, DEPTH, FEEDRATE_TRAVEL,
%   FEEDRATE_MACHINE, FILENAME, FEEDRATE_PLUNGE, FEEDRATE_RETRACT) grava
%   SEQUENCE_XY [2 x N] (NaN = conexão aérea) em FILENAME.ngc: corte em
%   DEPTH, viagens em TRAVEL_HEIGHT, todos os movimentos em G1. Os avanços
%   de mergulho e retração são opcionais.
    if nargin < 7 || isempty(feedrate_plunge)
        feedrate_plunge = feedrate_machine;
    end
    if nargin < 8 || isempty(feedrate_retract)
        feedrate_retract = feedrate_travel;
    end
    sequence_xyz = xy_to_xyz(sequence_xy, travel_height, depth);
    
    filename = strcat(filename, '.ngc');
    fid = fopen(filename, 'w');
    if fid == -1
        error('Não foi possível criar %s.', filename);
    end
    
    % Cabeçalho
    fprintf(fid, 'G21\n');
    fprintf(fid, 'G90\n');
    fprintf(fid, 'G94\n');
    fprintf(fid, 'G0 Z%.3f F%.0f\n\n', travel_height, feedrate_retract);
    fprintf(fid, 'M03\n');
    fprintf(fid, 'G04 P2\n');   % espera o spindle
    
    fprintf(fid, 'G1 Z%.3f F%.0f\n\n', travel_height, feedrate_retract); 
    
    % Movimentos
    curr_x = NaN; 
    curr_y = NaN; 
    curr_z = travel_height;
    num_points = size(sequence_xyz, 2);
    
    for i = 1:num_points
        x = sequence_xyz(1, i);
        y = sequence_xyz(2, i);
        z = sequence_xyz(3, i);
        
        % Só Z: retração ou mergulho
        if (~isnan(curr_x) && x == curr_x && y == curr_y) && z ~= curr_z
            if z > curr_z
                fprintf(fid, 'G1 Z%.3f F%.0f\n', z, feedrate_retract);
            else
                fprintf(fid, 'G1 Z%.3f F%.0f\n', z, feedrate_plunge);
            end
        else
            if z >= travel_height
                fprintf(fid, 'G1 X%.3f Y%.3f F%.0f\n\n', x, y, feedrate_travel);
            else
                fprintf(fid, 'G1 X%.3f Y%.3f F%.0f\n', x, y, feedrate_machine);
            end
        end
        
        curr_x = x;
        curr_y = y;
        curr_z = z;
    end
    
    % Rodapé
    fprintf(fid, 'M05\n');
    fprintf(fid, 'M30\n');
    fclose(fid);
    
    fprintf('G-code salvo em %s\n', filename);
end