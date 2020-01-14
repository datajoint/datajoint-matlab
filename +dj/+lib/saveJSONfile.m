function saveJSONfile(data, jsonFileName)
% Modified from FileExchange entry:
% https://www.mathworks.com/matlabcentral/fileexchange/...
%   50965-structure-to-json?focused=3876199&tab=function
% saves the values in the structure 'data' to a file in JSON indented format.
%
% Example:
%     data.name = 'chair';
%     data.color = 'pink';
%     data.metrics.height = 0.3;
%     data.metrics.width = 1.3;
%     saveJSONfile(data, 'out.json');
%
% Output 'out.json':
% {
% 	"name" : "chair",
% 	"color" : "pink",
% 	"metrics" : {
% 		"height" : 0.3,
% 		"width" : 1.3
% 		}
% 	}
%
    fid = fopen(jsonFileName,'w');
    writeElement(fid, data,'');
    fprintf(fid,'\n');
    fclose(fid);
end
function writeElement(fid, data,tabs)
    namesOfFields = fieldnames(data);
    tabs = sprintf('%s\t',tabs);
    fprintf(fid,'{\n%s',tabs);
    key = true;
    for i = 1:length(namesOfFields) - 1
        currentField = namesOfFields{i};
        currentElementValue = data.(currentField);
        writeSingleElement(fid, currentField,currentElementValue,tabs, key);
        fprintf(fid,',\n%s',tabs);
    end
    currentField = namesOfFields{end};
    currentElementValue = data.(currentField);
    writeSingleElement(fid, currentField,currentElementValue,tabs, key);
    fprintf(fid,'\n%s}',tabs(1:end-1));
end
function writeSingleElement(fid, currentField,currentElementValue,tabs, key)
    % if this is an array and not a string then iterate on every
    % element, if this is a single element write it
    currentField = regexprep(currentField,'[a-z0-9][A-Z]','${$0(1)}.${lower($0(2))}');
    if key
        fprintf(fid,'"%s" : ' , currentField);
    end
    if length(currentElementValue) > 1 && ~ischar(currentElementValue)
        fprintf(fid,'[\n%s\t',tabs);
        for m = 1:length(currentElementValue)-1
            if isstruct(currentElementValue(m))
                writeElement(fid, currentElementValue(m),tabs);
            else
                writeSingleElement(fid, '',currentElementValue(m),tabs, false)
            end
            fprintf(fid,',\n%s\t',tabs);
        end
        if isstruct(currentElementValue(end))
            writeElement(fid, currentElementValue(end),tabs);
        else
            writeSingleElement(fid, '',currentElementValue(end),tabs, false)
        end
        fprintf(fid,'\n%s]',tabs);
    elseif isstruct(currentElementValue)
        writeElement(fid, currentElementValue,tabs);
    elseif isempty(currentElementValue)
        fprintf(fid,'null');
    elseif isnumeric(currentElementValue)
        fprintf(fid,'%g' ,currentElementValue);
    elseif islogical(currentElementValue)
        if currentElementValue
            fprintf(fid,'true');
        else
            fprintf(fid,'false');
        end 
    else %ischar or something else ...
        fprintf(fid,'"%s"',currentElementValue);
    end
end