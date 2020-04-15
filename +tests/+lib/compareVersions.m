function res = compareVersions(verArray, verComp)
    % compareVersions - Semantic version comparison (greater than or equal)
    %
    % This function evaluates if an array of semantic versions is greater than 
    % or equal to a reference version.
    %
    % DISTRIBUTION:
    %  GitHub:       https://github.com/guzman-raphael/compareVersions
    %  FileExchange: https://www.mathworks.com/matlabcentral/fileexchange/71849-compareversions
    %
    % res = compareVersions(verArray, verComp)
    % INPUT:
    %   verArray: Cell array with the following conditions:
    %              - be of length >= 1,
    %              - contain only string elements, and
    %              - each element must be of length >= 1.
    %   verComp:  String or Char array that verArray will compare against for
    %             greater than evaluation. Must be:
    %              - be of length >= 1, and
    %              - a string.
    % OUTPUT:
    %   res:      Logical array that identifies if each cell element in verArray
    %             is greater than or equal to verComp.
    % TESTS:
    %   Tests included for reference. From root package directory,
    %   use command: runtests
    %
    % EXAMPLES:
    %   output = compareVersions({'3.2.4beta','9.5.2.1','8.0'}, '8.0.0'); %logical([0 1 1]) 
    %
    % NOTES:
    %   Tests included for reference. From root package directory,
    %   use command: runtests
    %
    % Tested: Matlab 9.5.0.944444 (R2018b) Linux
    % Author: Raphael Guzman, DataJoint
    %
    % $License: MIT (use/copy/change/redistribute on own risk) $
    % $File: compareVersions.m $
    % History:
    % 001: 2019-06-12 11:00, First version.
    %
    % OPEN BUGS:
    %  - None 
    res_n = length(verArray);
    if ~res_n || max(cellfun(@(c) ~ischar(c) && ...
            ~isstring(c),verArray)) > 0 || min(cellfun('length',verArray)) == 0
        msg = {
            'compareVersions:Error:CellArray'
            'Cell array to verify must:'
            '- be of length >= 1,'
            '- contain only string elements, and'
            '- each element must be of length >= 1.'
        };
        error('compareVersions:Error:CellArray', sprintf('%s\n',msg{:}));
    end
    if ~ischar(verComp) && ~isstring(verComp) || length(verComp) == 0
        msg = {
            'compareVersions:Error:VersionRef'
            'Version reference must:'
            '- be of length >= 1, and'
            '- a string.'
        };
        error('compareVersions:Error:VersionRef', sprintf('%s\n',msg{:}));
    end
    res = false(1, res_n);
    for i = 1:res_n
        shortVer = strsplit(verArray{i}, '.');
        shortVer = cellfun(@(x) str2double(regexp(x,'\d*','Match')), shortVer(1,:));
        longVer = strsplit(verComp, '.');
        longVer = cellfun(@(x) str2double(regexp(x,'\d*','Match')), longVer(1,:)); 
        shortVer_p = true;
        longVer_p = false;
        shortVer_s = length(shortVer);
        longVer_s = length(longVer);

        if shortVer_s > longVer_s
            [longVer shortVer] = deal(shortVer,longVer);
            [longVer_s shortVer_s] = deal(shortVer_s,longVer_s);
            [longVer_p shortVer_p] = deal(shortVer_p,longVer_p);
        end

        shortVer = [shortVer zeros(1,longVer_s - shortVer_s)];
        diff = shortVer - longVer;
        match = diff ~= 0;
       
        if ~match
            res(i) = true;
        else
            pos = 1:longVer_s;
            pos = pos(match);
            val = diff(pos(1));
            if val > 0
                res(i) = shortVer_p;
            elseif val < 0
                res(i) = longVer_p;
            end
        end
    end
end