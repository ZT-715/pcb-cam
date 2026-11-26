function sequence_xyz = xy_to_xyz(sequence_xy, travel_height, depth)
% XY_TO_XYZ Converte uma trajetória XY (NaN = conexão aérea) em pontos XYZ.
%
%   SEQUENCE_XYZ = XY_TO_XYZ(SEQUENCE_XY, TRAVEL_HEIGHT, DEPTH) devolve uma
%   matriz [4 x M] (X, Y, Z e uma linha de zeros) com mergulhos e
%   retrações explícitos.
    num_points = size(sequence_xy, 2);
    sequence_xyz = zeros(4, 0);
    is_in_air = true;
    
    for i = 1:num_points
        x = sequence_xy(1, i);
        y = sequence_xy(2, i);
        
        if isnan(x) || isnan(y)
            if ~is_in_air
                % Retração
                prev_x = sequence_xyz(1, end);
                prev_y = sequence_xyz(2, end);
                sequence_xyz(:, end+1) = [prev_x; prev_y; travel_height; 0];
                is_in_air = true;
            end
        else
            if is_in_air
                % Viagem e mergulho
                sequence_xyz(:, end+1) = [x; y; travel_height; 0];
                sequence_xyz(:, end+1) = [x; y; depth; 0];
                is_in_air = false;
            else
                sequence_xyz(:, end+1) = [x; y; depth; 0];
            end
        end
    end
    
    % Retração final
    if ~is_in_air
        prev_x = sequence_xyz(1, end);
        prev_y = sequence_xyz(2, end);
        sequence_xyz(:, end+1) = [prev_x; prev_y; travel_height; 0];
    end
end