function [C_grid, alpha_LUT] = lut_alpha(N)
% LUT_ALPHA Tabela inversa de C(alpha) = alpha + alpha^3 - alpha^4.
%
%   [C_GRID, ALPHA_LUT] = LUT_ALPHA(N) devolve N valores de alpha para C
%   uniforme em [0, 1]; use interp1(C_GRID, ALPHA_LUT, C).
    alpha_sample = linspace(0, 1, N);
    C_sample = alpha_sample + alpha_sample.^3 - alpha_sample.^4;
    C_grid = linspace(0, 1, N);
    alpha_LUT = interp1(C_sample, alpha_sample, C_grid, 'pchip');
end
