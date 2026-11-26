%% Tempo do isolamento no pior caso, na configuração adotada e no melhor caso (Seção 8.5)

configurar();

configuracoes = [
    struct('nome', "pior caso",   'juncao', 'round',  'conexao', "aerea")
    struct('nome', "adotado",     'juncao', 'square', 'conexao', "tempo")
    struct('nome', "melhor caso", 'juncao', 'miter',  'conexao', "tempo")
];

resumo = table();
for placa = ["pcb_ii", "pcb_iii"]
    resultado = planejar_placa(placa);
    parametros = parametros_ncc(resultado.job);
    for face = faces(resultado)
        [tempo, aereas] = arrayfun(@(c) isolamento(face.area, parametros, c), configuracoes);
        reducao = 100 * (tempo(1) - tempo) / tempo(1);
        resumo = [resumo; table(placa, face.nome, ...
            tempo(1), aereas(1), tempo(2), aereas(2), reducao(2), tempo(3), aereas(3), reducao(3), ...
            'VariableNames', ["placa", "face", "pior_s", "pior_aereas", ...
            "adotado_s", "adotado_aereas", "adotado_reducao_pct", ...
            "melhor_s", "melhor_aereas", "melhor_reducao_pct"])]; %#ok<AGROW>
    end
end
disp(resumo)

%% Funções

function [tempo, conexoes_aereas] = isolamento(area, parametros, configuracao)
    raio = parametros.tool_diameter / 2;
    passo = parametros.tool_diameter * (1 - parametros.overlap);
    parametros_da_conexao = parametros;
    parametros_da_conexao.conexao = configuracao.conexao;

    area_segura = polybuffer(area, -raio - 1e-5, 'JointType', configuracao.juncao);
    rede = create_tpenet(area, raio, 0, passo, true, parametros.contour_passes, configuracao.juncao);
    [rede, subcaminhos] = create_subpaths_safe(rede, raio, area_segura, parametros_da_conexao, ...
        'external_to_internal', false, passo);
    trajetoria = link_all_subpaths(rede, subcaminhos, area_segura, parametros_da_conexao);

    tempo = estimate_time(trajetoria, parametros);
    conexoes_aereas = sum(isnan(trajetoria(:, 1)));
end

function parametros = parametros_ncc(job)
    parametros = operation_params(job, job.ncc.tool_diameter, job.ncc.z_engrave, ...
        job.ncc.feed_machine, job.ncc.feed_travel, job.ncc.feed_z);
end

function lista = faces(resultado)
    lista = struct('nome', {}, 'area', {});
    if ismember(resultado.job.layers, ["top", "both"])
        lista(end+1) = struct('nome', "superior", 'area', resultado.geometry.ncc_top);
    end
    if ismember(resultado.job.layers, ["bottom", "both"])
        lista(end+1) = struct('nome', "inferior", 'area', resultado.geometry.ncc_bottom);
    end
end
