%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Title:          Fourier Analysis Script
%
%   Author:         Michael W. Hackemack
%   Institution:    Texas A&M University
%   Year:           2015
%   
%   Description:    
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Note(s):        
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Clear Project Space
% -------------------
if exist('pbool', 'var')
    clearvars -except pbool
else
    clear; pbool = false;
end
clc; close all; %format long e
if ~pbool, fpath = get_path(); addpath(fpath); pbool = true; end
% Define Path
% -----------
global glob
glob = get_globals('Home');
glob.print_info = false;
% Define all user inputs
% ------------------------------------------------------------------------------
inp = '2D_1G_DSA'; addpath([glob.input_path,inp]);
data = load_user_input();
% additional inputs
data.Type = 'Grid';
data.NumberPhasePerDim = 81;
% end user input section
% ------------------------------------------------------------------------------
% Populate data and output structures
% -----------------------------------
print_FA_heading(data);
[data, inputs] = process_fourier_inputs( data );
inputs = build_phase_transformation_matrix(data, inputs);
% Retrieve all spectrum data and postprocess
% ------------------------------------------
outputs = calculate_eigenspectrums(data, inputs);
% Loop through quadrature sets
for q=1:length(data.Neutronics.Transport.SnLevels)
    % Loop through meshes
    for i=1:inputs.TotalMeshes
        
    end
end
