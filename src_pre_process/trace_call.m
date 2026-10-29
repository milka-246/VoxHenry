function trace_call(name, fileoutname)
%%    Record the sequence of functions/scripts called during a simulation
% _________________________________________________________________________
%
%   trace_call('func_name')          record one call of 'func_name'
%   trace_call('-reset')             forget all the recorded calls
%   trace_call('-save', fileoutname) write the recorded calls to a text file
%
%   Each line of the file has the call depth (number of function/script
%   frames on the call stack, anonymous functions excluded) and the caller:
%   the nearest function on the call stack that is itself traced ('-' when
%   called from the main script). The caller skips any untraced frame
%   (anonymous functions, parfor internals, ...), so the call tree is
%   rebuilt from it. Consecutive calls of the same function are merged in
%   one line with the number of calls in a row.
%
% _________________________________________________________________________

persistent names counts depths callers known num

if isempty(num)
    names = cell(1024, 1);
    counts = zeros(1024, 1);
    depths = zeros(1024, 1);
    callers = cell(1024, 1);
    known = struct();
    num = 0;
end

if (strcmp(name, '-reset'))
    names = cell(1024, 1);
    counts = zeros(1024, 1);
    depths = zeros(1024, 1);
    callers = cell(1024, 1);
    known = struct();
    num = 0;
elseif (strcmp(name, '-save'))
    fid = fopen(fileoutname, 'w');
    if fid < 0
        disp(['ERROR opening the call trace file ', fileoutname]);
        return;
    end
    fprintf(fid, '%% order  calls  depth  caller  function\n');
    for k = 1:num
        fprintf(fid, '%7d %6d %6d  %s  %s\n', k, counts(k), depths(k), callers{k}, names{k});
    end
    fclose(fid);
elseif (num > 0 && strcmp(names{num}, name))
    % same function as the previous call (same caller): just count it,
    % without the cost of reading the call stack again
    counts(num) = counts(num) + 1;
else
    % grow the storage by doubling, to avoid reallocating at every call
    if num == length(counts)
        names{2*num} = [];
        counts(2*num) = 0;
        depths(2*num) = 0;
        callers{2*num} = [];
    end
    num = num + 1;
    names{num} = name;
    counts(num) = 1;
    known.(name) = true;
    % st(1) is trace_call, st(2) the traced function itself
    st = dbstack;
    % call depth: skip trace_call and the anonymous function frames
    depths(num) = sum(cellfun(@(s) s(1) ~= '@', {st(2:end).name}));
    % caller: nearest traced function below the traced one on the stack
    callers{num} = '-';
    for k = 3:numel(st)
        if isfield(known, st(k).name)
            callers{num} = st(k).name;
            break;
        end
    end
end
