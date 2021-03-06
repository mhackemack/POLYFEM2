%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Title:          Diffusion Limit Runs
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
function Main_Diffusion_Limit(out_dir)
clearvars -except out_dir; close all; clc;
% Specify some parameters
% linear_BFs = {'PWLD'};
% quadratic_BFs = {'MAXENT'};
% geom_types = {'Sq_poly'};
linear_BFs = {'MAXENT','PWLD','WACHSPRESS','MV'};
quadratic_BFs = {'MAXENT','PWLD','WACHSPRESS','MV'};
geom_types = {'quad','tri','Sq_poly'};
% ep_log_vals = [-5];
ep_log_vals = [-1,-2,-3,-4,-5];
% Get Globals, Set Path, and Initialize Domain Space
global glob
glob = get_globals('Office');
fpath = get_path();
addpath(fpath);
addpath([glob.input_path,'DL_Transport']);
transdata = load_user_input();
addpath([glob.input_path,'DL_Diffusion']);
diffdata = load_user_input();
% Loop through all geometry types
for g=1:length(geom_types)
    geometry = get_geometry(geom_types{g});
    % Run Linear Transport Examples
    data = transdata;
    data.Neutronics.FEMDegree = 1;
    for i=1:length(linear_BFs)
        tBF = linear_BFs{i};
        if ~check_BF_geom_combo(tBF, geometry), continue; end
        for j=1:length(ep_log_vals)
            data = modify_transport_data(data, 10^(ep_log_vals(j)), tBF);
            [data, geometry] = process_input_data(data, geometry);
            data = cleanup_neutronics_input_data(data, geometry);
            [data, sol, geometry, DoF, FE] = execute_problem(data, geometry);
            print_output([out_dir,'/Transport'],data,geometry,DoF,FE,sol.flux,geom_types{g},ep_log_vals(j));
        end
    end
    % Run Quadratic Transport Examples
    data = transdata;
    data.Neutronics.FEMDegree = 2;
    for i=1:length(quadratic_BFs)
        tBF = quadratic_BFs{i};
        if ~check_BF_geom_combo(tBF, geometry), continue; end
        for j=1:length(ep_log_vals)
            data = modify_transport_data(data, 10^(ep_log_vals(j)), tBF);
            [data, geometry] = process_input_data(data, geometry);
            data = cleanup_neutronics_input_data(data, geometry);
            [data, sol, geometry, DoF, FE] = execute_problem(data, geometry);
             print_output([out_dir,'/Transport'],data,geometry,DoF,FE,sol.flux,geom_types{g},ep_log_vals(j));
        end
    end
    % Run Linear Diffusion Examples
    data = diffdata;
    data.Neutronics.FEMDegree = 1;
    for i=1:length(linear_BFs)
        tBF = linear_BFs{i};
        if ~check_BF_geom_combo(tBF, geometry), continue; end
        data = modify_diffusion_data(data, 1, tBF);
        [data, geometry] = process_input_data(data, geometry);
        data = cleanup_neutronics_input_data(data, geometry);
        [data, sol, geometry, DoF, FE] = execute_problem(data, geometry);
        print_output([out_dir,'/Diffusion'],data,geometry,DoF,FE,sol.flux,geom_types{g});
    end
    % Run Quadratic Diffusion Examples
    data = diffdata;
    data.Neutronics.FEMDegree = 2;
    for i=1:length(quadratic_BFs)
        tBF = quadratic_BFs{i};
        if ~check_BF_geom_combo(tBF, geometry), continue; end
        data = modify_diffusion_data(data, 1, tBF);
        [data, geometry] = process_input_data(data, geometry);
        data = cleanup_neutronics_input_data(data, geometry);
        [data, sol, geometry, DoF, FE] = execute_problem(data, geometry);
        print_output([out_dir,'/Diffusion'],data,geometry,DoF,FE,sol.flux,geom_types{g});
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function data = modify_transport_data(data, ep, BF)
data.Neutronics.SpatialMethod = BF;
data.Neutronics.Transport.ScatteringXS = zeros(1,1,1,1);
data.Neutronics.Transport.TotalXS = 1/ep;
data.Neutronics.Transport.AbsorbXS = ep;
data.Neutronics.Transport.ScatteringXS(1,:,:,:) = 1/ep-ep;
data.Neutronics.Transport.ExtSource = ep;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function data = modify_diffusion_data(data, ep, BF)
data.Neutronics.SpatialMethod = BF;
% data.Neutronics.Diffusion.ScatteringXS = zeros(1,1,1,1);
% data.Neutronics.Diffusion.TotalXS = ep;
% data.Neutronics.Diffusion.DiffXS = ep/3;
% data.Neutronics.Diffusion.AbsorbXS = 0;
% data.Neutronics.Diffusion.ScatteringXS(1,:,:,:) = 0;
% data.Neutronics.Diffusion.ExtSource = ep;
data.Neutronics.Diffusion.ScatteringXS = zeros(1,1,1,1);
data.Neutronics.Diffusion.TotalXS = 1;
data.Neutronics.Diffusion.DiffXS = 1/3;
data.Neutronics.Diffusion.AbsorbXS = 0;
data.Neutronics.Diffusion.ScatteringXS(1,:,:,:) = 0;
data.Neutronics.Diffusion.ExtSource = 1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function geometry = get_geometry(gtype)
global glob
if strcmpi(gtype, 'quad')
%     geometry = CartesianGeometry(2,linspace(0,1,11),linspace(0,1,11));
    geometry = CartesianGeometry(2,linspace(0,1,11),linspace(0,1,11));
