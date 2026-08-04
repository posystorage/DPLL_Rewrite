function hash = file_sha256(file_path)
%FILE_SHA256 Calculate a source-file checksum for experiment provenance.

escaped = strrep(char(file_path), '''', '''''');
command = sprintf(['powershell -NoProfile -Command "' ...
    '(Get-FileHash -Algorithm SHA256 -LiteralPath ''%s'').Hash"'], escaped);
[status, output] = system(command);
if status ~= 0
    warning('dpll:HashFailed', 'Could not hash source file: %s', file_path);
    hash = '';
else
    hash = lower(strtrim(output));
end
end
