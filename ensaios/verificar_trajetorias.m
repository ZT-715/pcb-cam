%% Conta os segmentos de corte do NCC fora da área permitida ao centro da ferramenta (Seção 8.2)

configurar();

resumo = table();
for placa = ["pcb_ii", "pcb_iii"]
    resultado = planejar_placa(placa);
    raio = resultado.job.ncc.tool_diameter / 2;
    for operacao = resultado.ops(contains({resultado.ops.name}, 'ncc'))
        [fora, ~, total] = check_toolpath_inside(operacao.path, area_da_face(resultado, operacao.name), raio);
        resumo = [resumo; table(placa, string(operacao.name), fora, total, 'VariableNames', ...
            ["placa", "operacao", "segmentos_fora", "segmentos_de_corte"])]; %#ok<AGROW>
    end
end
disp(resumo)

function area = area_da_face(resultado, nome_da_operacao)
    if contains(nome_da_operacao, 'top')
        area = resultado.geometry.ncc_top;
    else
        area = resultado.geometry.ncc_bottom;
    end
end
