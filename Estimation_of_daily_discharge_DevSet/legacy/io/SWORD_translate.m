function out = SWORD_translate(input_id,sword_version_in)
% SWORD_TRANSLATE  Translate SWORD v16 ID (reach/node) to v17b using official mapping files.
%
%   out = SWORD_translate(input_id)
%   out = sword_translate(input_id, sword_version_in)
%
%   sword_version_in (optional): 'v16' or 'v17b'
%   If sword_version_in is not provided, the function will auto-detect.
% 
%   Automatically:
%     - Detects continent (from first digit)
%     - Detects feature type (reach or node)
%     - Loads correct mapping file (e.g. AF_NodeIDs_v17b_vs_v16.csv)
%     - Extracts corresponding v17b ID and metadata
%
% -----------------------------------------------------------------------
%  Originally written by: 
%             Peyman Saemian, GIS, University of Stuttgart
% -----------------------------------------------------------------------
% =======================================================================

%% 1. Input normalization
if nargin < 1
    error('You must provide an input ID (reach or node).');
elseif nargin < 2
    sword_version_in = 'auto';
else
    sword_version_in = lower(strtrim(sword_version_in));
    if ~ismember(sword_version_in, {'v16', 'v17b'})
        error('Invalid version input. Use ''v16'' or ''v17b''.');
    end
end

if ischar(input_id) || isstring(input_id)
    idStr = char(input_id);
    idNum = str2double(idStr);
elseif isnumeric(input_id)
    idNum = input_id;
    idStr = sprintf('%.0f', input_id);
else
    error('Unsupported input type.');
end

if isnan(idNum)
    error('Invalid input ID: cannot convert to numeric.');
end

if ~all(isstrprop(idStr,'digit'))
    error('Input ID must contain only digits. Got: %s', idStr);
end

%% 2. Detect type
nDigits = numel(idStr);
if nDigits == 11
    typeStr = 'Reach';
    v16col = 'v16_reach_id';
    v17col = 'v17_reach_id';
elseif nDigits == 14
    typeStr = 'Node';
    v16col = 'v16_node_id';
    v17col = 'v17_node_id';
else
    error('Unexpected ID length (%d). Expected 11 (reach) or 14 (node).', nDigits);
end

%% 3. Decode continent
[firstDigit, contShort, contLong] = local_decode_continent(idStr(1));

%% 4. Path to mapping folder
addpath(fullfile(pwd, '..', 'SWORD V16'));
baseDir = 'SWORD V16';
mapFile = fullfile(pwd, '..', baseDir, sprintf('%s_%sIDs_v17b_vs_v16.csv', contShort, typeStr));

if ~isfile(mapFile)
    error('Mapping file not found:\n%s', mapFile);
end

%% 5. Load and clean table (cached for speed)
persistent cache
if isempty(cache)
    cache = struct();
end
key = [contShort '_' typeStr];
if isfield(cache, key)
    T = cache.(key);
else
    opts = detectImportOptions(mapFile, 'NumHeaderLines', 0);
    opts.VariableNamingRule = 'preserve';
    T = readtable(mapFile, opts);
    % Clean column names: lowercase + replace spaces with underscores
    T.Properties.VariableNames = lower(strrep(T.Properties.VariableNames, ' ', '_'));
    cache.(key) = T;
end

%% 6. Ensure columns exist
if ~ismember(v16col, T.Properties.VariableNames)
    error('Column "%s" not found in %s', v16col, mapFile);
end
if ~ismember(v17col, T.Properties.VariableNames)
    error('Column "%s" not found in %s', v17col, mapFile);
end

%% 7. Find mapping based on version or auto-detect (robust)
idx_v16 = [];
idx_v17 = [];

if strcmp(sword_version_in, 'v16')
    idx_v16 = find(T.(v16col) == idNum, 1);
elseif strcmp(sword_version_in, 'v17b')
    idx_v17 = find(T.(v17col) == idNum, 1);
else
    % Auto mode: check both sides
    idx_v16 = find(T.(v16col) == idNum, 1);
    idx_v17 = find(T.(v17col) == idNum, 1);

    % Handle ambiguity: ID found in both columns
    if ~isempty(idx_v16) && ~isempty(idx_v17)
        warning(['ID %s found in BOTH v16 and v17b columns.\n' ...
                 'Returning both possible mappings in output.'], idStr);
    end
end

% --- Determine mapping direction(s)
if ~isempty(idx_v16) && isempty(idx_v17)
    sword_version_in = 'v16';
    mapped_ids = T.(v17col)(idx_v16);
    row = table2struct(T(idx_v16,:));
elseif isempty(idx_v16) && ~isempty(idx_v17)
    sword_version_in = 'v17b';
    mapped_ids = T.(v16col)(idx_v17);
    row = table2struct(T(idx_v17,:));
