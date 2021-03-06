%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Title:          Execution Functor - LHS DFEM Transport (hybrid)
%
%   Author:         Michael W. Hackemack
%   Institution:    Texas A&M University
%   Year:           2014
%   
%   Description:    
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function L = exec_func_LHS_dfem_transport_hybrid(data, mesh, DoF, FE, angs, groups)
% Process Input Space
% ------------------------------------------------------------------------------
global glob
dim = mesh.Dimension;
ndat = data.Transport;
ndof = DoF.TotalDoFs;
ng = length(groups);
na = length(angs);
ntot = ndof * ng * na;
angdirs = ndat.AngularDirections;
angnorm = ndat.AngQuadNorm;
q_offset = (1:na)*ndof - ndof;
g_offset = (1:ng)*ndof*na - ndof*na;
g0 = ndat.FluxStabilization;
d0 = ndat.CurrentStabilization;
diamD = mesh.Diameter;
% Allocate Memory Space
% ------------------------------------------------------------------------------
if ntot > glob.maxMatrix
    L = get_sparse_matrix(data, mesh, DoF, FE, angs, groups);
    return
end
L = zeros(ntot);
% Loop through cells
% ------------------------------------------------------------------------------
for c=1:mesh.TotalCells
    cmat = mesh.MatID(c);
    cnodes = DoF.ConnectivityArray{c};
    M = FE.CellMassMatrix{c};
    G = FE.CellGradientMatrix{c};
    % Loop through angles
    for q=1:na
        tq = angs(q);
        GG = cell_dot(dim, angdirs(tq, :), G);
        % Loop through energy groups
        for g=1:ng
            cnqg = cnodes + g_offset(g) + q_offset(q);
            L(cnqg,cnqg) = L(cnqg,cnqg) + ndat.TotalXS(cmat,g)*M + GG;
        end
        % Loop through angles again
        for qq=1:na
            sxs = ndat.ScatteringXS(cmat,1,1,1)*ndat.discrete_to_moment(qq);
            ccc = cnodes + q_offset(qq);
            L(cnqg,ccc) = L(cnqg,ccc) - sxs*M*ndat.moment_to_discrete(tq);
        end
    end
end
% Loop through boundary faces
% ------------------------------------------------------------------------------
for ff=1:mesh.TotalBoundaryFaces
    f = mesh.BoundaryFaces(ff);
    fflag = mesh.FaceID(f);
    fnorm = mesh.FaceNormal(f,:);
    fnodes = DoF.FaceCellNodes{f,1};
    tflag = ndat.BCFlags(fflag);
    M = FE.FaceMassMatrix{f,1};
    % Loop through angles
    for q=1:na
        tq = angs(q);
        fdot = fnorm * angdirs(tq,:)';
        if fdot > 0, continue; end
        % Loop through energy groups
        for g=1:ng
            fnqg = fnodes + g_offset(g) + q_offset(q);
            L(fnqg,fnqg) = L(fnqg,fnqg) - M*fdot;
            if tflag == glob.Reflecting
                rba = ndat.ReflectingBoundaryAngles{f}(q);
                fnqqg = fnodes + g_offset(g) + q_offset(rba);
                L(fnqg,fnqqg) = L(fnqg,fnqqg) + M*fdot;
            end
        end
    end
