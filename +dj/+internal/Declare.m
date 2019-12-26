classdef Declare
    % This static class hosts functions to convert DataJoint table 
    % definitions into mysql table definitions, and to declare the 
    % corresponding mysql tables.
    
    methods(Static)
        function fieldInfo = parseAttrDef(line)
            line = strtrim(line);
            assert(~isempty(regexp(line, '^[a-z][a-z\d_]*', 'once')), ...
                'invalid attribute name in %s', line)
            pat = {
                '^(?<name>[a-z][a-z\d_]*)\s*'     % field name
                ['=\s*(?<default>".*"|''.*''|\w+|[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)' ...
                    '\s*'] % default value
                [':\s*(?<type>\w[\w\s]+(\(.*\))?(\s*[aA][uU][tT][oO]_[iI][nN][cC][rR][eE]' ...
                    '[mM][eE][nN][tT])?)\s*']       % datatype
                '#(?<comment>.*)'           % comment
                '$'  % end of line
                };
            hasDefault = ~isempty(regexp(line, '^\w+\s*=', 'once'));
            if ~hasDefault
                pat{2} = '';
            end
            for sub = {[1 2 3 4 5] [1 2 3 5]}  % with and without the comment
                pattern = cat(2,pat{sub{:}});
                fieldInfo = regexp(line, pattern, 'names');
                if ~isempty(fieldInfo)
                    break
                end
            end
            assert(numel(fieldInfo)==1, 'Invalid field declaration "%s"', line)
            if ~isfield(fieldInfo,'comment')
                fieldInfo.comment = '';
            end
            fieldInfo.comment = strtrim(fieldInfo.comment);
            if ~hasDefault
                fieldInfo.default = '';
            end
            assert(isempty(regexp(fieldInfo.type,'^bigint', 'once')) ...
                || ~strcmp(fieldInfo.default,'null'), ...
                'BIGINT attributes cannot be nullable in "%s"', line)
            fieldInfo.isnullable = strcmpi(fieldInfo.default,'null');
        end

        function [sql, newattrs] = makeFK(sql, line, existingFields, inKey, hash)
            % add foreign key to SQL table definition
            pat = ['^(?<newattrs>\([\s\w,]*\))?' ...
                '\s*->\s*' ...
                '(?<cname>\w+\.[A-Z][A-Za-z0-9]*)' ...
                '\w*' ...
                '(?<attrs>\([\s\w,]*\))?' ...
                '\s*(#.*)?$'];
            fk = regexp(line, pat, 'names');
            if exist(fk.cname, 'class')
                rel = feval(fk.cname);
                assert(isa(rel, 'dj.Relvar'), 'class %s is not a DataJoint relation', fk.cname)
            else
                rel = dj.Relvar(fk.cname);
            end
            
            % parse and validate the attribute lists
            attrs = strsplit(fk.attrs, {' ',',','(',')'});
            newattrs = strsplit(fk.newattrs, {' ',',','(',')'});
            attrs(cellfun(@isempty, attrs))=[];
            newattrs(cellfun(@isempty, newattrs))=[];
            assert(all(cellfun(@(a) ismember(a, rel.primaryKey), attrs)), ...
                'All attributes in (%s) must be in the primary key of %s', ...
                strjoin(attrs, ','), rel.className)
            if length(newattrs)==1 
                % unambiguous single attribute
                if length(rel.primaryKey)==1
                    attrs = rel.primaryKey;
                elseif isempty(attrs) && length(setdiff(rel.primaryKey, existingFields))==1
                    attrs = setdiff(rel.primaryKey, existingFields);
                end
            end
            assert(length(attrs) == length(newattrs) , ...
                'Mapped fields (%s) and (%s) must match in the foreign key.', ...
                strjoin(newattrs,','), strjoin(attrs,','))
            
            % prepend unspecified primary key attributes that have not yet been included 
            pk = rel.primaryKey;
            pk(ismember(pk,attrs) | ismember(pk,existingFields))=[];
            attrs = [pk attrs];
            newattrs = [pk newattrs];
            
            % fromFields and toFields are sorted in the same order as
            % ref.rel.tableHeader.attributes
            [~, ix] = sort(cellfun(@(a) find(strcmp(a, rel.primaryKey)), attrs));
            attrs = attrs(ix);
            newattrs = newattrs(ix);
            
            for i=1:length(attrs)
                fieldInfo = rel.tableHeader.attributes(strcmp(attrs{i}, ...
                    rel.tableHeader.names));
                fieldInfo.name = newattrs{i};
                fieldInfo.nullabe = ~inKey;   % nonprimary references are nullable
                sql = sprintf('%s%s', sql, fieldToSQL(fieldInfo));
            end
            
            fkattrs = rel.primaryKey;
            fkattrs(ismember(fkattrs, attrs))=newattrs;
            hash = dj.internal.shorthash([{hash rel.fullTableName} newattrs]);
            sql = sprintf(...
                ['%sCONSTRAINT `%s` FOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE CASCADE ' ...
                'ON DELETE RESTRICT'], sql, hash, backquotedList(fkattrs), ...
                rel.fullTableName, backquotedList(rel.primaryKey));
        end
    end
end
