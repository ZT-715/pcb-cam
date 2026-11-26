function cfg = modelo_maquina_padrao()
% MODELO_MAQUINA_PADRAO Configuração do modelo de tempo da máquina.
%
%   CFG = MODELO_MAQUINA_PADRAO() devolve os parâmetros de
%   TEMPO_MODELO_MAQUINA: aceleração e tempo mínimo nominais da máquina e
%   erro TCP ajustado ao ensaio de cantos.
%
%   Campos:
%     a_eixos     - [ax ay az] aceleração máxima de cada eixo (mm/s²). A
%                   aceleração de um segmento é min(a_k/|u_k|), u = direção.
%     v_max_eixos - [vx vy vz] velocidade máxima de cada eixo (mm/s).
%     n_filtros   - número de filtros FIR iguais em série; cada um tem
%                   constante T = v/a e o atraso total é Td = n_filtros·T.
%     T_min       - tempo mínimo de cada bloco do G-code (s).
%     eps_tcp     - erro TCP máximo da equação de Ward (mm).

    cfg.a_eixos     = [150 150 150];
    cfg.v_max_eixos = [100 100 15];
    cfg.n_filtros   = 1;
    cfg.T_min       = 16e-3;
    cfg.eps_tcp     = 0.230;
end
