function saveJSONfile(data, jsonFileName)
    % saves the values in the structure 'data' to a file in JSON format.
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
        numFields = length(namesOfFields);
        tabs = sprintf('%s\t',tabs);
        fprintf(fid,'{\n%s',tabs);
        key = true;
        for i = 1:numFields - 1
            currentField = namesOfFields{i};
            currentElementValue = data.(currentField);
            writeSingleElement(fid, currentField,currentElementValue,tabs, key);
            fprintf(fid,',\n%s',tabs);
        end
        if isempty(i)
            i=1;
        else
            i=i+1;
        end


        currentField = namesOfFields{i};
        currentElementValue = data.(currentField);
        writeSingleElement(fid, currentField,currentElementValue,tabs, key);
        fprintf(fid,'\n%s}',tabs(1:end-1));
    end
    function writeSingleElement(fid, currentField,currentElementValue,tabs, key)

            % if this is an array and not a string then iterate on every
            % element, if this is a single element write it
            currentField = regexprep(currentField,'[a-z0-9][A-Z]','${$0(1)}.${lower($0(2))}');
            if length(currentElementValue) > 1 && ~ischar(currentElementValue)
                if key
                    fprintf(fid,'"%s" : ' , currentField);
                end
                fprintf(fid,'[\n%s\t',tabs);
                for m = 1:length(currentElementValue)-1
                    if isstruct(currentElementValue(m))
                        writeElement(fid, currentElementValue(m),tabs);
                    else
                        writeSingleElement(fid, '',currentElementValue(m),tabs, false)
                    end
                    fprintf(fid,',\n%s\t',tabs);
                end
                if isempty(m)
                    m=1;
                else
                    m=m+1;
                end

                if isstruct(currentElementValue(m))
                    writeElement(fid, currentElementValue(m),tabs);
                else
                    writeSingleElement(fid, '',currentElementValue(m),tabs, false)
                end

                fprintf(fid,'\n%s]',tabs);
            elseif isstruct(currentElementValue)
                if key
                    fprintf(fid,'"%s" : ' , currentField);
                end
                writeElement(fid, currentElementValue,tabs);
            elseif isempty(currentElementValue)
                if key
                    fprintf(fid,'"%s" : ' , currentField);
                end
                fprintf(fid,'null');
            elseif isnumeric(currentElementValue)
                if key
                    fprintf(fid,'"%s" : ' , currentField);
                end
                fprintf(fid,'%g' ,currentElementValue);
            elseif islogical(currentElementValue)
                if key
                    fprintf(fid,'"%s" : ' , currentField);
                end
                if currentElementValue
                    fprintf(fid,'true');
                else
                    fprintf(fid,'false');
                end 
            else %ischar or something else ...
                if key
                    fprintf(fid,'"%s" : ' , currentField);
                end
                fprintf(fid,'"%s"',currentElementValue);
            end
    end