elseif ~isempty(idx_v16) && ~isempty(idx_v17)
    % Ambiguous case: found in both versions
    sword_version_in = 'ambiguous';
    mapped_ids = struct( ...
        'as_v16', T.(v17col)(idx_v16), ...
        'as_v17b', T.(v16col)(idx_v17));
    row = struct(); % metadata skipped for simplicity
else
    % warning('No match found for ID %s in mapping file.', idStr);
    mapped_ids = NaN;
    row = struct();
    sword_version_in = 'unknown';
end

%% 8. Extract optional metadata safely
if isstruct(mapped_ids)
    % Ambiguous case: skip row-based metadata
    shift_flag            = NaN;
    boundary_flag         = NaN;
    boundary_percent      = NaN;
    dominant_reach        = NaN;
    v16_number_of_reaches = NaN;
else
    shift_flag            = getFieldSafe(row, 'shift_flag', NaN);
    boundary_flag         = getFieldSafe(row, 'boundary_flag', NaN);
    boundary_percent      = getFieldSafe(row, 'boundary_percent', NaN);
    dominant_reach        = getFieldSafe(row, 'dominant_reach', NaN);
    v16_number_of_reaches = getFieldSafe(row, 'v16_number_of_reaches', NaN);
end

%% 9. Build consistent output struct
if isstruct(mapped_ids)
    % Ambiguous: found in both v16 and v17b
    v16_id  = idNum;
    v17b_id = idNum; % same ID exists in both
    mapped_v16  = mapped_ids.as_v17b; % mapping from v17b → v16
    mapped_v17b = mapped_ids.as_v16;  % mapping from v16 → v17b
else
    % Regular one-direction mapping
    if strcmp(sword_version_in,'v16')
        % input = v16 → mapped to v17b
        v16_id  = idNum;
        v17b_id = mapped_ids;
        mapped_v16  = NaN;            % no need to map v17b → v16
        mapped_v17b = mapped_ids;     % v16 → v17b
    elseif strcmp(sword_version_in,'v17b')
        % input = v17b → mapped to v16
        v16_id  = mapped_ids;
        v17b_id = idNum;
        mapped_v16  = mapped_ids;     % v17b → v16
        mapped_v17b = NaN;            % no need to map v16 → v17b
    else
        v16_id  = NaN;
        v17b_id = NaN;
        mapped_v16  = NaN;
        mapped_v17b = NaN;
    end
end
out = struct( ...
    'input_id',              idNum, ...
    'sword_version_in',            sword_version_in, ...
    'type',                  lower(typeStr), ...
    'continent',             contShort, ...
    'v16_id',                v16_id, ...
    'v17b_id',               v17b_id, ...
    'mapped_v16',            mapped_v16, ...
    'mapped_v17b',           mapped_v17b, ...
    'shift_flag',            shift_flag, ...
    'boundary_flag',         boundary_flag, ...
    'boundary_percent',      boundary_percent, ...
    'dominant_reach',        dominant_reach, ...
    'v16_number_of_reaches', v16_number_of_reaches ...
);

% Smart printout
if isstruct(mapped_ids)
    fprintf(['⚠️ ID %s appears in BOTH versions.\n' ...
             '   → as v16 → v17b = %s\n' ...
             '   → as v17b → v16 = %s\n'], ...
             idStr, num2str(mapped_ids.as_v16), num2str(mapped_ids.as_v17b));
else
    % fprintf('ID: %s | Type: %-5s | Continent: %s | Version: %s → Mapped ID: %s\n', ...
    %     idStr, lower(typeStr), contShort, sword_version_in, num2str(mapped_ids));
end

end


%% ======================================================================
function [firstDigit, contShort, contLong] = local_decode_continent(c)
firstDigit = str2double(c);
switch firstDigit
    case 1, contShort='AF'; contLong='Africa';
    case 2, contShort='EU'; contLong='Europe';
    case 3, contShort='SI'; contLong='Siberia';
    case 4, contShort='AS'; contLong='Asia';
    case 5, contShort='OC'; contLong='Oceania';
    case 6, contShort='SA'; contLong='SouthAmerica';
    case 7, contShort='NA'; contLong='NorthAmerica';
    case 8, contShort='NA'; contLong='Arctic';
    case 9, contShort='NA'; contLong='Greenland';
    otherwise, contShort='UN'; contLong='Unknown';
end
end

%% ======================================================================
function val = getFieldSafe(S, fname, defaultVal)
if nargin < 3, defaultVal = NaN; end
if isempty(S) || ~isstruct(S)
    val = defaultVal; return;
end
fn = fieldnames(S);
match = strcmpi(fn, fname);
if any(match)
    val = S.(fn{match});
else
    val = defaultVal;
end
end
