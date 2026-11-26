%% Gera os códigos G dos ensaios T0, T1 e T3 do Capítulo 7
% Os arquivos executados na máquina estão em ensaios/dados/ensaios_maquina.
% SEGURANÇA: executar no ar, com o zero do eixo Z pelo menos 5 mm acima da placa.

raiz = configurar();
pasta = fullfile(raiz, 'saida', 'ensaios_maquina');
if ~isfolder(pasta), mkdir(pasta); end

config.origem = [10 10];
config.duracao_alvo = 110;
config.tempo_minimo_por_segmento = 16e-3;
config.profundidade = -0.05;
config.altura_de_viagem = 2;
config.avanco_de_viagem = 6000;
config.avanco_em_z = 900;

escrever_referencia(pasta, "T0_referencia", config);

for segmento = [0.005 0.02 0.1 0.4 1]
    escrever_trajetoria(pasta, nome_do_ensaio_t1("T1", segmento, 3000), ...
        reta_em_segmentos(segmento, 3000, config), 3000, config);
end
escrever_trajetoria(pasta, nome_do_ensaio_t1("T1b", 0.02, 600), ...
    reta_em_segmentos(0.02, 600, config), 600, config);

cantos = [0 10; 30 10; 60 10; 75 10; 90 10; 120 10; 150 10; 30 2; 90 2];
for k = 1:height(cantos)
    [desvio, lado] = deal(cantos(k, 1), cantos(k, 2));
    escrever_trajetoria(pasta, nome_do_ensaio_t3(desvio, lado), ...
        zigue_zague(desvio, lado, 3000, config), 3000, config);
end

fprintf('Ensaios gravados em %s\n', pasta);

%% Trajetórias

function pontos = reta_em_segmentos(segmento, avanco, config)
    comprimento_da_linha = 40;
    segmentos_por_linha = round(comprimento_da_linha / segmento);
    duracao_do_segmento = max(config.tempo_minimo_por_segmento, segmento / (avanco / 60));
    total_de_segmentos = ceil(config.duracao_alvo / duracao_do_segmento);

    pontos = zeros(total_de_segmentos + 1, 2);
    pontos(1, :) = config.origem;
    sentido = 1;
    for k = 1:total_de_segmentos
        if k > 1 && mod(k - 1, segmentos_por_linha) == 0
            sentido = -sentido;
        end
        pontos(k + 1, :) = pontos(k, :) + [sentido * segmento, 0];
    end
end

function pontos = zigue_zague(desvio, lado, avanco, config)
    segmentos_por_linha = 8;
    linha = zeros(segmentos_por_linha + 1, 2);
    linha(1, :) = config.origem + [0 30];
    for k = 1:segmentos_por_linha
        angulo = (desvio / 2) * (2 * mod(k, 2) - 1);
        linha(k + 1, :) = linha(k, :) + lado * [cosd(angulo) sind(angulo)];
    end

    total_de_segmentos = ceil(config.duracao_alvo / (lado / (avanco / 60)));
    passadas = ceil(total_de_segmentos / segmentos_por_linha);
    pontos = linha(1, :);
    for passada = 1:passadas
        if mod(passada, 2) == 1
            pontos = [pontos; linha(2:end, :)]; %#ok<AGROW>
        else
            pontos = [pontos; flipud(linha(1:end-1, :))]; %#ok<AGROW>
        end
    end
end

%% Nomes dos arquivos

function nome = nome_do_ensaio_t1(prefixo, segmento, avanco)
    nome = sprintf('%s_blocos_s%s_F%d', prefixo, numero_no_nome(segmento), avanco);
end

function nome = nome_do_ensaio_t3(desvio, lado)
    nome = sprintf('T3_canto_%03ddeg_L%s', desvio, numero_no_nome(lado));
end

function texto = numero_no_nome(valor)
    texto = strrep(sprintf('%g', valor), '.', 'p');
end

%% Escrita do código G

function escrever_referencia(pasta, nome, config)
    arquivo = abrir_ensaio(pasta, nome, config);
    fechar_ensaio(arquivo, config);
end

function escrever_trajetoria(pasta, nome, pontos, avanco, config)
    arquivo = abrir_ensaio(pasta, nome, config);
    fprintf(arquivo, 'G1 X%.3f Y%.3f F%.0f\n', pontos(1, :), config.avanco_de_viagem);
    fprintf(arquivo, 'G1 Z%.3f F%.0f\n', config.profundidade, config.avanco_em_z);
    fprintf(arquivo, 'G04 P1\n');
    fprintf(arquivo, 'G1 X%.3f Y%.3f F%.0f\n', [pontos(2:end, :)'; repmat(avanco, 1, height(pontos) - 1)]);
    fprintf(arquivo, 'G04 P1\n');
    fechar_ensaio(arquivo, config);
end

function arquivo = abrir_ensaio(pasta, nome, config)
    arquivo = fopen(fullfile(pasta, nome + ".ngc"), 'w');
    fprintf(arquivo, '(%s)\nG21\nG90\nG94\nG0 Z%.3f F%.0f\n\nM03\nG04 P2\nG1 Z%.3f F%.0f\n\n', ...
        nome, config.altura_de_viagem, config.avanco_em_z, config.altura_de_viagem, config.avanco_em_z);
end

function fechar_ensaio(arquivo, config)
    fprintf(arquivo, 'G1 Z%.3f F%.0f\nM05\nM30\n', config.altura_de_viagem, config.avanco_em_z);
    fclose(arquivo);
end
