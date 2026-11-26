function [ncc, outline] = read_gerber_ncc(outline_file, copper_file, scale)
% READ_GERBER_NCC Área de remoção de cobre a partir dos Gerbers.
%
%   [NCC, OUTLINE] = READ_GERBER_NCC(OUTLINE_FILE, COPPER_FILE, SCALE) lê o
%   contorno e o cobre, multiplica as coordenadas por SCALE e devolve a
%   área a usinar (contorno menos cobre) e o contorno da placa.

    arguments
        outline_file (1,:) char
        copper_file (1,:) char
        scale (1,1) double = 1. 
    end

    outline_reader = gerberRead(outline_file);
    copper_reader = gerberRead(copper_file);

    outline_reader.NumPointsOnCurves = 12;
    copper_reader.NumPointsOnCurves = 12;
    
    outline_shapes = shapes(outline_reader);
    copper_shapes = shapes(copper_reader);
    
    outline_vertices = clean_vertices(outline_shapes.Vertices(:, 1:2));
    copper_vertices = clean_vertices(copper_shapes.Vertices(:, 1:2));
   
    outline_poly = polyshape(outline_vertices * scale);
    copper_poly = polyshape(copper_vertices * scale);
    
    regs = regions(outline_poly);
    outline = repmat(polyshape, length(regs), 1);
    
    for i = 1:length(regs)
        r = regs(i);
        
        if numboundaries(r) > 1
            % Contorno desenhado como linha: usa o centro da linha
            half_width = area(r) / (perimeter(r) + eps);
            outline(i) = polybuffer(rmholes(r), -half_width, 'JointType', 'square');
        else
            outline(i) = r;
        end
    end
    
    outline = simplify(outline);
    copper_poly = simplify(copper_poly);

    ncc = subtract(outline, copper_poly);
    ncc = simplify(ncc);
end

function V_out = clean_vertices(V)
% CLEAN_VERTICES Remove vértices repetidos e contornos com menos de 3 vértices.

    is_sep = any(isnan(V), 2);
    limits = [0; find(is_sep); size(V, 1) + 1];

    pieces = {};
    for k = 1:numel(limits) - 1
        seg = V(limits(k)+1 : limits(k+1)-1, :);
        if isempty(seg)
            continue;
        end

        keep = [true; any(diff(seg, 1, 1) ~= 0, 2)];
        seg = seg(keep, :);

        if size(seg, 1) > 1 && all(seg(end, :) == seg(1, :))
            seg(end, :) = [];
        end

        if size(seg, 1) >= 3
            pieces{end+1} = seg; %#ok<AGROW>
        end
    end

    if isempty(pieces)
        V_out = zeros(0, 2);
        return;
    end

    n_rows = sum(cellfun(@(p) size(p, 1), pieces)) + numel(pieces) - 1;
    V_out = NaN(n_rows, 2);
    row = 1;
    for k = 1:numel(pieces)
        n = size(pieces{k}, 1);
        V_out(row:row+n-1, :) = pieces{k};
        row = row + n + 1;
    end
end