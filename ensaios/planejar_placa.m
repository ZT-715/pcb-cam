function resultado = planejar_placa(placa, opcoes)
%PLANEJAR_PLACA Planeja uma placa da monografia sem mensagens nem figuras.
%   RESULTADO = PLANEJAR_PLACA(PLACA, passes=N, sobreposicao=S) troca o número
%   de passes de isolamento e a sobreposição dos contornos da configuração.

    arguments
        placa (1, 1) string
        opcoes.passes = []
        opcoes.sobreposicao = []
    end

    job = configurar_placa(placa);
    if ~isempty(opcoes.passes), job.ncc.contour_passes = opcoes.passes; end
    if ~isempty(opcoes.sobreposicao), job.ncc.overlap = opcoes.sobreposicao; end

    job.output.dir = char(fullfile(tempname, placa));
    job.output.show_figures = false;
    job.output.save_figures = false;
    job.output.verbose = false;

    aviso_de_poligono_corrigido = 'MATLAB:polyshape:repairedBySimplify';
    estado_anterior = warning('off', aviso_de_poligono_corrigido);
    restaurar_aviso = onCleanup(@() warning(estado_anterior));

    resultado = pcb_cam(job);
    close all
end
