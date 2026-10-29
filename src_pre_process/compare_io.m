function nbad = compare_io(refdir, testdir, tol)
%%    Compare two sets of function input/output data saved by trace_io
% _________________________________________________________________________
%
%   nbad = compare_io(refdir, testdir)       relative tolerance 1e-12
%   nbad = compare_io(refdir, testdir, tol)
%
%   For every <id>_<func>_<in|out>.mat file of 'refdir' (in call order), the
%   same file of 'testdir' is loaded and every saved variable is compared:
%   numbers element by element by the relative error |a-b| / |a| (values
%   below 1e-15 of the largest |a| are compared to that floor; NaN must be at
%   the same places), the rest (text, logical, integers, sizes, classes)
%   exactly; cells, structs and the captured data of function handles are
%   compared element by element. Variables named trace_* (ids, ...) are skipped.
%
%   Prints one line per differing file and, at the end, the first call whose
%   data differ: with the inputs equal and the outputs different, that is the
%   function to look at. Returns the number of differing files.
%
% _________________________________________________________________________

if nargin < 3
    tol = 1e-12;
end

files = dir(fullfile(refdir, '*.mat'));
names = sort({files.name});
nbad = 0;
nmiss = 0;
first = '';
for k = 1:numel(names)
    f = names{k};
    if ~exist(fullfile(testdir, f), 'file')
        printf('MISSING  %s\n', f);
        nmiss = nmiss + 1;
        continue;
    end
    A = load(fullfile(refdir, f));
    B = load(fullfile(testdir, f));
    msgs = {};
    vars = fieldnames(A);
    for j = 1:numel(vars)
        v = vars{j};
        if strncmp(v, 'trace_', 6)
            continue;
        end
        if ~isfield(B, v)
            msgs{end+1} = sprintf('%s: missing', v);
            continue;
        end
        m = compare_value(A.(v), B.(v), tol, v);
        if ~isempty(m)
            msgs{end+1} = m;
        end
    end
    extra = setdiff(fieldnames(B), vars);
    for j = 1:numel(extra)
        msgs{end+1} = sprintf('%s: only in test', extra{j});
    end
    if ~isempty(msgs)
        nbad = nbad + 1;
        printf('DIFF     %s\n', f);
        printf('           %s\n', msgs{:});
        if isempty(first)
            first = f;
        end
    end
end

printf('\n%d files compared, %d differ, %d missing in %s (tolerance %g)\n', ...
       numel(names), nbad, nmiss, testdir, tol);
if ~isempty(first)
    printf('first difference: %s\n', first);
end
end


function msg = compare_value(a, b, tol, path)
% empty if a and b are equal within tol, else a description of the difference
msg = '';
if ~strcmp(class(a), class(b))
    msg = sprintf('%s: class %s vs %s', path, class(a), class(b));
elseif ~isequal(size(a), size(b))
    msg = sprintf('%s: size %s vs %s', path, mat2str(size(a)), mat2str(size(b)));
elseif isstruct(a)
    fa = fieldnames(a);
    if ~isequal(sort(fa), sort(fieldnames(b)))
        msg = sprintf('%s: different fields', path);
        return;
    end
    for i = 1:numel(a)
        for j = 1:numel(fa)
            msg = compare_value(a(i).(fa{j}), b(i).(fa{j}), tol, ...
                                sprintf('%s(%d).%s', path, i, fa{j}));
            if ~isempty(msg)
                return;
            end
        end
    end
elseif iscell(a)
    for i = 1:numel(a)
        msg = compare_value(a{i}, b{i}, tol, sprintf('%s{%d}', path, i));
        if ~isempty(msg)
            return;
        end
    end
elseif isfloat(a)
    a = a(:);
    b = b(:);
    if ~isequal(isnan(a), isnan(b))
        msg = sprintf('%s: NaN at different places', path);
        return;
    end
    ok = ~isnan(a);
    a = full(a(ok));
    b = full(b(ok));
    if isempty(a)
        return;
    end
    % element-wise relative error: the components of one result can differ
    % by many orders of magnitude (e.g. the 7 integrals of volume_volume), so
    % an error relative to the largest one would hide errors in the small
    % ones. Values below 1e-15 of the largest one are compared to that floor.
    scale = max(abs(a));
    if scale == 0
        scale = 1;
    end
    [rel, i] = max(abs(a - b) ./ max(abs(a), 1e-15 * scale));
    if rel > tol
        msg = sprintf('%s: relative error %.3g at element %d (%.17g vs %.17g)', ...
                      path, rel, i, real(a(i)), real(b(i)));
    end
elseif ~isequal(a, b)
    msg = sprintf('%s: values differ', path);
end
end
