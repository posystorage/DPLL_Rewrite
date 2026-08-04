function files = export_paper_figure(fig, base_path, size_inches, font_name)
%EXPORT_PAPER_FIGURE Save consistent vector and high-resolution outputs.

if nargin < 3, size_inches = [7.2 6.2]; end
if nargin < 4, font_name = 'Arial'; end
base_path = char(base_path);
[folder, ~, ~] = fileparts(base_path);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end

set(fig, 'Color', 'w', 'Units', 'inches', ...
    'Position', [1 1 size_inches(1) size_inches(2)], 'Renderer', 'painters');
set(findall(fig, '-property', 'FontName'), 'FontName', font_name);
set(findall(fig, '-property', 'FontSize'), 'FontSize', 9);
set(findall(fig, 'Type', 'axes'), 'LineWidth', 0.75, ...
    'TickDir', 'out', 'Box', 'off');

files.png = [base_path '.png'];
files.pdf = [base_path '.pdf'];
files.svg = [base_path '.svg'];
files.fig = [base_path '.fig'];
exportgraphics(fig, files.png, 'Resolution', 600);
exportgraphics(fig, files.pdf, 'ContentType', 'vector');
print(fig, files.svg, '-dsvg', '-vector');
savefig(fig, files.fig);
end
