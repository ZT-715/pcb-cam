function holes = alignment_holes(size_x, size_y, diameter, edge_margin)
% ALIGNMENT_HOLES Furos de alinhamento para produção em dupla face.
%
%   HOLES = ALIGNMENT_HOLES(SIZE_X, SIZE_Y, DIAMETER, EDGE_MARGIN) devolve
%   [x, y, diâmetro] de três furos simétricos ao eixo de virada x = SIZE_X/2:
%   dois nos cantos inferiores e um no centro da borda superior.

    arguments
        size_x (1,1) double {mustBePositive}
        size_y (1,1) double {mustBePositive}
        diameter (1,1) double {mustBePositive}
        edge_margin (1,1) double {mustBePositive}
    end

    if edge_margin < diameter / 2
        error('pcb_cam:alignment', 'Furo de alinhamento fora da placa.');
    end
    if 2 * edge_margin + diameter > size_x || edge_margin + diameter > size_y
        error('pcb_cam:alignment', 'Placa virgem pequena demais para os furos de alinhamento.');
    end

    holes = [edge_margin,          edge_margin,          diameter;
             size_x - edge_margin, edge_margin,          diameter;
             size_x / 2,           size_y - edge_margin, diameter];

    mirrored = [size_x - holes(:, 1), holes(:, 2:3)];
    assert(isequal(sortrows(round(mirrored, 9)), sortrows(round(holes, 9))), ...
        'pcb_cam:alignment', 'Furos de alinhamento não são simétricos ao eixo de virada.');
end