end
% Loop through interior faces
% ------------------------------------------------------------------------------
for ff=1:mesh.TotalInteriorFaces
    f = mesh.InteriorFaces(ff);
    fnorm = mesh.FaceNormal(f,:);
    fcells = mesh.FaceCells(f,:);
    % Loop through angles
    for q=1:na
        tq = angs(q);
        fdot = fnorm * angdirs(tq,:)'; afdot = abs(fdot);
        fnodes1 = DoF.FaceCellNodes{f,1}; c1 = fcells(1); m1 = mesh.MatID(c1);
        fnodes2 = DoF.FaceCellNodes{f,2}; c2 = fcells(2); m2 = mesh.MatID(c2);
        M = FE.FaceMassMatrix{f,1};
        MM = FE.FaceConformingMassMatrix{f,1};
        for g=1:ng
            grp = groups(g);
            fnqg1 = fnodes1 + g_offset(g) + q_offset(q);
            fnqg2 = fnodes2 + g_offset(g) + q_offset(q);
            if ndat.StabilizationType == 0
                gm = 1; gp = 1;
                dm = 0; dp = 0;
            elseif ndat.StabilizationType == 1
                sigs1 = ndat.ScatteringXS(m1,grp,grp,1);
                sigs2 = ndat.ScatteringXS(m2,grp,grp,1);
                gm = g0/max(g0,sigs1*diamD);
                gp = g0/max(g0,sigs2*diamD);
                dm = d0*(1-gm)/gm; dp = d0*(1-gp)/gp;
            elseif ndat.StabilizationType == 2
                sigs1 = ndat.ScatteringXS(m1,grp,grp,1);
                sigs2 = ndat.ScatteringXS(m2,grp,grp,1);
                h = mesh.OrthogonalProjection(f,:);
                gm = g0/max(g0,sigs1*h(1)); 
                gp = g0/max(g0,sigs2*h(2));
                dm = 0; dp = 0;
            elseif ndat.StabilizationType == 3
                sigs1 = ndat.ScatteringXS(m1,grp,grp,1);
                sigs2 = ndat.ScatteringXS(m2,grp,grp,1);
                h = mesh.OrthogonalProjection(f,:);
                gm = g0/max(g0,sigs1*h(1)); 
                gp = g0/max(g0,sigs2*h(2));
                dm = d0*(1-gm)/gm; dp = d0*(1-gp)/gp;
            end
            % ( [[u]] , [[b]] ) terms
            L(fnqg1,fnqg1) = L(fnqg1,fnqg1) + gm*afdot/2*M;  % (-,-)
            L(fnqg1,fnqg2) = L(fnqg1,fnqg2) - gp*afdot/2*MM; % (-,+)
            L(fnqg2,fnqg1) = L(fnqg2,fnqg1) - gm*afdot/2*MM; % (+,-)
            L(fnqg2,fnqg2) = L(fnqg2,fnqg2) + gp*afdot/2*M;  % (+,+)
            % ( {{un}} , {{b}} ) terms
            L(fnqg1,fnqg1) = L(fnqg1,fnqg1) - fdot/2*M;  % (-,-)
            L(fnqg1,fnqg2) = L(fnqg1,fnqg2) + fdot/2*MM; % (-,+)
            L(fnqg2,fnqg1) = L(fnqg2,fnqg1) - fdot/2*MM; % (+,-)
            L(fnqg2,fnqg2) = L(fnqg2,fnqg2) + fdot/2*M;  % (+,+)
            % ( {{Jun}} , {{Jbn}} ) terms
            for qq=1:na
                tqq = angs(qq);
                ffdot = fnorm * angdirs(tqq,:)';
                wt = ndat.AngularWeights(tqq);
                fnqqg1 = fnodes1 + g_offset(g) + q_offset(qq);
                fnqqg2 = fnodes2 + g_offset(g) + q_offset(qq);
                L(fnqg1,fnqqg1) = L(fnqg1,fnqqg1) + dm*fdot*ffdot*wt*M/angnorm;  % (-,-)
                L(fnqg1,fnqqg2) = L(fnqg1,fnqqg2) - dp*fdot*ffdot*wt*MM/angnorm; % (-,+)
                L(fnqg2,fnqqg1) = L(fnqg2,fnqqg1) - dm*fdot*ffdot*wt*MM/angnorm; % (+,-)
                L(fnqg2,fnqqg2) = L(fnqg2,fnqqg2) + dp*fdot*ffdot*wt*M/angnorm;  % (+,+)
            end
        end
    end
end
if ~issparse(L), L = sparse(L); end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function L = get_sparse_matrix(data, mesh, DoF, FE, angs, groups)
% Process Input Space
% ------------------------------------------------------------------------------
global glob
dim = mesh.Dimension;
ndat = data.Transport;
ndof = DoF.TotalDoFs;
ng = length(groups);
na = length(angs);
ntot = ndof * ng * na;
angdirs = ndat.AngularDirections;
angnorm = ndat.AngQuadNorm;
q_offset = (1:na)*ndof - ndof;
g_offset = (1:ng)*ndof*na - ndof*na;
g0 = ndat.FluxStabilization;
d0 = ndat.CurrentStabilization;
diamD = mesh.Diameter;
% Allocate Memory Space
% ------------------------------------------------------------------------------
I = [];
J = [];
TMAT = [];
% Loop through cells
% ------------------------------------------------------------------------------
for c=1:mesh.TotalCells
    cmat = mesh.MatID(c);
    cnodes = DoF.ConnectivityArray{c}; ncnodes = length(cnodes);
    onesnodes = ones(ncnodes,1);
    M = FE.CellMassMatrix{c};
    G = FE.CellGradientMatrix{c};
    % Loop through angles
    for q=1:na
        tq = angs(q);
        GG = cell_dot(dim, angdirs(tq, :), G);
        % Loop through energy groups
        for g=1:ng
            % Get Indexing Information
            % ------------------------------------------------------------------
            cnqg = cnodes + g_offset(g) + q_offset(q);
            rows = (onesnodes*cnqg)';
            cols = onesnodes*cnqg;
            % Apply Sparse Indexing
            % ------------------------------------------------------------------
            tmat = ndat.TotalXS(cmat,g)*M + GG;
            I = [I;rows(:)];
            J = [J;cols(:)];
            TMAT = [TMAT;tmat(:)];
        end
        % Loop through angle again
        for qq=1:na
            tq = angs(qq);
            ccc = cnodes + q_offset(qq);
            cols2 = onesnodes*ccc;
            I = [I;rows(:)];
            J = [J;cols2(:)];
            tmat = -ndat.ScatteringXS(cmat,1,1,1)*ndat.discrete_to_moment(tq)*M*ndat.moment_to_discrete(tq);
            TMAT = [TMAT;tmat(:)];
        end
    end
