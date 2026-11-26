function raiz = configurar()
%CONFIGURAR Adiciona o programa, as placas e os ensaios ao caminho do MATLAB.
    raiz = fileparts(mfilename('fullpath'));
    addpath(raiz, fullfile(raiz, 'placas'), fullfile(raiz, 'ensaios'));
    addpath(genpath(fullfile(raiz, 'src')));
end
