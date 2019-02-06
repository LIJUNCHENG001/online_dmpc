clc
clear all
close all
warning('off','all')

% Time settings and variables
T = 20; % Trajectory final time
h = 0.2; % time step duration
tk = 0:h:T;
K = T/h + 1; % number of time steps
Ts = 0.01; % period for interpolation @ 100Hz
t = 0:Ts:T; % interpolated time vector
k_hor = 15; % horizon length

% Variables for ellipsoid constraint
order = 2; % choose between 2 or 4 for the order of the super ellipsoid
rmin = 0.5; % X-Y protection radius for collisions
c = 1.5; % make this one for spherical constraint
E = diag([1,1,c]);
E1 = E^(-1);
E2 = E^(-order);

N = 4; % number of vehicles

% Workspace boundaries
pmin = [-2.5,-2.5,0.2];
pmax = [2.5,2.5,2.2];

% Minimum distance between vehicles in m
rmin_init = 0.75;

% Initial positions
% [po,pf] = randomTest(N,pmin,pmax,rmin_init);

% Initial positions
po1 = [1.501,1.5,1.5];
po2 = [-1.5,-1.5,1.5];
po3 = [-1.5,1.5,1.5];
po4 = [1.5,-1.5,1.5];
po = cat(3,po1,po2,po3,po4);

% Final positions
pf1 = [-1.5,-1.5,1.5];
pf2 = [1.5,1.5,1.5];
pf3 = [1.5,-1.5,1.5];
pf4 = [-1.5,1.5,1.5];
pf  = cat(3,pf1,pf2,pf3,pf4);

%% Set up the problem and call the solver

% Define model parameters for the quad + controller system
zeta_xy = 0.6502;
tau_xy = 0.3815;
omega_xy = 1/tau_xy;
zeta_z = 0.9103;
tau_z = 0.3;
omega_z = 1/tau_z;

% Matrices of the discrete state space model
% State = [x y z vx vy vz]
A = [1  0 0 h 0 0;
     0 1 0 0 h 0;
     0 0 1 0 0 h;
     -h*omega_xy^2 0 0 -2*omega_xy*h*zeta_xy 0 0;
     0 -h*omega_xy^2 0 0 -2*omega_xy*h*zeta_xy 0;
     0 0 -h*omega_xy^2 0 0 -2*omega_xy*h*zeta_xy];
 
B = [zeros(3,3);
     h*omega_xy^2 0 0;
     0 h*omega_xy^2 0;
     0 0 h*omega_z^2]; 
 
Lambda = getLambda(A,B,k_hor);
Lambda_K = Lambda(end-2:end,:); % to be used in the cost function

A0 = getA0(A,k_hor);
A0_K = A0(end-2:end,:);

% Matrices related to a Quartic Bezier curve

% Delta - converts control points into polynomial coefficients
delta = [1 0 0 0 0;
         -4 4 0 0 0 ;
         6 -12 6 0 0;
         -4 12 -12 4 0;
         1 -4 6 -4 4 ];
     
delta3d = augment_array_ndim(delta,3);

% Then we assemble a block-diagonal matrix based on the number of segments
% this matrix is used to compute the minimum snap cost function
l = 3; 
Beta = kron(eye(l),delta3d);

% Beta is also used to sample the Bezier curve at different times
% We will use it to minimize the error at the end of the curve, by sampling
% our curve at discrete time steps with length 'h'
T_segment = 0.8; % fixed time length of each Bezier segment
T_total = l*T_segment;
Tau = getTau(h,T_segment);
Tau3d = augment_array_ndim(Tau,3);

Gamma = kron(eye(l),Tau3d);

% Construct matrix Q: Hessian for each of the polynomial derivatives

cr = [0 0 0 0 1];
Q = getQ(4,T_segment,cr);
Q = sum(Q,3);

% This Q is only for one dimension, augment using our helper function
Q3d = augment_array_ndim(Q,3);

% Finally we compose the whole matrix as a block diagonal
Alpha = kron(eye(l),Q3d);
