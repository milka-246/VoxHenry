function trace_call(name, fileoutname)
%%    Record the sequence of functions/scripts called during a simulation
% _________________________________________________________________________
%
%   trace_call('func_name')          record one call of 'func_name'
%   trace_call('-reset')             forget all the recorded calls
%   trace_call('-save', fileoutname) write the recorded calls to a text fil
%
% _________________________________________________________________________

persistent names counts num

if isempty(num)
    names = cell(1024, 1);
    counts = zeros(1024, 1);
    num = 0;
end

if (strcmp(name, '-reset'))
    names = cell(1024, 1);
    counts = zeros(1024, 1);
    num = 0;
elseif (strcmp(name, '-save'))
    fid = fopen(fileoutname, 'w');
    if fid < 0
        disp(['ERROR opening the call trace file ', fileoutname]);
        return;
    end
    fprintf(fid, '%% order  calls  function\n');
    for k = 1:num
        fprintf(fid, '%7d %6d  %s\n', k, counts(k), names{k});
    end
    fclose(fid);
elseif (num > 0 && strcmp(names{num}, name))
    % same function as the previous call: just count it
    counts(num) = counts(num) + 1;
else
    % grow the storage by doubling, to avoid reallocating at every call
    if num == length(counts)
        names{2*num} = [];
        counts(2*num) = 0;
    end
    num = num + 1;
    names{num} = name;
    counts(num) = 1;
end