elseif strcmpi(gtype, 'tri')
    tx = linspace(0,1,11);
    [x,y]=meshgrid(tx,tx);
    x=x(:);y=y(:);
    tri = delaunayTriangulation(x,y);
    geometry = GeneralGeometry(2, 'Delaunay', tri);
elseif strcmpi(gtype, 'smooth_poly')
    gname = 'smooth_poly_mesh_L1_n8_a0.15';
    load(strcat(glob.geom_path,gname,'.mat'));
elseif strcmpi(gtype, 'Sq_poly')
    gname = 'PolyMesh_SqDomain_L1_n256';
    load(strcat(glob.geom_path,gname,'.mat'));
elseif strcmpi(gtype, 'z-poly')
    gname = 'z_mesh_poly_L1_n9_a0.05';
    load(strcat(glob.geom_path,gname,'.mat'));
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out = check_BF_geom_combo(tBF, geometry)
gtype = geometry.MeshType;
if strcmpi(gtype, 'Quadrilateral') || strcmpi(gtype, 'Triangle')
    out = true;
else
    if strcmpi(tBF,'lagrange') || strcmpi(tBF,'serendipity')
        out = false;
    else
        out = true;
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function print_output(out_dir,data,mesh,DoF,FE,flux,gtype,ep_val)
% Check if output directories exist
if ~isequal(exist([out_dir,'/x-y'], 'dir'),7),mkdir([out_dir,'/x-y']); end
if ~isequal(exist([out_dir,'/isomorphic'], 'dir'),7),mkdir([out_dir,'/isomorphic']); end
close('all'); fclose('all');
% Get some output info
BF = data.Neutronics.SpatialMethod;
k  = data.Neutronics.FEMDegree;
if exist('ep_val','var')
    f_name = sprintf('%s_%s_k=%d_ep=1e%d',gtype,BF,k,ep_val);
else
    f_name = sprintf('%s_%s_k=%d',gtype,BF,k);
end
% Create x-y output
figure(1); H = gcf; ax = gca;
plot_solution(mesh,DoF,FE,flux{:});
colorbar();
xlabel('x-axis')
ylabel('y-axis')
caxis([0,0.25])
ax.XTick = [0,.2,.4,.6,.8,1];
ax.YTick = [0,.2,.4,.6,.8,1];
savefig(H,[out_dir,'/x-y/',f_name])
print(H,'-dpng',[out_dir,'/x-y/',f_name])
print(H,'-deps',[out_dir,'/x-y/',f_name])
% Create isomorphic output
figure(2); H = gcf; ax = gca;
plot_solution(mesh,DoF,FE,flux{:});
box on;
view([-48, 32]);
axis([0 1 0 1 0 1/4]);
xlabel('x-axis')
ylabel('y-axis')
caxis([0,0.25])
ax.XTick = [0,.2,.4,.6,.8,1];
ax.YTick = [0,.2,.4,.6,.8,1];
ax.ZTick = [0,.05,.1,.15,.2,.25];
set(ax,'XGrid','on','XMinorGrid','off');
set(ax,'YGrid','on','YMinorGrid','off');
set(ax,'ZGrid','on','ZMinorGrid','off');
savefig(gcf,[out_dir,'/isomorphic/',f_name])
print(H,'-dpng',[out_dir,'/isomorphic/',f_name])
print(H,'-deps',[out_dir,'/isomorphic/',f_name])
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%