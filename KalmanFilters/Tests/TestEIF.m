scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '../'));
addpath(fullfile(scriptDir, '../MotionModels'));
addpath(fullfile(scriptDir, '../MeasurementModels'));

%% Create motion model
ts = 0.01;
[f, Fx, Fu, Fq] = CoordinatedTurnModel_Discrete(ts);

% x = [ x, y, v, phi, omega ]
x0 = [ 0.2, 0, 0.5, deg2rad(25), deg2rad(45) ]';
u0 = zeros(size(Fu(zeros(99,1),zeros(99,1),zeros(99,1)),2),1);
q0 = zeros(size(Fq(zeros(99,1),zeros(99,1),zeros(99,1)),2),1);

% Define process covariance
sigma_q_v = 0.00001;
sigma_q_omega = 0.000001; 
Q = diag([sigma_q_v^2, sigma_q_omega^2]);

Qsim = Q;
model = DiscreteMotionModelHandler(f, x0, Qsim);

%% Create measurement model
[h, Hx, Hr] = PositionSensor2D(1,2); % specify where in the state vector that (x,y) is located

% z = [ z_x, z_y ]
r0 = zeros(size(Hr(zeros(99,1),zeros(99,1)),2),1);

% Define measurement covariance
sigma_r_x = 0.005;
sigma_r_y = 0.005; 
R = diag([sigma_r_x^2, sigma_r_y^2]);

meas = MeasurementModelHandler(h, R);

%% Initialize Kalman filter
kf = EIF;

% Define initial process covariance
% x = [ x, y, v, phi, omega ]
sigma_xy = 1;
sigma_v = 1;
sigma_phi = 0.1*pi;
sigma_omega = 1;
P0 = diag([sigma_xy^2, sigma_xy^2, sigma_v^2, sigma_phi^2, sigma_omega^2]);

x0 = [ x0(1), x0(2), 0.1, deg2rad(45), deg2rad(10) ]';
%x0 = zeros(size(x0));
kf = kf.init_discrete_jacobians(...
                                f, Fx, Fu, Fq, Q, ...  % process model
                                h, Hx, Hr, R, ...  % measurement model
                                x0, P0);         
     
% OBS! Something seems to be wrong with the CoordinatedTurnModel Jacobian                            
                            
kf2 = kf.init_discrete(...
                                f, Q, ...  % process model
                                h, R, ...  % measurement model
                                x0, P0);                               
                

time = 0;                    
true = x0';
[x, P] = kf.getEstimate();
pred = x';
est = x';
measurements = x0(1:2)';
variance = [P(1,1), P(2,2), P(3,3), P(4,4), P(5,5)];
for (i = 1:300)    
    time(end+1,1) = time(end,1) + ts;
    
    % Propagate model and store true position
    model = model.stepDeterministic();        
    true(end+1,:) = model.x';
    true(end,4) = mod(true(end,4), 2*pi);
    
    % Generate measurement
    z = meas.get(model.x);
    measurements(end+1,:) = z';
    
    % Kalman filter
    kf = kf.predict();        
    [x, P] = kf.getEstimate();
    pred(end+1,:) = x';
    if (mod(i, 25) == 0)
        kf = kf.update(z);
    end    
    [x, P] = kf.getEstimate();
    est(end+1,:) = x';        
    variance(end+1,:) = [P(1,1), P(2,2), P(3,3), P(4,4), P(5,5)];
        
    x(4) = mod(x(4), 2*pi);
    kf = kf.setState(x);
end

%%
figure(1);
clf;
pos = true(:,1:2);
i = 1:length(pos);
surface([pos(:,1)';pos(:,1)'],[pos(:,2)';pos(:,2)'],zeros(2,size(pos,1)),[i;i],...
        'facecol','no',...
        'edgecol','interp',...
        'linew',2);
grid on;   
hold on;
plot(measurements(:,1), measurements(:,2), 'r.');
plot(est(:,1), est(:,2), 'b--');
hold off;
axis equal;

figure(2);
clf;
subplot(5,1,1);
plot(time, true(:,1), time, pred(:,1), time, est(:,1));
title('x'); legend('True', 'Prediction', 'Corrected');
subplot(5,1,2);
plot(time, true(:,2), time, pred(:,2), time, est(:,2));
title('y'); legend('True', 'Prediction', 'Corrected');
subplot(5,1,3);
plot(time, true(:,3), time, pred(:,3), time, est(:,3));
title('v'); legend('True', 'Prediction', 'Corrected');
subplot(5,1,4);
plot(time, true(:,4), time, pred(:,4), time, est(:,4));
title('phi'); legend('True', 'Prediction', 'Corrected');
subplot(5,1,5);
plot(time, true(:,5), time, pred(:,5), time, est(:,5));
title('omega'); legend('True', 'Prediction', 'Corrected');

%%
figure(3);
clf;
subplot(5,1,1);
plot(time, true(:,1), time, est(:,1), time, est(:,1)+sqrt(variance(:,1)), '--', time, est(:,1)-sqrt(variance(:,1)), '--');
title('x'); legend('True', 'Estimate', '1 sigma', '-1 sigma');
subplot(5,1,2);
plot(time, true(:,2), time, est(:,2), time, est(:,2)+sqrt(variance(:,2)), '--', time, est(:,2)-sqrt(variance(:,2)), '--');
title('y'); legend('True', 'Estimate', '1 sigma', '-1 sigma');
subplot(5,1,3);
plot(time, true(:,3), time, est(:,3), time, est(:,3)+sqrt(variance(:,3)), '--', time, est(:,3)-sqrt(variance(:,3)), '--');
title('v'); legend('True', 'Estimate', '1 sigma', '-1 sigma');
subplot(5,1,4);
plot(time, true(:,4), time, est(:,4), time, est(:,4)+sqrt(variance(:,4)), '--', time, est(:,4)-sqrt(variance(:,4)), '--');
title('phi'); legend('True', 'Estimate', '1 sigma', '-1 sigma');
subplot(5,1,5);
plot(time, true(:,5), time, est(:,5), time, est(:,5)+sqrt(variance(:,5)), '--', time, est(:,5)-sqrt(variance(:,5)), '--');
title('omega'); legend('True', 'Estimate', '1 sigma', '-1 sigma');