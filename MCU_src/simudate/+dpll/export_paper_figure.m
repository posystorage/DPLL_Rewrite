function files = export_paper_figure( ...
    fig, base_path, size_inches, font_name, formats)
%EXPORT_PAPER_FIGURE Save consistent vector and high-resolution outputs.

if nargin < 3, size_inches = [7.2 6.2]; end
if nargin < 4, font_name = 'Arial'; end
if nargin < 5, formats = ["png", "pdf", "svg", "fig"]; end
formats = unique(lower(string(formats(:))), 'stable');
allowed_formats = ["png", "pdf", "svg", "fig"];
unsupported = setdiff(formats, allowed_formats);
if isempty(formats) || ~isempty(unsupported)
    error('dpll:InvalidFigureFormats', ...
        'formats must contain one or more of: png, pdf, svg, fig.');
end
base_path = char(base_path);
[folder, ~, ~] = fileparts(base_path);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end

set(fig, 'Color', 'w', 'Units', 'inches', ...
    'Position', [1 1 size_inches(1) size_inches(2)], 'Renderer', 'painters');
set(findall(fig, '-property', 'FontName'), 'FontName', font_name);
set(findall(fig, '-property', 'FontSize'), 'FontSize', 9);
set(findall(fig, 'Type', 'axes'), 'LineWidth', 0.75, ...
    'TickDir', 'out', 'Box', 'off');

files = struct();
if any(formats == "png")
    files.png = [base_path '.png'];
    exportgraphics(fig, files.png, 'Resolution', 600);
end
if any(formats == "pdf")
    files.pdf = [base_path '.pdf'];
    exportgraphics(fig, files.pdf, 'ContentType', 'vector');
end
if any(formats == "svg")
    files.svg = [base_path '.svg'];
    print(fig, files.svg, '-dsvg', '-vector');
end

% Figures are commonly rendered headlessly with Visible='off'. Persist an
% interactive FIG state while leaving the caller's live figure unchanged.
if any(formats == "fig")
    files.fig = [base_path '.fig'];
    original_visibility = fig.Visible;
    visibility_cleanup = onCleanup( ...
        @() set(fig, 'Visible', original_visibility));
    set(fig, 'Visible', 'on');
    savefig(fig, files.fig);
    clear visibility_cleanup
end
end
