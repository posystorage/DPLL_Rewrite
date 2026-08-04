function experiment = start_dpll_reference_only_2p2z(tag, options)
%START_DPLL_REFERENCE_ONLY_2P2Z Run the causal MATLAB-only 2P2Z experiment.

root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir);
if nargin < 1 || strlength(string(tag)) == 0
    tag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
end
if nargin < 2, options = struct(); end
output_dir = fullfile(root_dir, 'results', 'reference_only_2p2z', char(tag));
candidates = build_reference_only_2p2z_candidates();
experiment = run_reference_only_2p2z_experiment( ...
    candidates, string(output_dir), options);
end
