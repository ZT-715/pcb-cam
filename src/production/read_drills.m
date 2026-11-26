function holes = read_drills(outline_file, copper_file, drill_files, scale)
% READ_DRILLS Furos dos arquivos Excellon (.drl).
%
%   HOLES = READ_DRILLS(OUTLINE_FILE, COPPER_FILE, DRILL_FILES, SCALE)
%   devolve [x, y, diâmetro] de cada furo, multiplicados por SCALE, sem
%   repetições. Os Gerbers de contorno e de cobre são exigidos por gerberRead.

    arguments
        outline_file
        copper_file
        drill_files
        scale (1,1) double = 1000
    end

    holes = zeros(0, 3);
    if isempty(drill_files)
        return;
    end
    drill_files = cellstr(drill_files);

    for k = 1:numel(drill_files)
        reader = gerberRead(char(outline_file), char(copper_file), char(drill_files{k}));
        comp = pcbComponent(reader);

        loc = comp.ViaLocations;
        if isempty(loc)
            continue;
        end
        diam = comp.ViaDiameter(:);
        if isscalar(diam)
            diam = repmat(diam, size(loc, 1), 1);
        end

        holes = [holes; loc(:, 1:2) * scale, diam * scale]; %#ok<AGROW>
    end

    if ~isempty(holes)
        holes = uniquetol(holes, 1e-6, 'ByRows', true, 'DataScale', 1);
    end
end
