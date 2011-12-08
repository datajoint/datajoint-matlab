% Relvar: a relational variable supporting relational operators
% A relvar may be a base relation associated with a table or a derived
% relation.
%
% SYNTAX:
%    obj = dj.Relvar  % can only be called after adding property 'table' of type dj.Table
%    obj = dj.Relvar(otherRelvar) % copy constructor, strips derived identity
%    obj = dj.Relvar(tableObj)    % construct a relvar servicing the table
%


classdef Relvar < matlab.mixin.Copyable & dynamicprops
    
    properties(SetAccess = private)
        schema  % handle to the schema object
    end
    
    properties(Dependent, SetAccess = private)
        primaryKey   % primary key attribute names
        nonKeyFields % non-key attribute names
    end
    
    properties(Access = private)
        updateListener   % listens for schema definition changes
        attrs   % struct array of attribute info, updated by relational operators
        sql     % sql statement: source, projection, and restriction clauses
        tab     % private dj.Table object, copied from public self.table
    end
    
    methods
        function self = Relvar(copyObj)
            switch true
                case nargin==0 && ~isempty(self.findprop('table'))
                    % normal constructor with no parameters.
                    % The derived class must have a 'table' property of type dj.Table
                    assert(isa(self.table,'dj.Table'), 'self.table must be a dj.Table')
                    assert(strcmp(class(self), self.table.className), ...
                        'class name %s does not match table name %s', ...
                        class(self), self.table.className)
                    self.tab = self.table;
                    
                case nargin==1 && isa(copyObj, 'dj.Relvar')
                    % (almost) copy constructor. Makes a derived relation. 
                    self.schema = copyObj.schema;
                    self.sql = copyObj.sql;
                    self.attrs = copyObj.attrs;
                    self.tab = []; % derived relation has no table object
                    
                case nargin==1 && ischar(copyObj)
                    % initialization as dj.Relvar('schema.ClassName')
                    self.tab = dj.Table(copyObj);
                    
                case nargin==1 && isa(copyObj, 'dj.Table')
                    % initialization from a dj.Table without a table-specific class
                    self.tab = copyObj;
                    
                otherwise
                    error 'invalid initatlization'
                    
            end
            
            self.updateListener = event.listener(self.schema, ...
                'ChangedDefinitions', @(eventSrc,eventData) self.reset);
            
            self.reset;
        end        
        
        
        function names = get.primaryKey(self)
            if isempty(self.attrs)
                names = {};
            else
                names = {self.attrs([self.attrs.iskey]).name};
            end
        end
        
        
        function names = get.nonKeyFields(self)
            if isempty(self.attrs)
                names = {};
            else
                names = {self.attrs(~[self.attrs.iskey]).name};
            end
        end
        
        
        function display(self, justify)
            % dj.Relvar/disp - display the contents of the relation.
            % Only non-blob attrs of the first several tuples are shown.
            % The total number of tuples is printed at the end.
            
            justify = nargin==1 || justify;
            tic
            display@handle(self)
            nTuples = self.count;
            
            
            if nTuples>0
                % print header
                ix = find( ~[self.attrs.isBlob] );  % attrs to display
                fprintf \n
                fprintf('  %12.12s', self.attrs(ix).name)
                fprintf \n
                maxRows = 12;
                tuples = self.fetch(self.attrs(ix).name,maxRows+1);
                
                % print rows
                for s = tuples(1:min(end,maxRows))'
                    for iField = ix
                        v = s.(self.attrs(iField).name);
                        if isnumeric(v)
                            fprintf('  %12g',v)
                        else
                            if justify
                                fprintf('  %12.12s',v)
                            else
                                fprintf('  ''%12s''', v)
                            end
                        end
                    end
                    fprintf '\n'
                end
                if nTuples > maxRows
                    for iField = ix
                        fprintf('  %12s','.....')
                    end
                    fprintf '\n'
                end
            end
            
            % print the total number of tuples
            fprintf('%d tuples (%.3g s)\n\n', nTuples, toc)
        end
        
        
        
        function n = count(self)
            % dj.Relvar.count return the cardinality of the relation contained
            % in this relvar.
            if strcmp(self.sql.pro, '*')
                n = self.schema.query(...
                    sprintf('SELECT count(*) as n FROM %s%s',...
                    self.sql.src, self.sql.res));
            else
                n = self.schema.query(...
                    sprintf('SELECT count(*) as n FROM (SELECT DISTINCT %s FROM %s%s) as r', ...
                    self.sql.pro, self.sql.src, self.sql.res));
            end
            n=n.n;
        end
        
        
        function ret = isempty(self)
            warning('DataJoint:deprecation',...
                'dj.Relvar/isemtpy is deprecated. Use ~dj.Relvar/count instead')
            ret = ~self.count;
        end
        
        
        function ret = length(self)
            warning('DataJoint:deprecation',...
                'dj.Relva/length is deprecated. Use dj.Relvar/count instead')
            ret = self.count;
        end
        
        
        
        
        function view(self)
            % dj.Relvar/view - view the data in speadsheet form
            
            if ~count(self)
                disp('empty relation')
            else
                columns = {self.attrs.name};
                
                assert(~any([self.attrs.isBlob]), 'cannot view blobs')
                
                % specify table header
                columnName = columns;
                for iCol = 1:length(columns)
                    
                    if self.attrs(iCol).iskey
                        columnName{iCol} = ['<html><b><font color="black">' columnName{iCol} '</b></font></html>'];
                    else
                        columnName{iCol} = ['<html><font color="blue">' columnName{iCol} '</font></html>'];
                    end
                end
                format = cell(1,length(columns));
                format([self.attrs.isString]) = {'char'};
                format([self.attrs.isNumeric]) = {'numeric'};
                for iCol = find(strncmpi('ENUM', {self.attrs.type}, 4))
                    enumValues = textscan(self.attrs(iCol).type(6:end-1),'%s','Delimiter',',');
                    enumValues = cellfun(@(x) x(2:end-1), enumValues{1}, 'Uni', false);  % strip quotes
                    format(iCol) = {enumValues'};
                end
                
                % display table
                data = fetch(self, columns{:});
                hfig = figure('Units', 'normalized', 'Position', [0.1 0.1 0.5 0.4], ...
                    'MenuBar', 'none');
                uitable(hfig, 'Units', 'normalized', 'Position', [0.0 0.0 1.0 1.0], ...
                    'ColumnName', columnName, 'ColumnEditable', false(1,length(columns)), ...
                    'ColumnFormat', format, 'Data', struct2cell(data)');
            end
        end
        
        
        
        
        function enter(self, key)
            % dj.Relvar/enter - manually enter data into the table,
            % matching the given key.
            
            assert(~isempty(self.tab), 'Cannot enter data into a derived relation')
            assert(ismember(self.tab.info.tier, {'manual','lookup'}), 'cannot enter data into automatic tables')
            
            if nargin<2
                key = struct;
            end
            
            hfig = figure('Units', 'normalized', 'Position', [0.1 0.1 0.8 0.4], ...
                'MenuBar', 'none', 'Name', self.tab.className);
            
            % buttons
            uicontrol('Parent', hfig, 'String', '+','Style', 'pushbutton', ...
                'Position', [15 15 15 18], 'Callback', {@newTuple});
            uicontrol('Parent', hfig','String','commit','Style','pushbutton', ...
                'Position', [50 15 80 18], 'Callback', {@commit});
            uicontrol('Parent', hfig, 'String', 'refresh','Style', 'pushbutton',...
                'Position', [140 15 80 18], 'Callback', {@refresh});
            hstat = uicontrol('Parent', hfig, 'Style','text',...
                'Position', [250 15 450 16]);
            
            columns = {'committed', self.attrs.name};
            
            % create table UI
            format = cell(1,length(columns)-1);
            format([self.attrs.isString]) = {'char'};
            format([self.attrs.isNumeric]) = {'numeric'};
            for iCol = find(strncmpi('ENUM', {self.attrs.type}, 4))
                enumValues = textscan(self.attrs(iCol).type(6:end-1),'%s','Delimiter',',');
                enumValues = cellfun(@(x) x(2:end-1), enumValues{1}, 'Uni', false);  % strip quotes
                format(iCol) = {enumValues'};
            end
            format = [{'logical'} format];
            columnName = columns;
            for iCol = 1:length(columns)
                if iCol == 1
                    columnName{iCol} = ['<html><i><font color="red">' columnName{iCol} '</i></font></html>'];
                else
                    if self.attrs(iCol-1).iskey
                        columnName{iCol} = ['<html><b><font color="black">' columnName{iCol} '</b></font></html>'];
                    else
                        columnName{iCol} = ['<html><font color="blue">' columnName{iCol} '</font></html>'];
                    end
                end
            end                       
            htab = uitable(hfig, 'Units', 'normalized', 'Position', [0.0 0.1 1.0 0.9], ...
                'ColumnName', columnName, 'ColumnEditable', ~isfield(key,columns), ...
                'ColumnFormat', format, 'CellEditCallback', {@cellEdit}, ...
                'CellSelectionCallback', {@selectCell});
            data = {};
            refresh;
            
            
            function refresh(varargin)
                data = struct2cell(fetch(self & key, columns{2:end}));
                data = reshape(data, size(data,1), size(data,2))';  % this is necessary when data is empty
                data = [num2cell(true(size(data,1),1)) data];
                set(htab, 'Data', data)
                set(hstat, 'String', 'status: ok');
            end
            
            function selectCell(~,selection)
                idx = selection.Indices;
                if ~isempty(idx) && idx(2)>1
                    if ~self.attrs(idx(2)-1).iskey && ~all([data{:,1}])
                        set(hstat, 'String', 'status: Cannot modify committed tuples when uncommitted tuples exist. Commit first.')
                    else
                        set(hstat, 'String', 'status: ok')
                    end
                end
            end
            
            
            function cellEdit(htab, change)
                idx = change.Indices;
                if data{idx(1),1}   % if modifiying committed data
                    if ~self.attrs(idx(2)-1).iskey  % allow only if everything else is committed
                        if ~all([data{:,1}])
                            set(hstat, 'String', 'status: Cannot modify committed tuples when uncommitted tuples exist. Commit or refresh first.')
                        else
                            choice = questdlg('Are you sure you want to update a committed tuple?', ...
                                'update confirmation', 'Update', 'Cancel', 'Cancel');
                            if strcmp(choice,'Update')
                                ikey = find([self.attrs.iskey]);
                                updateKey = cell2struct(data(idx(1), ikey+1)', columns(ikey+1)');
                                update(self & updateKey, columns{idx(2)}, change.NewData)
                                data{idx(1),idx(2)} = change.NewData;
                            end
                            set(hstat, 'String', 'status: ok')
                        end
                    else
                        % if modified a key field in a committed tuple, duplicate the tuple
                        data = data([1:idx idx:end],:);
                        idx(1) = idx(1)+1;
                        data{idx(1),idx(2)} = change.NewData;
                        data{idx(1),1}= false;
                        set(hstat,'String','status: you have uncommitted tuples');
                    end
                else
                    data{idx(1),idx(2)} = change.NewData;
                    data{idx(1),1}= false;
                    set(hstat,'String','status: you have uncommitted tuples');
                end
                set(htab, 'Data', data);
            end
            
            
            function newTuple(~,~)
                if size(data,1)>0
                    tuple = data(end,:);
                    tuple{1} = false;
                else
                    tuple(find(~[self.attrs.isNumeric])+1)={''};
                    tuple{1} = false;
                    for icol=2:length(columns)
                        switch true
                            case isfield(key,columns{icol})
                                tuple{icol} = key.(columns{icol});
                            case ~strcmp(self.attrs(icol-1).default, '<<<none>>>') && ~self.attrs(icol-1).isnullable
                                if self.attrs(icol-1).isNumeric
                                    tuple{icol} = str2double(self.attrs(icol-1).default);
                                else
                                    tuple{icol} = self.attrs(icol-1).default;
                                end
                            case strncmpi('ENUM', self.attrs(icol-1).type, 4)
                                tuple{icol} = format{icol}{1};
                        end
                    end
                end
                if isempty(data)
                    data = tuple;
                else
                    data = [data; tuple];
                end
                set(htab, 'Data', data)
            end
            
            function commit(~,~)
                ix = find(~[data{:,1}]);
                if isempty(ix)
                    set(hstat, 'String', 'status: nothing to commit')
                else
                    v = data(ix,2:end);
                    f = columns(2:end);
                    tuples = cell2struct(v',f');
                    for i=1:length(tuples)
                        try
                            insert(self,tuples(i));
                            data{ix(i),1}=true;
                            set(htab,'Data',data)
                        catch err
                            set(hstat, 'String', sprintf('error: %s', err.message))
                        end
                    end
                end
            end
        end
        
        
        
        
        
        function del(self, doPrompt)
            % dj.Relvar/del - remove all tuples of relation self from its table
            % as well as all dependent tuples in dependent tables.
            %
            % By default, confirmation is requested before deleting the data.
            % To turn off the confirmation, set the second input doPrompt to false.
            %
            % EXAMPLES:
            %   del(Scans) % delete all tuples from table Scans and all tuples in dependent tables.
            %   del(Scans('mouse_id=12')) % delete all Scans for mouse 12
            %   del(Scans - Cells)  % delete all tuples from table Scans that do not have matching
            %                       % tuples in table Cells
            %
            % See also dj.Table/drop
            
            doPrompt = nargin<2 || doPrompt;
            self.schema.cancelTransaction  % exit ongoing transaction, if any
            
            if self.count==0
                disp 'nothing to delete'
            else
                assert(~isempty(self.tab), 'Cannot delete from a derived relvar')
                
                % warn the user if deleting from a subtable
                if ismember(self.tab.info.tier, {'imported','computed'}) ...
                        && ~isa(self, 'dj.AutoPopulate')
                    fprintf(['!!! %s is a subtable. For referential integrity, ' ...
                        'delete from its parent instead.\n'], class(self))
                    if ~strcmpi('yes', input('Prceed anyway? yes/no >','s'))
                        disp 'delete cancelled'
                        return
                    end
                end
                
                % get the list of dependent tables
                downstream = self.schema.getNeighbors(self.tab.className, 0, +1000, false);
                
                % construct relvars to be deleted
                rels = {self};
                for iRel = downstream(2:end)
                    rels{end+1} = dj.Relvar(self.schema.classNames{iRel}) & self; %#ok:<AGROW>
                end
                
                % exclude relvar with no matching tuples
                counts = cellfun(@(x) count(x), rels);
                include =  counts > 0;
                counts = counts(include);
                rels = rels(include);
                downstream = downstream(include);
                
                % inform the  user about what's being deleted
                if doPrompt
                    disp 'ABOUT TO DELETE:'
                    for iRel = 1:length(rels)
                        fprintf('%s %s: %d', ...
                            rels{iRel}.tab.info.tier, ...
                            self.schema.classNames{downstream(iRel)}, counts(iRel));
                        if ismember(rels{iRel}.tab.info.tier, {'manual','lookup'})
                            fprintf ' !!!'
                        end
                        fprintf \n
                    end
                    fprintf \n
                end
                
                % confirm and delete
                if doPrompt && ~strcmpi('yes', input('Proceed to delete? yes/no >', 's'))
                    disp 'delete canceled'
                else
                    self.schema.startTransaction
                    try
                        for iRel = length(rels):-1:1
                            fprintf('Deleting %d tuples from %s... ', ...
                                counts(iRel), rels{iRel}.tab.className)
                            self.schema.query(sprintf('DELETE FROM %s%s', ...
                                rels{iRel}.sql.src, rels{iRel}.sql.res))
                            fprintf 'done (not committed)\n'
                        end
                        self.schema.commitTransaction
                        fprintf ' ** delete committed\n'
                    catch err
                        fprintf '\n ** delete rolled back due to to error\n'
                        self.schema.cancelTransaction
                        rethrow(err)
                    end
                end
            end
        end
        
        
        
        %%%%%%%%%%%%%%%%%%  RELATIONAL OPERATORS %%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function self = times(self, arg)
            % this alias is for backward compatibility
            self = self & arg;
        end
        
        
        
        function self = and(self, arg)
            % dj.Relvar/and - relational restriction
            %
            % R1 & cond  yeilds a relation containing all the tuples in R1
            % that match the condition cond. The condition cond could be an
            % structure array, another relation, or an sql boolean
            % expression.
            %
            % Examples:
            %   Scans & struct('mouse_id',3, 'scannum', 4);
            %   Scans & 'lens=10'
            %   Mice & (Scans & 'lens=10')
            
            self = self.copy;
            self.restrict(arg)
        end
        
        
        
        function self = pro(self, varargin)
            % dj.Relvar/pro - relational operators that modify the relvar's header:
            % project, rename, extend, and aggregate.
            %
            % SYNTAX:
            %   r = rel.pro(attr1, ..., attrn)
            %   r = rel.pro(otherRel, attr1, ..., attrn)
            %
            % INPUTS:
            %    'attr1',...,'attrn' is a comma-separated string of attributes.
            %    otherRel is another relvar for the aggregate operator
            %
            % The result will return another relation with the same number of tuples
            % with modified attributes. Primary key attributes are included implicitly
            % and cannot be excluded. Thus pro(rel) simply strips all non-key attrs.
            %
            % Project: To include an attribute, add its name to the attribute list.
            %
            % Rename: To rename an attribute, list it in the form 'old_name->new_name'.
            % Add '*' to the attribute list to add all the other attributes besides the
            % renamed ones.
            %
            % Extend: To compute a new attribute, list it as 'expression->new_name', e.g.
            % 'datediff(exp_date,now())->days_ago'. The computed expressions may use SQL
            % operators and functions.
            %
            % Aggregate: When the second input is another relvar, the computed
            % axpressions may include aggregation functions on attributes of the
            % other relvar: max, min, sum, avg, variance, std, and count.
            %
            % EXAMPLES:
            %   Construct relation r2 containing only the primary keys of r1:
            %   >> r2 = r1.pro();
            %
            %   Construct relation r3 which contains values for 'operator'
            %   and 'anesthesia' for every tuple in r1:
            %   >> r3 = r1.pro('operator','anesthesia');
            %
            %   Rename attribute 'anesthesia' to 'anesth' in relation r1:
            %   >> r1 = r1.pro('*','anesthesia->anesth');
            %
            %   Add field mouse_age to relation r1 that has the field mouse_dob:
            %   >> r1 = r1.pro('*','datediff(now(),mouse_dob)->mouse_age');
            %
            %   Add field 'n' which contains the count of matching tuples in r2
            %   for every tuple in r1. Also add field 'avga' which contains the
            %   average value of field 'a' in r2.
            %   >> r1 = r1.pro(r2,'count(*)->n','avg(a)->avga');
            %
            % See also: dj.Relvar/fetch
            
            self = dj.Relvar(self);  % copy into a derived relation
            
            params = varargin;
            isGrouped = nargin>1 && isa(params{1},'dj.Relvar');
            if isGrouped
                Q = params{1};
                params(1)=[];
            end
            
            assert(iscellstr(params), 'attributes must be provided as a list of strings');
            
            [include,aliases,computedAttrs] = parseAttrList(self, params);
            
            if ~all(include) || ~all(cellfun(@isempty,aliases)) || ~isempty(computedAttrs)
                
                % drop attributes that were not included
                self.attrs = self.attrs(include);
                aliases = aliases(include);
                
                % rename attributes
                fieldList = '';
                c = '';
                for iField=1:length(self.attrs)
                    fieldList=sprintf('%s%s`%s`',fieldList,c,self.attrs(iField).name);
                    if ~isempty(aliases{iField})
                        self.attrs(iField).name=aliases{iField};
                        fieldList=sprintf('%s as `%s`',fieldList,aliases{iField});
                    end
                    c = ',';
                end
                
                % add computed attributes
                for iComp = 1:size(computedAttrs,1)
                    self.attrs(end+1) = struct(...
                        'table','', ...
                        'name',computedAttrs{iComp,2},...
                        'iskey',false,...
                        'type','<sql_computed>',...
                        'isnullable', false,...
                        'comment','server-side computation', ...
                        'default', [], ...
                        'isNumeric', true, ...  % only numeric computations allowed for now, deal with character string expressions somehow
                        'isString', false, ...
                        'isBlob', false);
                    fieldList=sprintf('%s%s %s as `%s`', ...
                        fieldList,c,computedAttrs{iComp,1},computedAttrs{iComp,2});
                    c=',';
                end
                
                % update query
                if ~strcmp(self.sql.pro,'*')
                    self.sql.src = sprintf('(SELECT %s FROM %s%s) as r', ...
                        self.sql.pro, self.sql.src, self.sql.res);
                    self.sql.res = '';
                end
                self.sql.pro = fieldList;
                
                if isGrouped
                    keyStr = sprintf(',%s',self.primaryKey{:});
                    if isempty(Q.sql.res) && strcmp(Q.sql.pro,'*')
                        self.sql.src = sprintf(...
                            '(SELECT %s FROM %s NATURAL JOIN %s%s GROUP BY %s) as q%s', ...
                            self.sql.pro, self.sql.src, ...
                            Q.sql.src, self.sql.res, keyStr(2:end), char(rand(1,3)*26+65));
                    else
                        self.sql.src = sprintf(...
                            '(SELECT %s FROM %s NATURAL JOIN (SELECT %s FROM %s%s) as q%s GROUP BY %s) as q%s', ...
                            self.sql.pro, self.sql.src, ...
                            Q.sql.pro, Q.sql.src, Q.sql.res, ...
                            self.sql.res, keyStr(2:end),char(rand(1,3)*26+65));
                    end
                    self.sql.pro = '*';
                    self.sql.res = '';
                end
            end
        end
        
        
        
        function R1 = rdivide(R1, R2)
            % dj.Relvar/rdivide is depracated and will be removed in a future release.
            % Use dj.Relvar/minus instead.
            % See also dj.Relvar.minus
            R1 = R1 - R2;
        end
        
        
        
        function R1 = mtimes(R1,R2)
            % dj.Relvar/mtimes - relational natural join.
            %
            % SYNTAX:
            %   R3=R1*R2
            %
            % The result will contain all matching combinations of tuples
            % in R1 and tuples in R2. Two tuples make a matching
            % combination if their commonly named attributes contain the
            % same values.
            % Blobs and nullable attrs should not be joined on.
            % To prevent an attribute from being joined on, rename it using
            % dj.Relvar/pro's rename syntax.
            %
            % See also dj.Relvar/pro, dj.Relvar/fetch
            
            % check that the joined relations do not have common attrs that are blobs or opional
            commonIllegal = intersect( ...
                {R1.attrs([R1.attrs.isnullable] | [R1.attrs.isBlob]).name},...
                {R2.attrs([R2.attrs.isnullable] | [R2.attrs.isBlob]).name});
            if ~isempty(commonIllegal)
                error('Attribute ''%s'' is optional or a blob. Exclude it from one of the relations before joining.', ...
                    commonIllegal{1})
            end
            
            R1 = dj.Relvar(R1);
            
            % merge field lists
            [~, ix] = setdiff({R2.attrs.name},{R1.attrs.name});
            R1.attrs = [R1.attrs;R2.attrs(sort(ix))];
            
            % form the join query
            if strcmp(R1.sql.pro,'*') && isempty(R1.sql.res)
                R1.sql.src = sprintf( '%s NATURAL JOIN ',R1.sql.src );
            else
                R1.sql.src = sprintf( '(SELECT %s FROM %s%s) as r1 NATURAL JOIN '...
                    ,R1.sql.pro,R1.sql.src,R1.sql.res);
            end
            R1.sql.pro='*';
            R1.sql.res='';
            
            if strcmp(R2.sql.pro,'*') && isempty(R2.sql.res)
                R1.sql.src = sprintf( '%s%s', R1.sql.src, R2.sql.src);
            else
                alias = char(97+floor(rand(1,6)*26)); % to avoid duplicates
                R1.sql.src = sprintf( '%s (SELECT %s FROM %s%s) as `r2%s`', ...
                    R1.sql.src, R2.sql.pro, R2.sql.src, R2.sql.res, alias);
            end
            
        end
        
        
        
        function R1 = minus(R1,R2)
            % dj.Relvar/minus - relational antijoin (aka semidifference)
            %
            % SYNTAX: R3 = R1-R2
            %
            % The result R3 contains all tuples in R1 that do not have
            % matching tuples in R2. Two tuples are matching if their
            % commonly named attributes contain equal values. These
            % common attrs should not include nullable or blob attrs.
            %
            % See also dj.Relvar/and
            
            R1 = R1.copy; % shallow copy a the original object, preserves its identity
            
            commonIllegal = intersect( ...
                {R1.attrs([R1.attrs.isnullable] | [R1.attrs.isBlob]).name},...
                {R2.attrs([R2.attrs.isnullable] | [R2.attrs.isBlob]).name});
            if ~isempty(commonIllegal)
                error(['Attribute ''%s'' is optional or a blob and cannot be compared. '...
                    'You may project it out first.'], commonIllegal{1})
            end
            
            commonAttrs = intersect({R1.attrs.name}, {R2.attrs.name});
            
            if isempty(commonAttrs)
                % commonAttrs is empty, R1 is the empty relation
                R1.sql.res = [R1.sql.res ' WHERE FALSE'];
            else
                % update R1's query to the semidifference of R1 and R2
                commonAttrs = sprintf( ',%s', commonAttrs{:} );
                commonAttrs = commonAttrs(2:end);
                if ~strcmp(R1.sql.pro,'*')
                    R1.sql.src = sprintf('(SELECT %s FROM %s%s) as r1', ...
                        R1.sql.pro, R1.sql.src, R1.sql.res);
                    R1.sql.pro = '*';
                    R1.sql.res = '';
                end
                if isempty(R1.sql.res)
                    word = 'WHERE';
                else
                    word = 'AND';
                end
                if strcmp(R2.sql.pro,'*')
                    R1.sql.res = sprintf( '%s %s (%s) NOT IN (SELECT %s FROM %s%s)'...
                        , R1.sql.res, word, commonAttrs, commonAttrs, R2.sql.src, R2.sql.res );
                else
                    R1.sql.res = sprintf( '%s %s (%s) NOT IN (SELECT %s from (SELECT %s FROM %s%s) as r2)'...
                        , R1.sql.res, word, commonAttrs, commonAttrs, R2.sql.pro, R2.sql.src, R2.sql.res);
                end
            end
            
        end
        
        
        
        function restrict(self, varargin)
            % Restrict relation self in place by one or more conditions.
            % Condition may include a structure specifying field values to
            % match, an SQL logical expression, or another relvar.
            
            if ~isempty(varargin)
                cond = varargin{1};
                if iscell(cond)
                    self.restrict(cond{:});
                else
                    if isa(cond, 'dj.Relvar')
                        self.semijoin(cond);
                    else
                        if isstruct(cond)
                            cond = self.struct2cond(cond);
                        end
                        assert(ischar(cond), ...
                            'restricting condition must be a struct, a string, or a relvar')
                        
                        if ~isempty(cond)
                            % put the source in a subquery if it has any renames
                            if ~isempty(regexpi(self.sql.pro,' as '))
                                self.sql.src = sprintf('(SELECT %s FROM %s%s) as r'...
                                    , self.sql.pro, self.sql.src, self.sql.res );
                                self.sql.pro = '*';
                                self.sql.res = '';
                            end
                            
                            % append key condition to condition
                            if isempty(self.sql.res)
                                self.sql.res = sprintf(' WHERE (%s)', cond);
                            else
                                self.sql.res = sprintf('%s AND (%s)', ...
                                    self.sql.res, cond);
                            end
                        end
                    end
                end
                self.restrict(varargin{2:end});
            end
        end
        
        
        
        %--------------  FETCHING DATA  --------------------
        
        function ret = fetch(self, varargin)
            % dj.Relvar/fetch retrieve data from a relation as a struct array
            % SYNTAX:
            %    s = self.fetch       % retrieve primary key attributes only
            %    s = self.fetch('*')  % retrieve all attributes
            %    s = self.fetch('attr1','attr2',...) - retrieve primary key
            %       attributes and additional listed attributes.
            %
            % The specification of attributes 'attri' follows the same
            % conventions as in dj.Relvar.pro, including renamed
            % attributed, and computed arguments.  In particular, if the second
            % input argument is another relvar, the computed arguments can
            % include summary operations on the attrs of the second relvar.
            %
            % For example:
            %   s = R.fetch(Q, 'count(*)->n');
            % Here s(i).n will contain the number of tuples in Q matching
            % the ith tuple in R.
            %
            % If the last input argument is numerical, the number of
            % retrieved tuples will be limited to that number.
            % If two numerical arguments trail the argument list, then the
            % first is used as the starting index.
            %
            % For example:
            %    s = R.fetch('*', 100);        % tuples 1-100 from R
            %    s = R.fetch('*', 1, 100);     % still tuples 1-100
            %    s = R.fetch('*', 101, 100);   % tuples 101-200
            %
            % The numerical indexing into the relvar is a deviation from
            % relational theory and should be reserved for special cases only.
            %
            % See also dj.Relvar.pro, dj.Relvar/fetch1, dj.Relvar/fetchn
            
            
            [limit, args] = dj.Relvar.getLimitClause(varargin{:});
            self = pro(self, args{:});
            ret = self.schema.query(sprintf('SELECT %s FROM %s%s%s', ...
                self.sql.pro, self.sql.src, self.sql.res, limit));
            ret = dj.utils.structure2array(ret);
        end
        
        
        
        function varargout = fetch1(self, varargin)
            % dj.Relvar/fetch1 same as dj.Relvat/fetch but each field is
            % retrieved into a separate output variable.
            % Use fetch1 when you know that the relvar contains exactly one tuple.
            % The attribute list is specified the same way as in
            % dj.Relvar/fetch but wildcards '*' are not allowed.
            % The number of specified attributes must exactly match the number
            % of output arguments.
            %
            % Examples:
            %    v1 = R.fetch1('attr1');
            %    [v1,v2,qn] = R.fetch1(Q,'attr1','attr2','count(*)->n')
            %
            % See also dj.Relvar.fetch, dj.Relvar/fetchn, dj.Relvar/pro
            
            % validate input
            attrs = varargin(cellfun(@ischar, varargin));
            assert(nargout==length(attrs) || (nargout==0 && length(attrs)==1),...
                'The number of outputs must match the number of requested attributes')
            assert( ~any(strcmp(attrs,'*')), '''*'' is not allwed in fetch1()')
            
            s = self.fetch(varargin{:});
            assert(isscalar(s), 'fetch1 can only retrieve a single existing tuple.')
            
            % copy into output arguments
            varargout = cell(length(attrs));
            for iArg=1:length(attrs)
                name = regexp(attrs{iArg}, '(\w+)\s*$', 'tokens');
                varargout{iArg} = s.(name{1}{1});
            end
        end
        
        
        
        function varargout = fetchn(self, varargin)
            % dj.Relvar/fetchn same as dj.Relvar/fetch1 but can fetch
            % values from multiple tuples.  Unlike fetch1, string and
            % blob values are retrieved as matlab cells.
            %
            % See also dj.Relvar/fetch1, dj.Relvar/fetch, dj.Relvar/pro
            
            % validate input
            attrs = varargin(cellfun(@ischar, varargin));
            assert(nargout==length(attrs) || (nargout==0 && length(attrs)==1), ...
                'The number of outputs must match the number of requested attributes');
            assert( ~any(strcmp(attrs,'*')), '''*'' is not allwed in fetchn()');
            
            [limit, args] = dj.Relvar.getLimitClause(varargin{:});
            
            % submit query
            self = self.pro(args{:});
            ret = self.schema.query(sprintf('SELECT %s FROM %s%s%s',...
                self.sql.pro, self.sql.src, self.sql.res, limit));
            
            % copy into output arguments
            varargout = cell(length(attrs));
            for iArg=1:length(attrs)
                % if renamed, use the renamed attribute
                name = regexp(attrs{iArg}, '(\w+)\s*$', 'tokens');
                varargout{iArg} = ret.(name{1}{1});
            end
        end
        
        
        
        function insert(self, tuples, command)
            % insert an array of tuples directly into the table
            %
            % The input argument tuples must a structure array with field
            % names exactly matching those in the table.
            %
            % The optional argument 'command' allows replacing the MySQL
            % command from the default INSERT to INSERT IGNORE or REPLACE.
            %
            % Duplicates, unmatched attrs, or missing required attrs will
            % cause an error, unless command is specified.
            
            assert(~isempty(self.tab), 'Cannot insert into a derived relation')
            assert(isstruct(tuples), 'Tuples must be a non-empty structure array')
            if isempty(tuples)
                return
            end
            if nargin<=2
                command = 'INSERT';
            end
            assert(any(strcmpi(command,{'INSERT', 'INSERT IGNORE', 'REPLACE'})), ...
                'invalid insert command')
            
            % validate attrs
            fnames = fieldnames(tuples);
            found = ismember(fnames,{self.attrs.name});
            if ~all(found)
                error('Field %s is not found in the table %s', ...
                    fnames{find(~found,1,'first')}, class(self));
            end
            
            % form query
            ix = ismember({self.attrs.name}, fnames);
            for tuple=tuples(:)'
                queryStr = '';
                blobs = {};
                for i = find(ix)
                    v = tuple.(self.attrs(i).name);
                    if ~isempty(v)  % empty values are treated as unspecified values
                        if self.attrs(i).isString
                            assert(ischar(v), ...
                                'The field %s must be a character string', ...
                                self.attrs(i).name)
                            if isempty(v)
                                queryStr = sprintf('%s`%s`="",', ...
                                    queryStr, self.attrs(i).name);
                            else
                                queryStr = sprintf('%s`%s`="{S}",', ...
                                    queryStr,self.attrs(i).name);
                                blobs{end+1} = v;  %#ok<AGROW>
                            end
                        elseif self.attrs(i).isBlob
                            queryStr = sprintf('%s`%s`="{M}",', ...
                                queryStr,self.attrs(i).name);
                            if islogical(v) % mym doesn't accept logicals
                                v = uint8(v);
                            end
                            blobs{end+1} = v;    %#ok<AGROW>
                        else
                            if islogical(v)  % mym doesn't accept logicals
                                v = uint8(v);
                            end
                            assert(isscalar(v) && isnumeric(v),...
                                'The field %s must be a numeric scalar value', ...
                                self.attrs(i).name)
                            if ~isnan(v)  % nans are not passed: assumed missing.
                                queryStr = sprintf('%s`%s`=%1.16g,',...
                                    queryStr, self.attrs(i).name, v);
                            end
                        end
                    end
                end
                
                % issue query
                self.schema.query(sprintf('%s `%s`.`%s` SET %s', ...
                    command, self.schema.dbname, self.tab.info.name, ...
                    queryStr(1:end-1)), blobs{:})
            end
        end
        
        
        
        function inserti(self, tuples)
            % insert tuples but ignore errors. This is useful for rare
            % applications when duplicate entries should be quitely
            % discarded, for example.
            insert(self, tuples, 'INSERT IGNORE')
        end
    
    
    
        function update(self, attrname, value)
            % dj.Relvar/update - update an existing tuple
            % Updates can cause violations of referential integrity and should
            % not be used routinely.
            %
            % Safety constraints:
            %    1. self must contain exactly one tuple
            %    2. the update attribute must not be in primary key
            % 
            % EXAMPLES:
            %   update(v2p.Mice(key), 'mouse_dob',   '2011-01-01')
            %   update(v2p.Scan(key), 'lens', NaN)   % set numeric value to NULL
            %   update(v2p.Stat(key), 'img', [])  % set blob value to NULL 
            
            assert(~isempty(self.tab),  'Cannot insert into a derived relation')
            assert(count(self)==1, 'Update is only allowed on one tuple at a time for now')
            ix = find(strcmp(attrname,{self.attrs.name}));
            assert(numel(ix)==1, 'invalid attribute name')
            assert(~self.attrs(ix).iskey, 'cannot update a key value. Use insert(..,''REPLACE'') instead')
            
            switch true
                case self.attrs(ix).isString
                    assert(ischar(value), 'Value must be a string')
                    queryStr = '"{S}"';
                    value = {value};
                case self.attrs(ix).isBlob
                    if isempty(value) && self.attrs(ix).isnullable
                        queryStr = NULL;
                        value = {};
                    else
                        queryStr = '"{M}"';
                        if islogical(value)
                            value = uint8(value);
                        end
                        value = {value};
                    end
                case self.attrs(ix).isNumeric
                    if islogical(value)
                        value = uint8(valuealue);
                    end
                    assert(isscalar(value) && isnumeric(value), 'Numeric value must be scalar')
                    if isnan(value)
                        assert(self.attrs(ix).isnullable, ...
                            'attribute `%s` is not nullable. NaNs not allowed', attrname)
                        queryStr = 'NULL';
                        value = {};
                    else
                        queryStr = sprintf('%1.16g',value);
                        value = {};
                    end
                otherwise
                    error 'Invalid condition: report to DataJoint developers'
            end
            queryStr = sprintf('UPDATE %s SET `%s`=%s%s', self.sql.src, ...
                attrname, queryStr, self.sql.res);
            self.schema.query(queryStr, value{:})
        end        
    end    
    
    
    
    
    methods(Access=private)
        
        function reset(self)
            % initialize or reinitialize the base relvar.
            % reset is executed when at construction and then again if
            % table definitions have changed.
            if isempty(self.attrs) || ~isempty(self.tab) 
                self.schema = self.tab.schema;
                self.attrs = self.tab.attrs;
                self.sql.pro = '*';
                if ~isfield(self.sql, 'res')
                    self.sql.res = '';
                end
                self.sql.src = sprintf('`%s`.`%s`', ...
                    self.schema.dbname, self.tab.info.name);
            end
        end

        
        function semijoin(R1, R2)
            % relational natural semijoin performed in place.
            % The R1.semjoin(R2) contains all the tuples of R1 that have matching tuples in R2.
            %
            %  Syntax: r1.semijoin(r2)
            %
            % For technical details, see
            %   http://dev.mysql.md/doc/refman/5.4/en/semi-joins.html
            %
            % Semijoin is performed on common non-nullable nonblob attributes
            
            % update expression
            
            commonIllegal = intersect( ...
                {R1.attrs([R1.attrs.isBlob]).name},...
                {R2.attrs([R2.attrs.isBlob]).name});
            if ~isempty(commonIllegal)
                error('Attribute ''%s'' is a blob and cannot be compared. You may project it out first.',...
                    commonIllegal{1})
            end
            
            commonAttrs = intersect({R1.attrs.name},{R2.attrs.name});
            
            % if commonAttrs is empty, R1 is unchanged
            if ~isempty(commonAttrs)
                commonAttrs = sprintf( ',%s', commonAttrs{:} );
                commonAttrs = commonAttrs(2:end);
                if ~strcmp(R1.sql.pro,'*')
                    R1.sql.src = sprintf('(SELECT %s FROM %s%s) as r1',...
                        R1.sql.pro, R1.sql.src, R1.sql.res);
                    R1.sql.pro = '*';
                    R1.sql.res = '';
                end
                if isempty(R1.sql.res)
                    word = 'WHERE';
                else
                    word = 'AND';
                end
                if strcmp(R2.sql.pro,'*')
                    R1.sql.res = sprintf( '%s %s (%s) IN (SELECT %s FROM %s%s)', ...
                        R1.sql.res, word, commonAttrs, commonAttrs, R2.sql.src, R2.sql.res);
                else
                    R1.sql.res = sprintf( '%s %s (%s) IN (SELECT %s from (SELECT %s FROM %s%s) as r2)', ...
                        R1.sql.res,word,commonAttrs,commonAttrs,R2.sql.pro,R2.sql.src,R2.sql.res);
                end
            end
        end
        
        
        
        function cond = struct2cond(self, key)
            if length(key)>1
                % combine multiple keys into one condition
                c1 = self.struct2cond(key(1));
                cond = self.struct2cond(key(2:end));
                if ~isempty(c1)
                    cond = sprintf('%s OR %s', c1, cond);
                end
            else
                % convert the structure key into an SQL condition (string)
                keyFields = fieldnames(key)';
                foundAttributes = ismember(keyFields, {self.attrs.name});
                word = '';
                cond = '';
                for field = keyFields(foundAttributes)
                    value = key.(field{1});
                    if ~isempty(value)
                        iField = find(strcmp(field{1}, {self.attrs.name}));
                        assert(~self.attrs(iField).isBlob,...
                            'The key must not include blob attrs.');
                        if self.attrs(iField).isString
                            assert( ischar(value), ...
                                'Value for key.%s must be a string', field{1})
                            value=sprintf('"%s"',value);
                        else
                            assert(isnumeric(value), ...
                                'Value for key.%s must be numeric', field{1});
                            value=sprintf('%1.16g',value);
                        end
                        cond = sprintf('%s%s`%s`=%s', ...
                            cond, word, self.attrs(iField).name, value);
                        word = ' AND';
                    end
                end
            end
        end
        
        
        
        function [include,aliases,computedAttrs] = parseAttrList(self, attrList)
            % This is a helper function for dj.Revlar.pro.
            % Parse and validate the list of relation attributes in attrList.
            % OUTPUT:
            %    include: a logical array marking which attrs of self must be included
            %    aliases: a string array containing aliases for each of self's attrs or '' if not aliased
            %  computedAttrs: pairs of SQL expressions and their aliases.
            %
            
            include = [self.attrs.iskey];  % implicitly include the primary key
            aliases = repmat({''},size(self.attrs));  % one per each self.attrs
            computedAttrs = {};
            
            for iAttr=1:length(attrList)
                if strcmp('*',attrList{iAttr})
                    include = include | true;   % include all attributes
                else
                    % process a renamed attribute
                    toks = regexp( attrList{iAttr}, ...
                        '^([a-z]\w*)\s*->\s*(\w+)', 'tokens' );
                    if ~isempty(toks)
                        ix = find(strcmp(toks{1}{1},{self.attrs.name}));
                        assert(length(ix)==1,'Attribute `%s` not found',toks{1}{1});
                        include(ix)=true;
                        assert(~ismember(toks{1}{2},aliases) ...
                            && ~ismember(toks{1}{2},{self.attrs.name})...
                            ,'Duplicate attribute alias `%s`',toks{1}{2});
                        aliases{ix}=toks{1}{2};
                    else
                        % process a computed attribute
                        toks = regexp( attrList{iAttr}, ...
                            '(.*\S)\s*->\s*(\w+)', 'tokens' );
                        if ~isempty(toks)
                            computedAttrs(end+1,:) = toks{:};   %#ok<AGROW>
                        else
                            % process a regular attribute
                            ix = find(strcmp(attrList{iAttr},{self.attrs.name}));
                            assert(length(ix)==1,'Attribute `%s` not found', ...
                                attrList{iAttr});
                            include(ix)=true;
                        end
                    end
                end
            end
        end
    end
    
    
    
    methods(Access=private, Static)
        
        function [limit, args] = getLimitClause(varargin)
            % makes the SQL limit clause from fetch() input arguments.
            % If the last one or two inputs are numeric, a LIMIT clause is
            % created.
            limit = '';
            args = varargin;
            if nargin>0 && isnumeric(args{end})
                if nargin>1 && isnumeric(args{end-1})
                    limit = sprintf(' LIMIT %d, %d', args{end-1:end});
                    args(end-1:end) = [];
                else
                    limit = sprintf(' LIMIT %d', varargin{end});
                    args(end) = [];
                end
            end
        end
        
    end
    
end
