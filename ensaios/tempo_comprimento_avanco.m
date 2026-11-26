function tempo = tempo_comprimento_avanco(pontos, velocidade)
%TEMPO_COMPRIMENTO_AVANCO Tempo a velocidade constante, como estima o FlatCAM.
%   TEMPO = TEMPO_COMPRIMENTO_AVANCO(PONTOS, VELOCIDADE) soma o comprimento de
%   cada segmento (mm) dividido pela sua velocidade comandada (mm/s).

    comprimentos = vecnorm(diff(pontos, 1, 1), 2, 2);
    tempo = sum(comprimentos ./ velocidade(:));
end
