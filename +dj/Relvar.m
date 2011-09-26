% Relvar: a relational variable supporting relational operators
% A relvar may be a base relation associated with a table or a derived
% relation.
%
% SYNTAX:
%    obj = dj.Relvar;                % abstract, must have derived property 'table' of type dj.Table
%    obj = dj.Relvar(anoterRelvar);  % copy constructor, strips derived properties
%    obj = dj.Relvar(tableObj);      % base relvar without a derived class, for internal use only

% Dimitri Yatsenko, 2009-09-10, 2011-09-16


% classdef Revlar < matlab.mixin.Copyable   % R2011
classdef Relvar < dynamicprops   % R2009a
    
    properties(SetAccess = private)
        schema     % handle to the schema object
        primaryKey % list of primary key fields
        fields     % list of fieldnames
        expression % the MATLAB expression to construct this relation
    end
    
    properties(Access = private)
        sql        % sql statement: source, projection, and restriction clauses
        precedence = 0   % 0 (base), -1='*', -2='-', -3='&'
    end
    
    
    methods
        function self = Relvar(copyObj)
            switch true
                
                case nargin==0 && ~isempty(self.findprop('table'))
                    % normal constructor with no parameters.
                    % The derived class must have a 'table' property of type dj.Table
                    self.schema = self.table.schema;
                    self.primaryKey = self.table.primaryKey;
                    self.fields = self.table.fields;
                    self.sql.pro = '*';
                    self.sql.res = '';
                    self.sql.src = sprintf('`%s`.`%s`', ...
                        self.table.schema.dbname, self.table.info.name);
                    self.expression = class(self);
                    
                case nargin==1 && isa(copyObj, 'dj.Relvar')
                    % copy constructor
                    self.schema = copyObj.schema;
                    self.primaryKey = copyObj.primaryKey;
                    self.sql = copyObj.sql;
                    self.fields = copyObj.fields;
                    self.expression = copyObj.expression;
                    
                case nargin==1 && isa(copyObj, 'dj.Table')
                    % initialization from a dj.Table, for housekeeping use only
                    self.schema = copyObj.schema;
                    self.primaryKey = copyObj.primaryKey;
                    self.fields = copyObj.fields;
                    self.sql.pro = '*';
                    self.sql.res = '';
                    self.sql.src = sprintf('`%s`.`%s`', ...
                        copyObj.schema.dbname, copyObj.info.name);
                    self.expression = '<temporary>'; % no valid expression without subclassing
                    
                otherwise
                    error 'invalid initatlization'
            end
        end
        
        
        
        function display(self, justify)
            % DJ/disp - displays the contents of a relation.
            % Only non-blob fields of the first several tuples are shown. The total
            % number of tuples is printed at the end.
            justify = nargin==1 || justify;
            tic
            display@handle(self)
            % print header
            fprintf \n
            ix = find( ~[self.fields.isBlob] );  % fields to display
            fprintf('  %12.12s', self.fields(ix).name);
            fprintf \n
            
            % print rows
            maxRows = 24;
            tuples = self.fetch(self.fields(ix).name,maxRows+1);
            nTuples = length(self);
            
            if nTuples>0
                for s = tuples(1:min(end,maxRows))'
                    for iField = ix
                        v = s.(self.fields(iField).name);
                        if isnumeric(v)
                            fprintf('  %12g',v);
                        else
                            if justify
                                fprintf('  %12.12s',v);
                            else
                                fprintf('  ''%12s''', v);
                            end
                        end
                    end
                    fprintf('\n');
                end
            end
            if nTuples > maxRows
                for iField = ix
                    fprintf('  %12s','.....');
                end
                fprintf('\n');
            end
            
            % print the total number of tuples
            fprintf('%d tuples (%.3g s)\n\n', nTuples, toc );
        end
        
        
        
        function n = length(self)
            % return the cardinality of relation self
            if strcmp(self.sql.pro, '*')
                n = self.schema.query(sprintf('SELECT count(*) as n FROM %s%s', self.sql.src, self.sql.res));
            else
                n = self.schema.query(sprintf('SELECT count(*) as n FROM (SELECT DISTINCT %s FROM %s%s) as r', ...
                    self.sql.pro, self.sql.src, self.sql.res));
            end
            n=n.n;
        end
        
        
        
        function ret = isempty(self)
            ret = self.length==0;
        end
        
        
        function del(self, doPrompt)
            % del(self)  - remove all tuples in relation self from its base relation.
            %
            % EXAMPLE:
            %   del(Scans) -- delete all tuples from table Scans
            %   del(Scans('mouse_id=12')) -- delete all Scans for mouse 12
            %   del(Scans-Cells)  -- delete all tuples from table Scans
            %           that do not have a matching tuples in table Cells
            
            assert(~isempty(findprop(self,'table')) && isa(self.table, 'dj.Table'), ...
                'Cannot delete from a derived relation');
            
            doPrompt = nargin<2 || doPrompt;
            self.schema.cancelTransaction  % roll back any uncommitted transaction
            n = self.length;
            doDelete = true;
            if n == 0
                disp('Nothing to delete')
            else
                if ismember(self.table.info.tier, {'manual','lookup'})
                    warning('DataJoint:del',...
                        'About to delete from a table containing manual data. Proceed at your own risk.')
                else
                    doDelete = ~isempty(findprop(self,'popRel')) || strcmp('yes', input(...
                        'Attempting to delete from a subtable: risk violating integrity constraints? yes/no? >> '...
                        ,'s'));
                end
            end
            
            doDelete = ~doPrompt || doDelete && strcmpi('yes',input(sprintf(...
                'Delete %d records from %s? yes/no >> ',...
                n, class(self)), 's'));
            
            if doDelete
                self.schema.query(sprintf('DELETE FROM %s%s', self.sql.src, self.sql.res))
            else
                disp 'Nothing deleted'
            end
        end
        
        
        
        
        
        %%%%%%%%%%%%%%%%%%  RELATIONAL OPERATORS %%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function self = times(self, arg)
            % this alias is for backward compatibility
            self = self & arg;
        end
        
        
        function newSelf = copy(self)   % remove this function in R2011
            if isa(self, 'matlab.mixin.Copyable')
                newSelf = copy@matlab.mixinCopyable(self);
            else
                newSelf = dj.Relvar(self);
                if ~isempty(self.findprop('table'));
                    newSelf.addprop('table');
                    newSelf.table = self.table;
                end
            end
        end
        
        
        
        function self = and(self, arg)
            % relational restriction
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
            
            self = self.copy;  % uncomment in R2011
            
            self.restrict(arg)
        end
        
        
        function self = pro(self, varargin)
            % self=pro(self,attr1,...,attrn) - project relation self onto its attributes
            % self=pro(self,Q,attr1,...,attrn) - project relation self onto its attributes and
            % onto aggregate attributes of relation Q.
            %
            % INPUTS:
            %    'attr1',...,'attrn' is a comma-separated string of relation attributes
            % onto which to project the relation self.
            %
            % Primary key attributes are included implicitly and cannot be excluded.
            %
            % To rename an attribute, list it in the form 'old_name->new_name'.
            %
            % Computed attributes are always aliased:
            % 'datediff(exp_date,now())->days_ago'
            %
            % When attr1 is '*', all attributes are included. Attributes can then be
            % excluded by prefixing them with a tilde '~'.
            %
            % The order of attributes in the attribute list does not affect the
            % ordering of attributes in the resulting relation.
            %
            % Example 1. Construct relation r2 containing only the primary keys of r1:
            %    >> r2 = pro(r1);
            %
            % Example 2. Construct relation r3 which contains values for 'operator'
            %    and 'anesthesia' for every tuple in r1:
            %    >> r3=pro(r1,'operator','anesthesia');
            %
            % Example 3. Rename attribute 'anesthesia' to 'anesth' in relation r1:
            %    >> r1 = pro( r1, '*','anesthesia->anesth');
            %
            % Example 4. Add field mouse_age in days to relation r1 that has the field mouse_dob:
            %    >> r1 = pro( r1, '*', 'datediff(now(),mouse_dob)->mouse_age' );
            %
            % Example 5. Add field 'n' which contains the count of matching tuples in r2
            % for every tuple in r1. Also add field 'avga' which contains the average
            % value of field 'a' in r2.
            %    >> r1 = pro( r1, r2, '*','count(*)->n','avg(a)->avga');
            % You may use the following aggregation functions: max,min,sum,avg,variance,std,count
            
            self = dj.Relvar(self);  % copy into a derived relation
            
            params = varargin;
            isGrouped = nargin>1 &&  isa(params{1},'dj.Relvar');
            if isempty(params)
                self.expression = sprintf('pro(%s)', self.expression);
            else
                if isGrouped
                    Q = params{1};
                    params(1)=[];
                    str = sprintf(',''%s''',params{:});
                    self.expression = sprintf('pro(%s,%s,%s)',...
                        self.expression, Q.expression,str(2:end));
                else
                    str = sprintf(',''%s''',params{:});
                    self.expression = sprintf('pro(%s,%s)',...
                        self.expression, str(2:end));
                end
            end
            self.precedence = 0;
            
            assert(iscellstr(params), 'attributes must be provided as a list of strings');
            
            [include,aliases,computedAttrs] = parseAttrList(self, params);
            
            if ~all(include) || ~all(cellfun(@isempty,aliases)) || ~isempty(computedAttrs)
                self.fields = self.fields(include);
                aliases = aliases(include);
                self.primaryKey={self.fields([self.fields.iskey]).name};
                
                % add selected attributes
                fieldList = '';
                c = '';
                for iField=1:length(self.fields)
                    fieldList=sprintf('%s%s`%s`',fieldList,c,self.fields(iField).name);
                    if ~isempty(aliases{iField})
                        self.fields(iField).name=aliases{iField};
                        fieldList=sprintf('%s as `%s`',fieldList,aliases{iField});
                    end
                    c = ',';
                end
                
                % add computed attributes
                for iComp = 1:size(computedAttrs,1)
                    self.fields(end+1) = struct(...
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
                    fieldList=sprintf('%s%s %s as `%s`',fieldList,c,computedAttrs{iComp,1},computedAttrs{iComp,2});
                    c=',';
                end
                
                % update query
                if ~strcmp(self.sql.pro,'*')
                    self.sql.src = sprintf('(SELECT %s FROM %s%s) as r',self.sql.pro,self.sql.src,self.sql.res);
                    self.sql.res = '';
                end
                self.sql.pro = fieldList;
                
                if isGrouped
                    keyStr = sprintf(',%s',self.primaryKey{:});
                    if isempty(Q.sql.res) && strcmp(Q.sql.pro,'*')
                        self.sql.src = sprintf('(SELECT %s FROM %s NATURAL JOIN %s%s GROUP BY %s) as q%s'...
                            , self.sql.pro, self.sql.src, Q.sql.src, self.sql.res, keyStr(2:end), char(rand(1,3)*26+65) );
                    else
                        self.sql.src = sprintf('(SELECT %s FROM %s NATURAL JOIN (SELECT %s FROM %s%s) as q%s GROUP BY %s) as q%s'...
                            , self.sql.pro, self.sql.src, Q.sql.pro, Q.sql.src, Q.sql.res, self.sql.res, keyStr(2:end),char(rand(1,3)*26+65) );
                    end
                    self.sql.pro = '*';
                    self.sql.res = '';
                end
            end
        end
        
        
        function R1 = rdivide(R1, R2)
            warning('datajoint:deprecation',...
                'Use R1-R2 instead of R1./R2. dj.Relvar/rdivide will be deprecated in next release')
            R1 = R1 - R2;
        end
        
        
        
        function R1 = mtimes(R1,R2)
            %  DJ/mtimes - relational natural join.
            %  Syntax: r3=r1*r2
            
            % check that the joined relations do not have common fields that are blobs or opional
            commonIllegal = intersect( ...
                {R1.fields([R1.fields.isnullable] | [R1.fields.isBlob]).name},...
                {R2.fields([R2.fields.isnullable] | [R2.fields.isBlob]).name});
            if ~isempty(commonIllegal)
                error('Attribute ''%s'' is optional or a blob. Exclude it from one of the relations before joining.', commonIllegal{1})
            end
            
            R1 = dj.Relvar(R1);
            prec = -1;
            R1.expression = sprintf('%s*%s', R1.brace(prec), R2.brace(prec+1));
            R1.precedence = prec;
            
            % merge field lists
            [trashs,ix] = setdiff({R2.fields.name},{R1.fields.name});
            R1.fields = [R1.fields;R2.fields(sort(ix))];
            R1.primaryKey = {R1.fields([R1.fields.iskey]).name}';
            
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
                R1.sql.src = sprintf( '%s (SELECT %s FROM %s%s) as `r2%s`',R1.sql.src,R2.sql.pro,R2.sql.src,R2.sql.res,alias);
            end
            
        end
        
        
        function R1 = minus(R1,R2)
            % DJ/rdivide - relational natural semidifference.
            % r1./r2 contains all tuples in r1 that do not have matching tuples in r2.
            %
            %  Syntax: r3=r1./r2
            %
            % Semidifference is performed on common non-nullable nonblob attributes
            
            R1 = R1.copy; % shallow copy a the original object, preserves its identity
            prec = -2;
            R1.expression = sprintf('%s-%s', R1.brace(prec), R2.brace(prec+1));
            R1.precedence = prec;
            
            commonIllegal = intersect( ...
                {R1.fields([R1.fields.isnullable] | [R1.fields.isBlob]).name},...
                {R2.fields([R2.fields.isnullable] | [R2.fields.isBlob]).name});
            if ~isempty(commonIllegal)
                error('Attribute ''%s'' is optional or a blob and cannot be compared. You may project it out first.',...
                    commonIllegal{1})
            end
            
            commonAttrs = intersect({R1.fields.name}, {R2.fields.name});
            
            if isempty(commonAttrs)
                % commonAttrs is empty, R1 is the empty relation
                R1.sql.res = [R1.sql.res ' WHERE FALSE'];
            else
                % update R1's query to the semidifference of R1 and R2
                commonAttrs = sprintf( ',%s', commonAttrs{:} );
                commonAttrs = commonAttrs(2:end);
                if ~strcmp(R1.sql.pro,'*')
                    R1.sql.src = sprintf('(SELECT %s FROM %s%s) as r1',R1.sql.pro,R1.sql.src,R1.sql.res);
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
                            'restricting condition must be a structure, an string, or another relation')
                        
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
                            self.expression = sprintf('%s & ''%s''',...
                                self.expression, cond);
                            self.precedence = -3;
                        end
                    end
                end
                self.restrict(varargin{2:end});
            end
        end
        
        
        
        %--------------  FETCHING DATA  --------------------
        
        function ret = fetch(self, varargin)
            % Relvar/fetch - retrieve data from a relation as a struct array
            % SYNTAX:
            %    s = fetch(self)       %% retrieve primary key attributes only
            %    s = fetch(self,'*')   %% retrieve all attributes
            %    s = fetch(self,'attr1','attr2',...) - retrieve primary key
            %       attributes and additional listed attributes.
            LIMIT = '';
            if nargin>1 && isnumeric(varargin{end})
                if nargin>2 && isnumeric(varargin{end-1})
                    LIMIT = sprintf(' LIMIT %d, %d', varargin{end-1:end});
                    varargin(end-1:end) = [];
                else
                    LIMIT = sprintf(' LIMIT %d', varargin{end});
                    varargin(end) = [];
                end
            end
            self = pro(self, varargin{:});
            ret = self.schema.query(sprintf('SELECT %s FROM %s%s%s', ...
                self.sql.pro, self.sql.src, self.sql.res, LIMIT));
            ret = dj.utils.structure2array(ret);
        end
        
        
        
        function varargout = fetch1(self, varargin)
            % Relvar/fetch1 - retrieve attributes from a single tuple in a
            % relation into separate variables.
            % Use fetch1 when you know that self contains at most one tuple.
            % Strings are retrieves as character arrays.
            %
            % SYNTAX:
            %    [f1,f2,..,fk] = fetch1( self, 'attr1','attr2',...,'attrk' )
            
            % validate input
            if nargin>=2 && ...
                    (isa(varargin{1}, 'dj.Relvar') || isa(varargin{1}, 'dj.Table'))
                attrs = varargin(2:end);
            else
                attrs = varargin;
            end
            assert(nargout==length(attrs) || (nargout==0 && length(attrs)==1),...
                'The number of outputs must match the number of requested attributes');
            assert( ~any(strcmp(attrs,'*')), '''*'' is not allwed in fetch1()');
            
            s = fetch(self, varargin{:});
            assert(isscalar(s),'fetch1 can only retrieve a single existing tuple.');
            
            % copy into output arguments
            for iArg=1:length(attrs)
                name = regexp(attrs{iArg}, '(^|->)\s*(\w+)', 'tokens');  % if aliased, use the alias
                if length(name)==2
                    name = name{2}{2};
                else
                    name = name{1}{2};
                end
                varargout{iArg}=s.(name);
            end
        end
        
        
        function varargout = fetchn(self, varargin)
            % DJ/fetch1 - retrieve attribute values from multiple tuples in relation self.
            % Nonnumeric results are returned as cell arrays.
            %
            % Syntax:
            %    [v1,v2,..,vk] = fetch1(self, 'attr1','attr2',...,'attrk')
            %    [v1,v2,..,vk] = fetch1(self, Q, 'attr1', 'attr2',...,'attrk');
            
            
            % validate input
            if nargin>=2 && isa(varargin{1},'dj.Relvar')
                attrs = varargin(2:end);
            else
                attrs = varargin;
            end
            assert(nargout==length(attrs) || (nargout==0 && length(attrs)==1), ...
                'The number of outputs must match the number of requested attributes');
            assert( ~any(strcmp(attrs,'*')), '''*'' is not allwed in fetchn()');
            
            % submit query
            self = pro(self,varargin{:});
            ret=query(self,...
                sprintf('SELECT %s FROM %s%s',...
                self.sql.pro, self.sql.src, self.sql.res));
            
            % copy into output arguments
            for iArg=1:length(attrs)
                name = regexp(attrs{iArg}, '(^|->)\s*(\w+)', 'tokens');  % if renamed, use the renamed attribute
                name = name{end}{2};
                assert(isfield(ret,name),'Field %s not found', name );
                varargout{iArg} = ret.(name);
            end
        end
        
        
        
        
        
        
        function insert(self, tuples)
            % insert tuples directly into the table with no checks.
            %
            % The input argument tuples must a structure array with field
            % names exactly matching those in the table.
            %
            % Duplicates, unmathed fields, or missing required fields will
            % cause an error.
            %
            % See also dj.Relvar/inserti.
            
            assert(~isempty(findprop(self,'table')), ...
                'Cannot insert into a derived relation')
            assert(isstruct(tuples), ...
                'Tuples must be a non-empty structure array')
            if isempty(tuples)
                return
            end
            
            % validate fields
            fnames = fieldnames(tuples);
            found = ismember(fnames,{self.fields.name});
            if ~all(found)
                error('Field %s is not found in the table %s', ...
                    fnames{find(~found,1,'first')}, class(self));
            end
            
            % form query
            ix = ismember({self.fields.name}, fnames);
            for tuple=tuples(:)'
                queryStr = '';
                blobs = {};
                for i = find(ix)
                    v = tuple.(self.fields(i).name);
                    if self.fields(i).isString
                        assert( ischar(v), 'The field %s must be a character string', self.fields(i).name );
                        if isempty(v)
                            queryStr = sprintf( '%s`%s`="",', queryStr, self.fields(i).name);
                        else
                            queryStr = sprintf( '%s`%s`="{S}",', queryStr,self.fields(i).name );
                            blobs{end+1} = v;                                       %#ok<AGROW>
                        end
                    elseif self.fields(i).isBlob
                        queryStr = sprintf( '%s`%s`="{M}",', queryStr,self.fields(i).name );
                        if islogical(v) % mym doesn't accept logicals
                            v = uint8(v);
                        end
                        blobs{end+1} = v;                                       %#ok<AGROW>
                    else
                        if islogical(v)  % mym doesn't accept logicals
                            v = uint8(v);
                        end
                        assert( isscalar(v) && isnumeric(v),...
                            'The field %s must be a numeric scalar value', self.fields(i).name );
                        if ~isnan(v)  % nans are not passed: assumed missing.
                            queryStr = sprintf( '%s`%s`=%1.16g,',...
                                queryStr, self.fields(i).name, v);
                        end
                    end
                end
                
                % issue query
                self.schema.query(sprintf('INSERT `%s`.`%s` SET %s', ...
                    self.schema.dbname, self.table.info.name, queryStr(1:end-1)), blobs{:})
            end
        end
    end
    
    
    methods(Access=private)
        
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
                {R1.fields([R1.fields.isBlob]).name},...
                {R2.fields([R2.fields.isBlob]).name});
            if ~isempty(commonIllegal)
                error('Attribute ''%s'' is optional or a blob and cannot be compared. You may project it out first.',...
                    commonIllegal{1})
            end
            
            commonAttrs = intersect({R1.fields.name},{R2.fields.name});
            
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
                prec = -3;
                R1.expression = sprintf('%s & %s', R1.brace(prec), R2.brace(prec+1));
                R1.precedence = prec;
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
                foundAttributes = ismember(keyFields, {self.fields.name});
                word = '';
                cond = '';
                for field = keyFields(foundAttributes)
                    value = key.(field{1});
                    if ~isempty(value)
                        iField = find(strcmp(field{1}, {self.fields.name}));
                        assert(~self.fields(iField).isBlob,...
                            'The key must not include blob fields.');
                        if self.fields(iField).isString
                            assert( ischar(value), ...
                                'Value for key.%s must be a string', field{1})
                            value=sprintf('"%s"',value);
                        else
                            assert(isnumeric(value), ...
                                'Value for key.%s must be numeric', field{1});
                            value=sprintf('%1.16g',value);
                        end
                        cond = sprintf('%s%s`%s`=%s', cond, word, self.fields(iField).name, value);
                        word = ' AND';
                    end
                end
            end
        end
        
        
        
        function [include,aliases,computedAttrs] = parseAttrList(self, attrList)
            %{
            This is a helper function for dj.Revlar.pro.
            Parse and validate the list of relation attributes in attrList.
            OUTPUT:
              include: a logical array marking which fields of self must be included
              aliases: a string array containing aliases for each of self's fields or '' if not aliased
              computedAttrs: pairs of SQL expressions and their aliases.
            %}
            
            include = [self.fields.iskey];  % implicitly include the primary key
            aliases = repmat({''},size(self.fields));  % one per each self.fields
            computedAttrs = {};
            
            for iAttr=1:length(attrList)
                if strcmp('*',attrList{iAttr})
                    include = include | true;   % include all attributes
                else
                    % process a renamed attribute
                    toks = regexp( attrList{iAttr}, '^([a-z]\w*)\s*->\s*(\w+)', 'tokens' );
                    if ~isempty(toks)
                        ix = find(strcmp(toks{1}{1},{self.fields.name}));
                        assert(length(ix)==1,'Attribute `%s` not found',toks{1}{1});
                        include(ix)=true;
                        assert(~ismember(toks{1}{2},aliases) && ~ismember(toks{1}{2},{self.fields.name})...
                            ,'Duplicate attribute alias `%s`',toks{1}{2});
                        aliases{ix}=toks{1}{2};
                    else
                        % process a computed attribute
                        toks = regexp( attrList{iAttr}, '(.*\S)\s*->\s*(\w+)', 'tokens' );
                        if ~isempty(toks)
                            computedAttrs(end+1,:) = toks{:};   %#ok<AGROW>
                        else
                            % process a regular attribute
                            ix = find(strcmp(attrList{iAttr},{self.fields.name}));
                            assert(length(ix)==1,'Attribute `%s` not found', attrList{iAttr});
                            include(ix)=true;
                        end
                    end
                end
            end
        end
        
        
        function str = brace(self, precedence)
            % return self.expression in parentheses if precedence > self.precedence
            str = self.expression;
            if precedence > self.precedence
                str = ['(' str ')'];
            end
        end
    end
end