%% Calibra o modelo de tempo com os ensaios T1 e T3 do Capítulo 7

raiz = configurar();
pasta = fullfile(raiz, 'ensaios', 'dados', 'ensaios_maquina');

ensaios = carregar_ensaios(pasta);

modelo = modelo_maquina_padrao();
modelo.a_eixos = [150 150 150];
modelo.T_min = 16e-3;

cantos_de_10_mm = ensaios.ensaio == "T3" & ensaios.segmento_mm == 10 & ensaios.desvio_graus > 0;
[modelo.eps_tcp, busca] = ajustar_eps_tcp(ensaios(cantos_de_10_mm, :), modelo, 0.010:0.001:0.500);

ensaios.previsto_s = tempo_previsto(ensaios.trajetoria, modelo);
ensaios.erro_pct = erro_percentual(ensaios.previsto_s, ensaios.liquido_s);

fprintf('Erro TCP ajustado: %.3f mm\n', modelo.eps_tcp);
for grupo = ["T1", "T3"]
    fprintf('Erro RMS do ensaio %s: %.1f%%\n', grupo, rms(ensaios.erro_pct(ensaios.ensaio == grupo)));
end
disp(ensaios(:, ["arquivo", "liquido_s", "previsto_s", "erro_pct"]))

%% Ensaios medidos

function ensaios = carregar_ensaios(pasta)
    ESCALA_DO_CRONOMETRO = 1.076;
    DURACAO_DAS_MARCAS_G04 = 2;

    ensaios = readtable(fullfile(pasta, 'tempos_medidos.csv'), 'TextType', 'string');
    referencia = ensaios.medido_s(ensaios.ensaio == "T0");
    ensaios = ensaios(ensaios.ensaio ~= "T0", :);

    ensaios.liquido_s = (ensaios.medido_s - referencia - DURACAO_DAS_MARCAS_G04) / ESCALA_DO_CRONOMETRO;
    ensaios.trajetoria = arrayfun(@(arquivo) ler_trajetoria(fullfile(pasta, arquivo + ".ngc")), ...
        ensaios.arquivo, 'UniformOutput', false);
end

function trajetoria = ler_trajetoria(arquivo)
    [pontos, avanco] = ler_movimentos_gcode(arquivo);
    trajetoria = struct('pontos', pontos, 'velocidade', avanco / 60);
end

%% Ajuste do erro TCP

function [melhor_eps, busca] = ajustar_eps_tcp(ensaios, modelo, candidatos)
    erro = arrayfun(@(candidato) soma_dos_erros_ao_quadrado(ensaios, ...
        setfield(modelo, 'eps_tcp', candidato)), candidatos); %#ok<SFLD>
    [~, melhor] = min(erro);
    melhor_eps = candidatos(melhor);
    busca = table(candidatos', erro', 'VariableNames', ["eps_tcp_mm", "soma_dos_erros_ao_quadrado"]);
end

function soma = soma_dos_erros_ao_quadrado(ensaios, modelo)
    relativo = (tempo_previsto(ensaios.trajetoria, modelo) - ensaios.liquido_s) ./ ensaios.liquido_s;
    soma = sum(relativo .^ 2);
end

%% Tempo e erro

function tempo = tempo_previsto(trajetorias, modelo)
    tempo = cellfun(@(t) sum(tempo_modelo_maquina(t.pontos, t.velocidade, modelo).time), trajetorias);
end

function erro = erro_percentual(previsto, medido)
    erro = 100 * (previsto - medido) ./ medido;
end
