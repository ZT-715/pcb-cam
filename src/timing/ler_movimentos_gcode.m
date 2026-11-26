function [P, F] = ler_movimentos_gcode(arquivo)
% LER_MOVIMENTOS_GCODE Pontos e avanços dos movimentos G0/G1 de um G-code.
%
%   [P, F] = LER_MOVIMENTOS_GCODE(ARQUIVO) devolve P [N+1 x 3] (X, Y, Z
%   em mm, na ordem do arquivo) e F [N x 1], o avanço (mm/min) de cada
%   segmento P(i) -> P(i+1). Coordenadas ainda não definidas no início do
%   arquivo recebem o primeiro valor conhecido.

    linhas = readlines(arquivo);
    x = NaN; y = NaN; z = NaN; f = NaN;
    P = zeros(numel(linhas), 3); Fp = zeros(numel(linhas), 1); n = 0;
    for i = 1:numel(linhas)
        s = strtrim(linhas(i));
        if ~(startsWith(s, "G1") || startsWith(s, "G0")), continue; end
        tok = regexp(s, '([XYZF])(-?[\d.]+)', 'tokens');
        for k = 1:numel(tok)
            val = str2double(tok{k}{2});
            switch tok{k}{1}
                case 'X', x = val;
                case 'Y', y = val;
                case 'Z', z = val;
                case 'F', f = val;
            end
        end
        n = n + 1; P(n, :) = [x y z]; Fp(n) = f;
    end
    P = P(1:n, :);
    for c = 1:3
        k = find(~isnan(P(:, c)), 1);
        if isempty(k), P(:, c) = 0; else, P(1:k-1, c) = P(k, c); end
    end
    F = Fp(2:n);
end
