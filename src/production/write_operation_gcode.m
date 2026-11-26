function filename = write_operation_gcode(path_xy, z_cut, feed_machine, feed_travel, travel_height, out_dir, name, feed_z, feed_retract)
% WRITE_OPERATION_GCODE Grava o G-code de uma operação com GENERATE_GCODE.
%
%   FILENAME = WRITE_OPERATION_GCODE(PATH_XY, Z_CUT, FEED_MACHINE,
%   FEED_TRAVEL, TRAVEL_HEIGHT, OUT_DIR, NAME, FEED_Z, FEED_RETRACT) grava
%   PATH_XY [N x 2] (NaN = conexão aérea) em OUT_DIR/NAME.ngc e devolve o
%   caminho do arquivo. FEED_Z e FEED_RETRACT são opcionais.

    if nargin < 8 || isempty(feed_z)
        feed_z = feed_machine;
    end
    if nargin < 9 || isempty(feed_retract)
        feed_retract = feed_travel;
    end
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end
    base = fullfile(out_dir, name);

    evalc('generate_gcode(path_xy'', travel_height, z_cut, feed_travel, feed_machine, base, feed_z, feed_retract)');
    filename = [base '.ngc'];
end