end
% Loop through boundary faces
% ------------------------------------------------------------------------------
for ff=1:mesh.TotalBoundaryFaces
    f = mesh.BoundaryFaces(ff);
    fflag = mesh.FaceID(f);
    fnorm = mesh.FaceNormal(f,:);
    fnodes = DoF.FaceCellNodes{f,1};
    tflag = ndat.BCFlags(fflag);
    M = FE.FaceMassMatrix{f,1};
    % Loop through angles
    for q=1:na
        tq = angs(q);
        fdot = fnorm * angdirs(tq,:)';
        if fdot > 0, continue; end
        % Loop through energy groups
        for g=1:ng
            fnqg = fnodes + g_offset(g) + q_offset(q);
            cols = onesnodes*fnqg; rows = (onesnodes*fnqg)'; tmat = -fdot*M;
            I = [I;rows(:)]; J = [J;cols(:)]; TMAT = [TMAT;tmat(:)];
            if tflag == glob.Reflecting
                rba = ndat.ReflectingBoundaryAngles{f}(q);
                fnqqg = fnodes + g_offset(g) + q_offset(rba);
                cols = onesnodes*fnqqg; rows = (onesnodes*fnqg)'; tmat = fdot*M;
                I = [I;rows(:)]; J = [J;cols(:)]; TMAT = [TMAT;tmat(:)];
            end
        end
    end
end
% Loop through interior faces
% ------------------------------------------------------------------------------
for ff=1:mesh.TotalInteriorFaces
    f = mesh.InteriorFaces(ff);
    fnorm = mesh.FaceNormal(f,:);
    fcells = mesh.FaceCells(f,:);
    % Loop through angles
    for q=1:na
        tq = angs(q);
        fdot = fnorm * angdirs(tq,:)'; afdot = abs(fdot);
        fnodes1 = DoF.FaceCellNodes{f,1}; c1 = fcells(1); m1 = mesh.MatID(c1);
        fnodes2 = DoF.FaceCellNodes{f,2}; c2 = fcells(2); m2 = mesh.MatID(c2);
        M = FE.FaceMassMatrix{f,1};
        MM = FE.FaceConformingMassMatrix{f,1};
        for g=1:ng
            grp = groups(g);
            fnqg1 = fnodes1 + g_offset(g) + q_offset(q);
            fnqg2 = fnodes2 + g_offset(g) + q_offset(q);
            if ndat.StabilizationType == 0
                gm = 1; gp = 1;
                dm = 0; dp = 0;
            elseif ndat.StabilizationType == 1
                sigs1 = ndat.ScatteringXS(m1,grp,grp,1);
                sigs2 = ndat.ScatteringXS(m2,grp,grp,1);
                gm = g0/max(g0,sigs1*diamD);
                gp = g0/max(g0,sigs2*diamD);
                dm = d0*(1-gm)/gm; dp = d0*(1-gp)/gp;
            elseif ndat.StabilizationType == 2
                sigs1 = ndat.ScatteringXS(m1,grp,grp,1);
                sigs2 = ndat.ScatteringXS(m2,grp,grp,1);
                h = mesh.OrthogonalProjection(f,:);
                gm = g0/max(g0,sigs1*h(1)); 
                gp = g0/max(g0,sigs2*h(2));
                dm = 0; dp = 0;
            elseif ndat.StabilizationType == 3
                sigs1 = ndat.ScatteringXS(m1,grp,grp,1);
                sigs2 = ndat.ScatteringXS(m2,grp,grp,1);
                h = mesh.OrthogonalProjection(f,:);
                gm = g0/max(g0,sigs1*h(1)); 
                gp = g0/max(g0,sigs2*h(2));
                dm = d0*(1-gm)/gm; dp = d0*(1-gp)/gp;
            end
            cols1 = onesnodes*fnqg1; rows1 = (onesnodes*fnqg1)';
            cols2 = onesnodes*fnqg2; rows2 = (onesnodes*fnqg2)';
            % ( [[u]] , [[b]] ) terms
