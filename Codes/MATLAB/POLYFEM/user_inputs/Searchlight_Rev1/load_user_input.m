function [data, geometry] = load_user_input(dat_in, geom_in)
global glob
% Problem Input Parameters
% ------------------------------------------------------------------------------
data.problem.Path = 'Transport/Searchlight';
data.problem.Name = geom_in.GeometryType;
data.problem.NumberMaterials = 1;
data.problem.problemType = 'SourceDriven';
data.problem.plotSolution = 0;
data.problem.saveSolution = 1;
data.problem.saveVTKSolution = 1;
% AMR Input Parameters
% ------------------------------------------------------------------------------
data.problem.refineMesh = 1;
data.problem.refinementLevels = dat_in.lvls;
data.problem.refinementTolerance = dat_in.tol;
data.problem.AMRIrregularity = dat_in.irr;
data.problem.projectSolution = 0;
data.problem.refinementType = 0; % 0 = err(c)/maxerr < c, 1 = numc/totalCells = c
% Neutronics Data
% ------------------------------------------------------------------------------
data.Neutronics.PowerLevel = 1.0;
data.Neutronics.StartingSolution = 'zero';
data.Neutronics.transportMethod = 'Transport';
data.Neutronics.FEMType = 'DFEM';
data.Neutronics.SpatialMethod = 'PWLD';
data.Neutronics.FEMDegree = 1;
data.Neutronics.FEMLumping = false;
data.Neutronics.numberEnergyGroups = 1;

% Transport Properties
% ------------------------------------------------------------------------------
% Flux/Angle Properties
data.Neutronics.Transport.PnOrder = 0;
data.Neutronics.Transport.AngleAggregation = 'single';
data.Neutronics.Transport.QuadType = 'manual';
data.Neutronics.Transport.SnLevels = 4;
data.Neutronics.Transport.PolarLevels = 4;
data.Neutronics.Transport.AzimuthalLevels = 4;
data.Neutronics.Transport.QuadAngles  = [1,.4]/norm([1,.4]);  % Angles for manual set
% data.Neutronics.Transport.QuadAngles  = [1,0]/norm([1,0]);  % Angles for manual set
data.Neutronics.Transport.QuadWeights = [1];                  % Weights for manual set
% Sweep Operations
data.Neutronics.Transport.performSweeps = 0;
data.Neutronics.Transport.visualizeSweeping = 0;
% Tranpsort Type Properties - most of this only applies to hybrid transport
data.Neutronics.Transport.transportType = 'upwind';
data.Neutronics.Transport.StabilizationMethod = 'EGDG';
data.Neutronics.Transport.FluxStabilization = 2.0;
data.Neutronics.Transport.CurrentStabilization = 1.0;
% Physical Properties
txs = 0.0; c = 0.0;
data.Neutronics.Transport.ScatteringXS = zeros(1,1,1,1);
data.Neutronics.Transport.TotalXS = [txs];
data.Neutronics.Transport.AbsorbXS = (1-c)*data.Neutronics.Transport.TotalXS;
data.Neutronics.Transport.ScatteringXS(1,:,:,:) = c*data.Neutronics.Transport.TotalXS;
data.Neutronics.Transport.FissionXS = [0.0];
data.Neutronics.Transport.NuBar = [0.0];
data.Neutronics.Transport.FissSpec = [0.0];
data.Neutronics.Transport.ExtSource = [0.0];
% Boundary Conditions
data.Neutronics.Transport.BCFlags = [glob.Vacuum; glob.IncidentBeam];
data.Neutronics.Transport.BCVals = {0.0; 0.515};

% DSA Properties
% ------------------------------------------------------------------------------
data.Neutronics.Transport.performDSA = 0;
data.Neutronics.Transport.DSAType = 'MIP';
data.Neutronics.Transport.DSASolveMethod = 'direct';
data.Neutronics.Transport.DSAPreconditioner = 'Jacobi';
data.Neutronics.Transport.DSATolerance = 1e-4;
data.Neutronics.Transport.DSAMaxIterations = 1e4;
data.Neutronics.IP_Constant = 4;

% Solver Input Parameters
% ------------------------------------------------------------------------------
data.solver.absoluteTolerance = 1e-6;
data.solver.relativeTolerance = 1e-6;
data.solver.maxIterations = 10000;
data.solver.performNKA = 0;
data.solver.kyrlovSubspace = [];

% Geometry Data
% ------------------------------------------------------------------------------
data.problem.Dimension = geom_in.Dimension;
[data,geometry] = load_geometry_input(data, geom_in);
% Set Boundary Flags
geometry.set_face_flag_on_surface(2,[0,.2*geom_in.Ly;0,.4*geom_in.Ly]);
