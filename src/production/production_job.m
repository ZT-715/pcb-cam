function job = production_job(job)
% PRODUCTION_JOB Aplica a JOB os parâmetros de produção das placas de teste.
%
%   JOB = PRODUCTION_JOB(JOB) define ferramentas, profundidades, avanços,
%   margem e altura de viagem; mantém arquivos, faces e placa virgem. Sem
%   argumento, parte de DEFAULT_JOB.

    if nargin < 1
        job = default_job();
    end

    % Remoção de cobre (diâmetro com folga para o arredondamento do Gerber)
    job.ncc.tool_diameter = 0.2 - 1e-4;
    job.ncc.z_engrave     = -0.05;
    job.ncc.feed_machine  = 3000;
    job.ncc.feed_travel   = 6000;
    job.ncc.feed_z        = 900;

    % Recorte
    job.mill.tool_diameter = 1.0;
    job.mill.z_mill        = -1.8;
    job.mill.feed_machine  = 50;
    job.mill.feed_travel   = 6000;
    job.mill.feed_z        = 300;

    job.cut.offset_radius = 0.5;
    job.cut.tab_length    = 2.0;

    % Furos e furos de alinhamento
    job.holes.tool_diameter = 1;
    job.holes.feed_machine  = 50;
    job.holes.feed_z        = 300;
    job.align.diameter      = 1.0;
    job.align.edge_margin   = 5.1;

    % Máquina
    job.blank.margin = [5 5];
    job.machine.F_z = 15.0;
    job.machine.travel_height = 2.0;
end
