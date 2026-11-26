function job = configurar_placa(placa)
%CONFIGURAR_PLACA Configuração de produção das placas da monografia.
%   JOB = CONFIGURAR_PLACA(PLACA), com PLACA igual a "pcb_i", "pcb_ii" ou "pcb_iii".

    pasta = fullfile(fileparts(mfilename('fullpath')), placa);
    arquivo = @(nome) fullfile(pasta, nome);
    job = default_job();

    switch placa
        case "pcb_i"
            job.files.outline    = arquivo('teste_pcb1g2_A-Edge_Cuts.gbr');
            job.files.top_copper = arquivo('teste_pcb1g2_A-F_Cu.gbr');
            job.files.drills     = {arquivo('teste_pcb1g2_A.drl')};
            job.layers = "top";
            job.blank.size_x = 70;
            job.blank.size_y = 100;
            job.blank.origin = "center";
            job.ncc.overlap = 0.4;
            job.ncc.contour_passes = 3;

        case "pcb_ii"
            job.files.outline       = arquivo('NS07-Edge_Cuts.gbr');
            job.files.top_copper    = arquivo('NS07-F_Cu.gbr');
            job.files.bottom_copper = arquivo('NS07-B_Cu.gbr');
            job.files.drills        = {arquivo('NS07-PTH.drl')};
            job.layers = "both";
            job.blank.size_x = 190;
            job.blank.size_y = 150;
            job.blank.origin = [8 6];
            job.ncc.overlap = 0.4;
            job.ncc.contour_passes = 3;

        case "pcb_iii"
            job.files.outline       = arquivo('Hydro_Battery_Charger_OUTLINES.gbr');
            job.files.top_copper    = arquivo('Hydro_Battery_Charger_COPPER-TOP.gbr');
            job.files.bottom_copper = arquivo('Hydro_Battery_Charger_COPPER-BOTTOM.gbr');
            job.files.drills        = {arquivo('Hydro_Battery_Charger_DRILLS-PTH.drl'), ...
                                       arquivo('Hydro_Battery_Charger_DRILLS-NPTH.drl')};
            job.layers = "both";
            job.blank.size_x = 200;
            job.blank.size_y = 150;
            job.blank.origin = "center";
            job.ncc.overlap = 0.4;
            job.ncc.contour_passes = 5;
            job.align.edge_margin = 6;

        otherwise
            error('A placa deve ser "pcb_i", "pcb_ii" ou "pcb_iii".');
    end

    job = production_job(job);
    job.output.prefix = 'placa';
end
