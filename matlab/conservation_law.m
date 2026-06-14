%% conservation_law.m — SuperInstance Conservation Law in MATLAB/Octave
%
% γ + η = C  (Shannon chain rule: H(X) = I(X;G) + H(X|G))
%
% Usage (MATLAB):     conservation_law
% Usage (Octave):     octave conservation_law.m
%%

function conservation_law
  fprintf('═══ SuperInstance Conservation Law — MATLAB/Octave ═══\n\n');

  %% Monte Carlo Fleet Cancellation
  fprintf('─── Monte Carlo Fleet Cancellation ───\n');
  sizes = [5, 10, 50, 100, 500, 1000, 5000, 10000];
  for i = 1:length(sizes)
    n = sizes(i);
    tic;
    result = monte_carlo_cancellation(n, 10000);
    elapsed = toc;
    theory = conservation_efficiency(n);
    err = abs(result - theory) / theory * 100;
    fprintf('  n=%-6d  cancel=%.4f  theory=%.4f  error=%.2f%%  time=%.3fs\n', ...
            n, result, theory, err, elapsed);
  end

  %% Conservation Identity
  fprintf('\n─── Conservation Identity γ + η = C ───\n');
  rand('state', 42);
  n = 10000;
  G = ternary_signals(n);
  mask = rand(n, 1) < 0.5;
  X = mask .* G + (~mask) .* ternary_signals(n);
  X = sign(X) .* min(abs(X), 1);
  [gamma_val, eta_val, C_val] = conservation_analyze(X, G);
  fprintf('  γ = %.6f bits\n', gamma_val);
  fprintf('  η = %.6f bits\n', eta_val);
  fprintf('  C = %.6f bits\n', C_val);
  fprintf('  γ + η = %.6f bits\n', gamma_val + eta_val);
  fprintf('  H_max = log₂(3) = %.6f bits\n', log2(3));

  %% Haar Wavelet
  fprintf('\n─── Haar Wavelet Decomposition ───\n');
  signal = [1, 1, -1, 1, -1, -1, 1, -1];
  [approx, detail] = haar_decompose(signal);
  fprintf('  Signal: '); fprintf('%d ', signal); fprintf('\n');
  fprintf('  Approx: '); fprintf('%.3f ', approx); fprintf('\n');
  fprintf('  Detail: '); fprintf('%.3f ', detail); fprintf('\n');

  %% Throughput
  fprintf('\n─── Throughput Test ───\n');
  tic;
  result = monte_carlo_cancellation(100000, 100);
  elapsed = toc;
  fprintf('  100K agents × 100 trials: %.3fs (%.1fM sig/s)\n', ...
          elapsed, 100000 * 100 / elapsed / 1e6);

  fprintf('\n═══ Complete ═══\n');
end

%% ─── Core Functions ─────────────────────────────────────────────────

function signals = ternary_signals(n)
  u = rand(n, 1);
  signals = zeros(n, 1);
  signals(u < 1/3) = -1;
  signals(u >= 2/3) = 1;
end

function eff = conservation_efficiency(n)
  delta = (1 / sqrt(n)) * (1 - 3 / (2 * n));
  eff = 1 - delta;
end

function [gamma_val, eta_val, C_val] = conservation_analyze(X, G)
  n = length(X);
  C_val = ternary_entropy(X);
  H_G = ternary_entropy(G);
  joint = zeros(3, 3);
  for xi = 1:3
    for gi = 1:3
      xv = xi - 2; gv = gi - 2;
      joint(xi, gi) = sum((X == xv) & (G == gv)) / n;
    end
  end
  joint_nz = joint(joint > 0);
  H_XG = -sum(joint_nz .* log2(joint_nz));
  eta_val = max(0, H_XG - H_G);
  gamma_val = max(0, C_val - eta_val);
end

function H = ternary_entropy(signals)
  n = length(signals);
  counts = [sum(signals == -1), sum(signals == 0), sum(signals == 1)];
  p = counts / n;
  p = p(p > 0);
  H = -sum(p .* log2(p));
end

function cancel = monte_carlo_cancellation(fleet_size, n_trials)
  cancellations = zeros(n_trials, 1);
  for t = 1:n_trials
    signals = ternary_signals(fleet_size);
    cancellations(t) = 1 - abs(sum(signals)) / fleet_size;
  end
  cancel = mean(cancellations);
end

function [approx, detail] = haar_decompose(signal)
  n = length(signal);
  even = signal(1:2:n);
  odd = signal(2:2:n);
  approx = (even + odd) / sqrt(2);
  detail = (even - odd) / sqrt(2);
end