%             I = [I;rows1(:)]; J = [J;cols1(:)]; TMAT = [TMAT;gm*afdot/2*M(:)];
%             I = [I;rows1(:)]; J = [J;cols2(:)]; TMAT = [TMAT;-gp*afdot/2*MM(:)];
%             I = [I;rows2(:)]; J = [J;cols1(:)]; TMAT = [TMAT;-gm*afdot/2*MM(:)];
%             I = [I;rows2(:)]; J = [J;cols2(:)]; TMAT = [TMAT;gp*afdot/2*M(:)];
%             L(fnqg1,fnqg1) = L(fnqg1,fnqg1) + gm*afdot/2*M;  % (-,-)
%             L(fnqg1,fnqg2) = L(fnqg1,fnqg2) - gp*afdot/2*MM; % (-,+)
%             L(fnqg2,fnqg1) = L(fnqg2,fnqg1) - gm*afdot/2*MM; % (+,-)
%             L(fnqg2,fnqg2) = L(fnqg2,fnqg2) + gp*afdot/2*M;  % (+,+)
            % ( {{un}} , {{b}} ) terms
%             I = [I;rows1(:)]; J = [J;cols1(:)]; TMAT = [TMAT;-fdot/2*M(:)];
%             I = [I;rows1(:)]; J = [J;cols2(:)]; TMAT = [TMAT;fdot/2*MM(:)];
%             I = [I;rows2(:)]; J = [J;cols1(:)]; TMAT = [TMAT;-fdot/2*MM(:)];
%             I = [I;rows2(:)]; J = [J;cols2(:)]; TMAT = [TMAT;fdot/2*M(:)];
%             L(fnqg1,fnqg1) = L(fnqg1,fnqg1) - fdot/2*M;  % (-,-)
%             L(fnqg1,fnqg2) = L(fnqg1,fnqg2) + fdot/2*MM; % (-,+)
%             L(fnqg2,fnqg1) = L(fnqg2,fnqg1) - fdot/2*MM; % (+,-)
%             L(fnqg2,fnqg2) = L(fnqg2,fnqg2) + fdot/2*M;  % (+,+)
            I = [I;rows1(:)]; J = [J;cols1(:)]; TMAT = [TMAT;gm*afdot/2*M(:)-fdot/2*M(:)];
            I = [I;rows1(:)]; J = [J;cols2(:)]; TMAT = [TMAT;-gp*afdot/2*MM(:)+fdot/2*MM(:)];
            I = [I;rows2(:)]; J = [J;cols1(:)]; TMAT = [TMAT;-gm*afdot/2*MM(:)-fdot/2*MM(:)];
            I = [I;rows2(:)]; J = [J;cols2(:)]; TMAT = [TMAT;gp*afdot/2*M(:)+fdot/2*M(:)];
            % ( {{Jun}} , {{Jbn}} ) terms
            for qq=1:na
                tqq = angs(qq);
                ffdot = fnorm * angdirs(tqq,:)';
                wt = ndat.AngularWeights(tqq);
                fnqqg1 = fnodes1 + g_offset(g) + q_offset(qq);
                fnqqg2 = fnodes2 + g_offset(g) + q_offset(qq);
                tcols1 = onesnodes*fnqqg1;
                tcols2 = onesnodes*fnqqg2;
                I = [I;rows1(:)]; J = [J;tcols1(:)]; TMAT = [TMAT;dm*fdot*ffdot*wt/angnorm*M(:)];
                I = [I;rows1(:)]; J = [J;tcols2(:)]; TMAT = [TMAT;-dp*fdot*ffdot*wt/angnorm*MM(:)];
                I = [I;rows2(:)]; J = [J;tcols1(:)]; TMAT = [TMAT;-dm*fdot*ffdot*wt/angnorm*MM(:)];
                I = [I;rows2(:)]; J = [J;tcols2(:)]; TMAT = [TMAT;dp*fdot*ffdot*wt/angnorm*M(:)];
%                 L(fnqg1,fnqqg1) = L(fnqg1,fnqqg1) + dm*fdot*ffdot*wt*M/angnorm;  % (-,-)
%                 L(fnqg1,fnqqg2) = L(fnqg1,fnqqg2) - dp*fdot*ffdot*wt*MM/angnorm; % (-,+)
%                 L(fnqg2,fnqqg1) = L(fnqg2,fnqqg1) - dm*fdot*ffdot*wt*MM/angnorm; % (+,-)
%                 L(fnqg2,fnqqg2) = L(fnqg2,fnqqg2) + dp*fdot*ffdot*wt*M/angnorm;  % (+,+)
            end
        end
    end
end
% Form Sparse Matrix
% ------------------------------------------------------------------------------
L = sparse(I,J,TMAT,ntot,ntot);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out = cell_dot(dim, vec1, vec2)
if dim == 1
    out = vec1*vec2{1};
elseif dim == 2
    out = vec1(1)*vec2{1} + vec1(2)*vec2{2};
else
    out = vec1(1)*vec2{1} + vec1(2)*vec2{2} + vec1(3)*vec2{3};
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%