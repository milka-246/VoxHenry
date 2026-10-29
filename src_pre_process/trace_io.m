function trace_io(mode, name, vars)
%%    Save the input and output data of every traced function call
% _________________________________________________________________________
%
%   trace_io('-start', outdir, maxcalls)  start saving into 'outdir'; at most
%                                         'maxcalls' calls per function are
%                                         saved (Inf = all)
%   trace_io('-stop')                     stop saving, close the index file
%   trace_io('in',  'func_name')          at the start of a function: save its
%                                         input arguments
%   trace_io('out', 'func_name')          before each exit of a function: save
%                                         its output arguments
%   trace_io('in'|'out', 'script', vars)  same for a script: 'vars' is the
%                                         cell array of variables to save
%
%   Each call gets an id (in call order). Its data go to
%   <outdir>/<id>_<func>_in.mat and <id>_<func>_out.mat (MATLAB v7 format),
%   and a line 'id parent in|out func vars' goes to <outdir>/io_index.txt
%   ('parent' is the id of the calling traced function, 0 for the main script).
%
%   Besides the arguments, the global variables declared in the function are
%   saved too (some functions only exchange data through globals).
%   Function handles are saved as a struct with their text and the variables
%   they captured, so the data hidden in a closure are visible as well.
%   A variable that does not exist (argument not passed, output not yet
%   assigned) is listed in 'trace_missing' instead.
%
% _________________________________________________________________________

persistent on outdir maxcalls nextid stack_ids stack_names stack_saved ncalls sigs fid

if (strcmp(mode, '-start'))
    outdir = name;
    maxcalls = vars;
    if ~exist(outdir, 'dir')
        mkdir(outdir);
    end
    fid = fopen(fullfile(outdir, 'io_index.txt'), 'w');
    fprintf(fid, '%% id  parent  dir  function  variables\n');
    nextid = 0;
    stack_ids = [];
    stack_names = {};
    stack_saved = [];
    ncalls = struct();
    sigs = struct();
    on = true;
    return;
elseif (strcmp(mode, '-stop'))
    if ~isempty(on) && on
        fclose(fid);
    end
    on = false;
    return;
end

% cheap exit when saving is off
if isempty(on) || ~on
    return;
end

if (strcmp(mode, 'in'))
    nextid = nextid + 1;
    id = nextid;
    if isempty(stack_ids)
        parent = 0;
    else
        parent = stack_ids(end);
    end
    if isfield(ncalls, name)
        ncalls.(name) = ncalls.(name) + 1;
    else
        ncalls.(name) = 1;
    end
    save_it = ncalls.(name) <= maxcalls;
    stack_ids(end+1) = id;
    stack_names{end+1} = name;
    stack_saved(end+1) = save_it;
else
    % pop the call of 'name' (a missing 'out' of a callee is skipped over)
    k = numel(stack_names);
    while k > 0 && ~strcmp(stack_names{k}, name)
        k = k - 1;
    end
    if k == 0
        return;  % 'out' without 'in' (e.g. saving started inside the function)
    end
    id = stack_ids(k);
    if k > 1
        parent = stack_ids(k-1);
    else
        parent = 0;
    end
    save_it = stack_saved(k);
    stack_ids(k:end) = [];
    stack_names(k:end) = [];
    stack_saved(k:end) = [];
end

if ~save_it
    return;
end

% names of the variables to save
if nargin < 3
    if ~isfield(sigs, name)
        sigs.(name) = trace_io_signature(name);
    end
    sig = sigs.(name);
    if strcmp(mode, 'in')
        vars = sig.inputs;
    else
        vars = sig.outputs;
    end
    globs = sig.globals;
else
    globs = {};
end

S = struct();
missing = {};
for k = 1:numel(vars)
    v = vars{k};
    if evalin('caller', sprintf('exist(''%s'', ''var'')', v))
        S.(v) = trace_io_value(evalin('caller', v), 3);
    else
        missing{end+1} = v;
    end
end
for k = 1:numel(globs)
    g = globs{k};
    eval(sprintf('global %s; gval = %s;', g, g));
    S.(['global_' g]) = trace_io_value(gval, 3);
end
S.trace_function = name;
S.trace_id = id;
S.trace_parent = parent;
S.trace_dir = mode;
S.trace_missing = missing;

save('-v7', fullfile(outdir, sprintf('%06d_%s_%s.mat', id, name, mode)), '-struct', 'S');
saved = fieldnames(S)';
saved = saved(~strncmp(saved, 'trace_', 6));
if ~isempty(missing)
    saved{end+1} = ['(missing: ', strjoin(missing, ' '), ')'];
end
fprintf(fid, '%6d %6d  %-3s  %s  %s\n', id, parent, mode, name, strjoin(saved, ' '));
end


function sig = trace_io_signature(name)
% input/output argument names and declared globals, read from the source file
sig = struct('inputs', {{}}, 'outputs', {{}}, 'globals', {{}});
txt = fileread(which(name));
lines = strsplit(txt, "\n");
found_function = false;
for k = 1:numel(lines)
    l = regexprep(lines{k}, '%.*$', '');
    if ~found_function
        t = regexp(l, '^\s*function\s+(.*)$', 'tokens', 'once');
        if ~isempty(t)
            found_function = true;
            rest = t{1};
            % outputs: what is before '=', if '=' comes before '('
            eq = strfind(rest, '=');
            par = strfind(rest, '(');
            if ~isempty(eq) && (isempty(par) || eq(1) < par(1))
                sig.outputs = regexp(rest(1:eq(1)-1), '\w+', 'match');
                rest = rest(eq(1)+1:end);
            end
            % inputs: what is between the parentheses after the name
            p = regexp(rest, '\(([^)]*)\)', 'tokens', 'once');
            if ~isempty(p)
                sig.inputs = regexp(p{1}, '\w+', 'match');
            end
            continue;
        end
    end
    t = regexp(l, '^\s*global\s+(.*)$', 'tokens', 'once');
    if ~isempty(t)
        sig.globals = [sig.globals, regexp(t{1}, '\w+', 'match')];
    end
end
sig.globals = unique(sig.globals, 'stable');
end


function v = trace_io_value(v, depth)
% make a value storable in a .mat file: function handles become a struct with
% their text and captured variables (down to 'depth' levels of handles)
if isa(v, 'function_handle')
    info = functions(v);
    h = struct('class', 'function_handle', 'text', func2str(v));
    if depth > 0 && isfield(info, 'workspace') && ~isempty(info.workspace)
        ws = info.workspace{1};
        f = fieldnames(ws);
        for k = 1:numel(f)
            ws.(f{k}) = trace_io_value(ws.(f{k}), depth - 1);
        end
        h.workspace = ws;
    end
    v = h;
elseif iscell(v)
    for k = 1:numel(v)
        v{k} = trace_io_value(v{k}, depth);
    end
elseif isstruct(v)
    f = fieldnames(v);
    for j = 1:numel(v)
        for k = 1:numel(f)
            v(j).(f{k}) = trace_io_value(v(j).(f{k}), depth);
        end
    end
end
end
