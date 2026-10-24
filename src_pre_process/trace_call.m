function trace_call(name, fileoutname)
%%    Record the sequence of functions/scripts called during a simulation
% _________________________________________________________________________
%
%   trace_call('func_name')          record one call of 'func_name'
%   trace_call('-reset')             forget all the recorded calls
%   trace_call('-save', fileoutname) write the recorded calls to a text file
%
%   Each line of the file has the call depth (number of function/script
%   frames on the call stack, anonymous functions excluded), so that the
%   call tree can be rebuilt. Consecutive calls of the same function are
%   merged in one line with the number of calls in a row.
%
% _________________________________________________________________________

persistent names counts depths num

if isempty(num)
    names = cell(1024, 1);
    counts = zeros(1024, 1);
    depths = zeros(1024, 1);
    num = 0;
end

if (strcmp(name, '-reset'))
    names = cell(1024, 1);
    counts = zeros(1024, 1);
    depths = zeros(1024, 1);
    num = 0;
elseif (strcmp(name, '-save'))
    fid = fopen(fileoutname, 'w');
    if fid < 0
        disp(['ERROR opening the call trace file ', fileoutname]);
        return;
    end
    fprintf(fid, '%% order  calls  depth  function\n');
    for k = 1:num
        fprintf(fid, '%7d %6d %6d  %s\n', k, counts(k), depths(k), names{k});
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
    end
    num = num + 1;
    names{num} = name;
    counts(num) = 1;
    % call depth of the caller of trace_call: skip trace_call itself
    % and the anonymous function frames (e.g. the GMRES operator handles)
    st = dbstack;
    depths(num) = sum(cellfun(@(s) s(1) ~= '@', {st(2:end).name}));
end
