%% Compara o tempo medido das placas com o modelo e com a estimativa por comprimento e avanço
% A remoção de cobre da PCB III foi cronometrada com 4 passes de isolamento e
% 20% de sobreposição; a furação e o recorte dessa placa não foram cronometrados.

raiz = configurar();
modelo = modelo_maquina_padrao();
executados_pcb_ii = fullfile(raiz, 'ensaios', 'dados', 'pcb_ii');
pcb_iii = planejar_placa("pcb_iii", passes=4, sobreposicao=0.2);

operacoes = [
    comparar("PCB II, NCC superior",  fullfile(executados_pcb_ii, 'placa_2_top_ncc.ngc'),    minutos_e_segundos(20, 11),   modelo)
    comparar("PCB II, NCC inferior",  fullfile(executados_pcb_ii, 'placa_4_bottom_ncc.ngc'), minutos_e_segundos(19, 55),   modelo)
    comparar("PCB II, furos",         fullfile(executados_pcb_ii, 'placa_3_top_furos.ngc'),  minutos_e_segundos(3, 9),     modelo)
    comparar("PCB II, recorte",       fullfile(executados_pcb_ii, 'placa_6_recorte.ngc'),    minutos_e_segundos(9, 59),    modelo)
    comparar("PCB III, NCC superior", arquivo_da_operacao(pcb_iii, '2_top_ncc'),             minutos_e_segundos(24, 56),   modelo)
    comparar("PCB III, NCC inferior", arquivo_da_operacao(pcb_iii, '4_bottom_ncc'),          minutos_e_segundos(28, 44.4), modelo)
    comparar("PCB III, furos",        arquivo_da_operacao(pcb_iii, '3_top_furos'),           NaN,                          modelo)
    comparar("PCB III, recorte",      arquivo_da_operacao(pcb_iii, '6_recorte'),             NaN,                          modelo)
];

disp(operacoes)
fprintf('Erro RMS do modelo: %.1f%%\n', rms(operacoes.erro_modelo_pct, 'omitnan'));
fprintf('Erro RMS da estimativa por comprimento e avanço: %.1f%%\n', rms(operacoes.erro_comprimento_pct, 'omitnan'));

%% Funções

function linha = comparar(operacao, arquivo, medido_s, modelo)
    [pontos, avanco] = ler_movimentos_gcode(arquivo);
    velocidade = avanco / 60;
    modelo_s = sum(tempo_modelo_maquina(pontos, velocidade, modelo).time);
    comprimento_s = tempo_comprimento_avanco(pontos, velocidade);

    linha = table(operacao, medido_s, modelo_s, erro_percentual(modelo_s, medido_s), ...
        comprimento_s, erro_percentual(comprimento_s, medido_s), 'VariableNames', ...
        ["operacao", "medido_s", "modelo_s", "erro_modelo_pct", "comprimento_s", "erro_comprimento_pct"]);
end

function arquivo = arquivo_da_operacao(resultado, nome)
    arquivo = resultado.ops(strcmp({resultado.ops.name}, nome)).file;
end

function tempo = minutos_e_segundos(minutos, segundos)
    tempo = 60 * minutos + segundos;
end

function erro = erro_percentual(previsto, medido)
    erro = 100 * (previsto - medido) ./ medido;
end
