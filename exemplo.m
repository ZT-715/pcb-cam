%% Gera o código G da PCB I, a placa de face simples da monografia
% Para outra placa, troque os arquivos e as dimensões da placa virgem.

raiz = configurar();
pasta = fullfile(raiz, 'placas', 'pcb_i');

job = default_job();
job.files.outline    = fullfile(pasta, 'teste_pcb1g2_A-Edge_Cuts.gbr');
job.files.top_copper = fullfile(pasta, 'teste_pcb1g2_A-F_Cu.gbr');
job.files.drills     = {fullfile(pasta, 'teste_pcb1g2_A.drl')};
job.layers = "top";
job.blank.size_x = 70;
job.blank.size_y = 100;
job.blank.origin = "center";
job.ncc.overlap = 0.4;
job.ncc.contour_passes = 3;
job = production_job(job);

job.output.dir = fullfile(raiz, 'saida', 'pcb_i');
job.output.prefix = 'placa';
resultado = pcb_cam(job);
