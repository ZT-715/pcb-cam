%% Acréscimo de tempo causado pelo tempo mínimo de 16 ms por segmento (Seção 8.6)
% As trajetórias são as do planejamento; muda só o limite no cálculo do tempo.

configurar();
T_MIN = modelo_maquina_padrao().T_min;

resumo = table();
for placa = ["pcb_ii", "pcb_iii"]
    resultado = planejar_placa(placa);
    operacoes = resultado.ops(~arrayfun(@(op) isempty(op.path), resultado.ops));
    tempos = arrayfun(@(op) {tempos_cinematicos(op, resultado.job, T_MIN)}, operacoes);
    de_ncc = contains({operacoes.name}, 'ncc');

    todos = vertcat(tempos{:});
    ncc = vertcat(tempos{de_ncc});
    resumo = [resumo; table(placa, 100 * mean(todos < T_MIN), ...
        minutos(sum(todos)), minutos(sum(max(todos, T_MIN))), ...
        acrescimo_pct(todos, T_MIN), acrescimo_pct(ncc, T_MIN), ...
        'VariableNames', ["placa", "segmentos_limitados_pct", "sem_limite", "com_limite", ...
        "acrescimo_pct", "acrescimo_ncc_pct"])]; %#ok<AGROW>
end
disp(resumo)

%% Funções

function tempos = tempos_cinematicos(operacao, job, T_MIN)
    p = parametros_da_operacao(job, operacao.name);
    movimento = process_nonstop_trajectory(operacao.path, p.eps, p.F_cmd, p.F_rapid, ...
        p.F_z, p.A_max, p.depth, p.travel_height);
    tempos = movimento.time_kinematic;
    conferir_com_o_planejamento(tempos, operacao, T_MIN);
end

function conferir_com_o_planejamento(tempos, operacao, T_MIN)
    tempo_com_limite = sum(max(tempos, T_MIN));
    assert(abs(tempo_com_limite - operacao.machine_time) <= 1e-6 * max(1, operacao.machine_time), ...
        'O tempo recalculado de %s difere do planejamento.', operacao.name);
end

function p = parametros_da_operacao(job, nome)
    if contains(nome, 'ncc')
        p = operation_params(job, job.ncc.tool_diameter, job.ncc.z_engrave, ...
            job.ncc.feed_machine, job.ncc.feed_travel, job.ncc.feed_z);
    elseif contains(nome, 'furos') || contains(nome, 'alinhamento')
        p = operation_params(job, job.holes.tool_diameter, job.mill.z_mill, ...
            job.holes.feed_machine, job.mill.feed_travel, job.holes.feed_z);
    else
        p = operation_params(job, job.mill.tool_diameter, job.mill.z_mill, ...
            job.mill.feed_machine, job.mill.feed_travel, job.mill.feed_z);
    end
end

function pct = acrescimo_pct(tempos, T_MIN)
    pct = 100 * (sum(max(tempos, T_MIN)) - sum(tempos)) / sum(tempos);
end

function d = minutos(segundos)
    d = duration(0, 0, round(segundos), 'Format', 'mm:ss');
end
