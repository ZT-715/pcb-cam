function alfa = alfa_ward(theta, v, T, eps_tcp)
% ALFA_WARD Fator de velocidade no vértice pela equação de Ward et al. (2023).
%
%   ALFA = ALFA_WARD(THETA, V, T, EPS_TCP) resolve
%       C(alfa) = alfa + alfa³ - alfa⁴ = 3·sqrt(2)·eps / (V·T·sqrt(1 + cos θ))
%   THETA é o ângulo interno do vértice, em graus (180° = segmentos
%   colineares, 0° = reversão); V em mm/s; T, constante do filtro, em s;
%   EPS_TCP em mm. Colinear: ALFA = 1. Reversão: ALFA = 0.

    persistent C_grid alfa_lut
    if isempty(C_grid)
        [C_grid, alfa_lut] = lut_alpha(2000);
    end
    raiz = sqrt(max(1 + cosd(theta), 0));
    C = 3 * sqrt(2) * eps_tcp ./ max(v .* T .* raiz, eps);
    alfa = interp1(C_grid, alfa_lut, min(max(C, 0), 1), 'linear');
    alfa(theta > 180 - 1e-6) = 1;
    alfa(theta < 0.1) = 0;
end
