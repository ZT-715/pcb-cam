function out = tempo_modelo_maquina(P, v_cmd, cfg)
% TEMPO_MODELO_MAQUINA Tempo de execução de uma sequência de movimentos.
%
%   OUT = TEMPO_MODELO_MAQUINA(P, V_CMD, CFG)
%     P     - [N+1 x 3] pontos XYZ (mm), na ordem do G-code.
%     V_CMD - [N x 1] velocidade comandada de cada segmento (mm/s).
%     CFG   - configuração da máquina (MODELO_MAQUINA_PADRAO).
%
%   Modelo de filtros FIR (Ward et al., 2023), n filtros iguais de
%   constante T = v/a:
%     1. Aceleração e velocidade de cada segmento limitadas por eixo:
%        a = min(a_k/|u_k|), v = min(v_cmd, min(v_max,k/|u_k|)).
%     2. Fator alfa em cada vértice pela equação de Ward (ALFA_WARD), com o
%        ângulo interno θ (180° = colinear, 0° = reversão) e o erro eps_tcp.
%        Velocidade no vértice: w = min(alfa_saída·v_i, alfa_entrada·v_i+1).
%        Início e fim do trecho parados.
%     3. Velocidade alcançável no segmento entre w0 e w1:
%        v_ef = min(v, sqrt(a·L + (w0² + w1²)/2)).
%     4. Tempo, com atraso Td = n_filtros·v_ef/a:
%        t = L/v_ef + (Td/2)·[(1 - w0/v_ef)² + (1 - w1/v_ef)²].
%     5. t = max(t, T_min).
%
%   OUT: time, time_kinematic, distances, velocities (v_ef), angulo (θ em
%   cada vértice interno, graus), alpha_in, alpha_out, t_min.

    D = diff(P, 1, 1);
    L = vecnorm(D, 2, 2);
    v_cmd = v_cmd(:);
    if isscalar(v_cmd), v_cmd = repmat(v_cmd, size(L)); end
    ok = L > 1e-9;
    D = D(ok, :); L = L(ok); v_cmd = v_cmd(ok);
    n = numel(L);

    out = struct('time', zeros(n, 1), 'time_kinematic', zeros(n, 1), 'distances', L, ...
        'velocities', zeros(n, 1), 'angulo', zeros(max(n - 1, 0), 1), ...
        'alpha_in', zeros(n, 1), 'alpha_out', zeros(n, 1), 't_min', cfg.T_min);
    if n == 0, return; end

    % 1. Limites por eixo
    U = D ./ L;
    a = 1 ./ max(abs(U) ./ cfg.a_eixos, [], 2);
    v = min(v_cmd, 1 ./ max(abs(U) ./ cfg.v_max_eixos, [], 2));
    T = v ./ a;

    % 2. Velocidade nos vértices (ângulo interno entre -u_i e u_i+1)
    w = zeros(n + 1, 1);
    if n > 1
        theta = acosd(min(max(-sum(U(1:end-1, :) .* U(2:end, :), 2), -1), 1));
        al_saida = alfa_ward(theta, v(1:end-1), T(1:end-1), cfg.eps_tcp);
        al_entrada = alfa_ward(theta, v(2:end), T(2:end), cfg.eps_tcp);
        w(2:n) = min(al_saida .* v(1:end-1), al_entrada .* v(2:end));
        out.angulo = theta;
    end

    % 3. Velocidade alcançável entre as velocidades dos vértices
    w0 = w(1:n); w1 = w(2:n+1);
    v_ef = min(v, sqrt(a .* L + (w0.^2 + w1.^2) / 2));
    a_in = min(w0 ./ v_ef, 1);
    a_out = min(w1 ./ v_ef, 1);

    % 4 e 5. Tempo de cada segmento
    Td = cfg.n_filtros * v_ef ./ a;
    t = L ./ v_ef + (Td / 2) .* ((1 - a_in).^2 + (1 - a_out).^2);

    out.time_kinematic = t;
    out.time = max(t, cfg.T_min);
    out.velocities = v_ef;
    out.alpha_in = a_in;
    out.alpha_out = a_out;
end
