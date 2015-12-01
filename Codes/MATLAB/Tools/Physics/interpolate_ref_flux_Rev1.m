%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Title:          Interpolate Refinement Solution (Rev1)
%
%   Author:         Michael W. Hackemack
%   Institution:    Texas A&M University
%   Year:           2015
%
%   Description:    MATLAB function to interpolate a flux solution from a
%                   coarser mesh onto a finer mesh only.
%                   
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Notes:          The interpolation is performed 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function flux = interpolate_ref_flux_Rev1(mesh, dof1, dof2, fe, flux0)
% Exit if not 2D - all these issues may be fixed at a later date.
if mesh.Dimension ~= 2, error('Can only interpolate solution in 2D.'); end
bf_func = fe.get_basis_eval_func();
fe_deg = fe.Degree;
% Build outgoing flux structure
[ng, nm] = size(flux0);
flux = cell(ng, nm); ndof = dof2.TotalDoFs;
for g=1:ng
    for m=1:nm
        flux(g,m) = zeros(ndof,1);
    end
end
% Loop through refined mesh cells
for c=1:mesh.TotalCells
    % Continue if mesh cell was not refined
    if ~mesh.CellRefinedLastCycle(c)
        cdofs1 = dof1.ConnectivityArray{c};
        cdofs2 = dof2.ConnectivityArray{c};
        % Loop through energy groups and moments
        for g=1:ng
            for m=1:nm
                flux{g,m}(cdofs2) = flux0{g,m}(cdofs1);
            end
        end
        continue
    end
    % Get degree of freedom information between refinements
    c0 = mesh.PreviousCell(c);
    cdofs1 = dof1.ConnectivityArray{c0}; ncdofs1 = length(cdofs1);
    cdofs2 = dof2.ConnectivityArray{c};  ncdofs2 = length(cdofs2);
    cvd1 = dof1.CellVertexNodes{c0}; ncvd1 = length(cvd1);
    f = get_2D_face_vertex_ordering(ncvd1);
    nodes1 = dof1.NodeLocations(cdofs1,:);
    nodes2 = dof1.NodeLocations(cdofs2,:);
    % Get basis function values and interpolate
    b = bf_func(nodes1, nodes2, f, fe_deg, ncvd1);
    for g=1:ng
        for m=1:nm
            flux{g,m}(cdofs2) = b*flux0{g,m}(cdofs1);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function Listing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out = get_2D_face_vertex_ordering(nv)
out = cell(nv,1);
for f=1:nv
    out{f} = [f,mod(f,nv)+1];
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%