% GeneralRelvar: a relational variable supporting relational operators.
% General relvars do not have a table associated with them. They
% represent a relational expression based on other relvars.

% To make the code R2009 compatible, toggle comments on the following two lines  
%classdef GeneralRelvar < dj.R2009CopyableRelvarMixin  % pre-R2011
classdef GeneralRelvar < matlab.mixin.Copyable  %post-R2011
    
    properties(Dependent, SetAccess = private)
        schema       % schema object
        header       % attributes and their properties
        sql          % sql expression
        primaryKey   % primary key attribute names
        nonKeyFields % non-key attribute names
    end
    
    properties(SetAccess=private, GetAccess=public)
        restrictions = {} % list of restrictions applied to operator output
    end
    
    properties(SetAccess=private, GetAccess=protected)
        operator          % node type: table, join, or pro
        operands = {}     % list of operands
    end
    
    methods
        function self = init(self, operator, operands, restrictions)
            self.operator = operator;
            if nargin>=3
                self.operands = operands;
            end
            if nargin>=4
                self.restrictions = restrictions;
            end
        end
        
        function header = get.header(self)
            header = self.compile();
        end
        
        function s = get.sql(self)
            [~, s] = self.compile();
        end
        
        function schema = get.schema(self)
            schema = self.getSchema();
        end
        
        function names = get.primaryKey(self)
            if isempty(self.header)
                warning('DataJoint:emptyPrimaryKey', 'empty primary key?')
                names = {};
            else
                names = {self.header([self.header.iskey]).name};
            end
        end
        
        function names = get.nonKeyFields(self)
            if isempty(self.header)
                names = {};
            else
                names = {self.header(~[self.header.iskey]).name};
            end
        end
        
        function clause = whereClause(self)
            clause = makeWhereClause(self.header, self.restrictions);
        end
        
        function display(self, justify)
            % dj.GeneralRelvar/display - display the contents of the relation.
            % Only non-blob attributes of the first several tuples are shown.
            % The total number of tuples is printed at the end.
            tic
            justify = nargin==1 || justify;
            display@handle(self)
            nTuples = self.count;
            
            header = self.header;
            
            if nTuples>0
                % print header
                ix = find( ~[header.isBlob] );  % header to display
                fprintf \n
                fprintf('  %12.12s', header(ix).name)
                fprintf \n
                maxRows = 12;
                tuples = self.fetch(header(ix).name,maxRows+1);
                
                % print rows
                for s = tuples(1:min(end,maxRows))'
                    for iField = ix
                        v = s.(header(iField).name);
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
        
        function view(self)
            % dj.Relvar/view - view the data in speadsheet form
            
            if ~self.count
                disp 'empty relation'
            else
                columns = {self.header.name};
                
                assert(~any([self.header.isBlob]), 'cannot view blobs')
                
                % specify table header
                columnName = columns;
                for iCol = 1:length(columns)
                    
                    if self.header(iCol).iskey
                        columnName{iCol} = ['<html><b><font color="black">' columnName{iCol} '</b></font></html>'];
                    else
                        columnName{iCol} = ['<html><font color="blue">' columnName{iCol} '</font></html>'];
                    end
                end
                format = cell(1,length(columns));
                format([self.header.isString]) = {'char'};
                format([self.header.isNumeric]) = {'numeric'};
                for iCol = find(strncmpi('ENUM', {self.header.type}, 4))
                    enumValues = textscan(self.header(iCol).type(6:end-1),'%s','Delimiter',',');
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
        
        
        %%%%%%%%%%%%%%%%%% FETCHING DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function n = count(self)
            % GeneralRelvar/count - the number of tuples in the relation.
            [~, sql] = self.compile(3);
            n = self.schema.conn.query(sprintf('SELECT count(*) as n FROM %s', sql));
            n=n.n;
        end
        
        
        function ret = fetch(self, varargin)
            % dj.GeneralRelvar/fetch retrieve data from a relation as a struct array
            % SYNTAX:
            %    s = self.fetch       % retrieve primary key attributes only
            %    s = self.fetch('*')  % retrieve all attributes
            %    s = self.fetch('attr1','attr2',...) - retrieve primary key
            %       attributes and additional listed attributes.
            %
            % The specification of attributes 'attri' follows the same
            % conventions as in dj.GeneralRelvar.pro, including renamed
            % attributed, and computed arguments.  In particular, if the second
            % input argument is another relvar, the computed arguments can
            % include summary operations on the header of the second relvar.
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
            % See also dj.GeneralRelvar.pro, dj.GeneralRelvar/fetch1, dj.GeneralRelvar/fetchn
            
            [limit, args] = makeLimitClause(varargin{:});
            self = self.pro(args{:});
            [header, sql] = self.compile;
            ret = self.schema.conn.query(sprintf('SELECT %s FROM %s%s', ...
                makeAttrList(header), sql, limit));
            ret = dj.struct.fromFields(ret);
        end
        
        
        function varargout = fetch1(self, varargin)
            % dj.GeneralRelvar/fetch1 same as dj.Relvat/fetch but each field is
            % retrieved into a separate output variable.
            % Use fetch1 when you know that the relvar contains exactly one tuple.
            % The attribute list is specified the same way as in
            % dj.GeneralRelvar/fetch but wildcards '*' are not allowed.
            % The number of specified attributes must exactly match the number
            % of output arguments.
            %
            % Examples:
            %    v1 = R.fetch1('attr1');
            %    [v1,v2,qn] = R.fetch1(Q,'attr1','attr2','count(*)->n')
            %
            % See also dj.GeneralRelvar.fetch, dj.GeneralRelvar/fetchn, dj.GeneralRelvar/pro
            
            % validate input
            specs = varargin(cellfun(@ischar, varargin));  %attribute specifiers
            if nargout~=length(specs) && (nargout~=0 || length(specs)~=1), ...
                    throwAsCaller(MException('DataJoint:invalidOperator', ...
                    'The number of fetch1() outputs must match the number of requested attributes'))
            end
            if isempty(specs)
                throwAsCaller(MException('DataJoint:invalidOperator',...
                    'insufficient inputs'))
            end
            if any(strcmp(specs,'*'))
                throwAsCaller(MException('DataJoint:invalidOpeator', ...
                    '"*" is not allwed in fetch1()'))
            end
            
            s = self.fetch(varargin{:});
            
            if ~isscalar(s)
                throwAsCaller(MException('DataJoint:invalidOperator', ...
                    'fetch1 can only retrieve a single existing tuple.'))
            end
            
            % copy into output arguments
            varargout = cell(length(specs));
            for iArg=1:length(specs)
                name = regexp(specs{iArg}, '(\w+)\s*$', 'tokens');
                varargout{iArg} = s.(name{1}{1});
            end
        end
        
        
        function varargout = fetchn(self, varargin)
            % dj.GeneralRelvar/fetchn same as dj.GeneralRelvar/fetch1 but can fetch
            % values from multiple tuples.  Unlike fetch1, string and
            % blob values are retrieved as matlab cells.
            %
            % See also dj.GeneralRelvar/fetch1, dj.GeneralRelvar/fetch, dj.GeneralRelvar/pro
            
            specs = varargin(cellfun(@ischar, varargin));  % attribute specifiers
            if nargout~=length(specs) && (nargout~=0 || length(specs)~=1), ...
                    throwAsCaller(MException('DataJoint:invalidOperator', ...
                    'The number of fetchn() outputs must match the number of requested attributes'))
            end
            if isempty(specs)
                throwAsCaller(MException('DataJoint:invalidOperator',...
                    'insufficient inputs'))
            end
            if any(strcmp(specs,'*'))
                throwAsCaller(MException('DataJoint:invalidOpeator', ...
                    '"*" is not allwed in fetchn()'))
            end
            [limit, args] = makeLimitClause(varargin{:});
            
            % submit query
            self = self.pro(args{:});
            [header, sql] = self.compile;
            ret = self.schema.conn.query(sprintf('SELECT %s FROM %s%s%s',...
                makeAttrList(header), sql, limit));
            
            % copy into output arguments
            varargout = cell(length(specs));
            for iArg=1:length(specs)
                % if renamed, use the renamed attribute
                name = regexp(specs{iArg}, '(\w+)\s*$', 'tokens');
                varargout{iArg} = ret.(name{1}{1});
            end
        end
        
        
        %%%%%%%%%%%%%%%%%%  RELATIONAL OPERATORS %%%%%%%%%%%%%%%%%%%%%%%%%%
        function restrict(self, varargin)
            % dj.GeneralRelvar/restrict - relational restriction in place
            % Restrictions may be provided as separate arguments or a
            % single cell array.
            % Restrictions may include sql expressions, other relvars, or
            % structure arrays.
            % Including the word 'not' in the restriction list negates one
            % restriction that follows immediately.
            % All conditions must be true for a tuple to pass.
            %
            % Examples:
            %    rel.restrict('session_date>2012-01-01', 'not', struct('anesthesia', 'urethane'))
            %    rel2.restrict(rel)    % all tuples in rel2 that at least on tuple in rel
            
            args = varargin;
            if length(args)==1 && iscell(args{1})
                args = args{1};
            end
            self.restrictions = [self.restrictions args];
        end
        
        
        function ret = and(self, arg)
            % dj.GeneralRelvar/and - relational restriction
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
            if ~iscell(arg)
                arg = {arg};
            end
            ret = self.copy; 
            ret.restrictions = [ret.restrictions arg];  
        end
        
        function ret = minus(self, arg)
            if iscell(arg)
                throwAsCaller(MException('DataJoint:invalidOperator',...
                    'Antijoin only accepts single restrictions'))
            end
            ret = self.copy;  
            ret.restrictions = [ret.restrictions {'not' arg}]; 
        end
        
        function ret = times(self, arg)
            % alias for backward compatibility
            ret = self & arg;
        end
        
        function ret = rdivide(self, arg)
            % alias for backward compatibility
            ret = self - arg;
        end
        
        function ret = pro(self, varargin)
            % dj.GeneralRelvar/pro - relational operators that modify the relvar's header:
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
            % and cannot be excluded. Thus pro(rel) simply strips all non-key header.
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
            % See also: dj.GeneralRelvar/fetch
            if nargin>2 && isa(varargin{1}, 'dj.GeneralRelvar')
                % if the first argument is a relvar, perform aggregate operator
                op = 'aggregate';
                arg = varargin(1);
                params = varargin(2:end);
            else
                op = 'pro';
                arg = [];
                params = varargin;
            end
            
            if ~iscellstr(params)
                throwAsCaller(MException('DataJoint:invalidOperotor', ...
                    'pro() requires a list of strings as attribute specs'))
            end
            
            ret = init(dj.GeneralRelvar, op, [{self} arg params]);
        end        
        
        function ret = mtimes(self, arg)
            % dj.GeneralRelvar/mtimes - relational natural join.
            %
            % SYNTAX:
            %   R3=R1*R2
            %
            % The result will contain all matching combinations of tuples
            % in R1 and tuples in R2. Two tuples make a matching
            % combination if their commonly named attributes contain the
            % same values.
            % Blobs and nullable header should not be joined on.
            % To prevent an attribute from being joined on, rename it using
            % dj.GeneralRelvar/pro's rename syntax.
            %
            % See also dj.GeneralRelvar/pro, dj.GeneralRelvar/fetch
            if nargin<=1 || ~isa(arg, 'dj.GeneralRelvar')
                throwAsCaller(MException('DataJoint:invalidOperotor', ...
                    'dj.GeneralRelvar/mtimes requires another relvar as operand'))
            end
            ret = init(dj.GeneralRelvar, 'join', {self arg});
        end
        
        function length(self)
            % prohibit the use of length() to avoid ambiguity
            throwAsCaller(MException('DataJoint:invalidOperator',....
                'dj.GeneralRelvar/length is not defined Use count()'))
        end
        
        function isempty(self)
            % prohibit the use of isempty() tp avoid ambiguity
            throwAsCaller(MException('DataJoint:invalidOperator',....
                'dj.GeneralRelvar/isempty is not defined. Use count()'))
        end
        
    end
    
    
    %%%%%%%%%%%%%%% PRIVATE HELPER FUNCTIONS %%%%%%%%%%%%%%%%%%%%%
    
    
    methods(Access = private)
        
        function schema = getSchema(self)
            schema = self.operands{1};
            if strcmp(self.operator, 'table')
                schema = schema.schema;
            else
                schema = schema.getSchema();
            end
        end
        
        
        function [header, sql] = compile(self, enclose)
            % compile the query tree into an SQL expression
            % OUTPUTS:
            %   sql =   "... [WHERE ...] [GROUP BY (...)]'
            %   header = structure array with attribute properties
            %
            % The input argument enclose controls whether the statement
            % must be enclosed in parentheses: 
            %   0 - don't enclose
            %   1 - enclose only if some attributes are aliased
            %   2 - enclose if anything but a simple table
            %   3 - enclose if is an aggregate (has a GROUP BY clause)
            % Of course, we could simply always inclose subexpressions in
            % parentheses, but we try to keep SQL expressions as simple as
            % possible.
            
            persistent aliasCount
            if isempty(aliasCount)
                aliasCount = 0;
            end
            aliasCount = aliasCount + 1;
            if nargin<2
                enclose = 0;
            end
                        
            % apply relational operators recursively
            switch self.operator
                case 'table'  % terminal node
                    r = self.operands{1};
                    header = r.header;
                    sql = sprintf('`%s`.`%s`', r.schema.dbname, r.info.name);
                    
                case 'pro'
                    [header, sql] = compile(self.operands{1},1);
                    header = projectHeader(header, self.operands(2:end));
                    
                case 'aggregate'
                    [header, sql] = compile(self.operands{1},2);
                    [header2, sql2] = compile(self.operands{2},2);
                    commonIllegal = intersect(...
                        {header([header.isBlob]).name}, ...
                        {header2([header2.isBlob]).name});
                    if ~isempty(commonIllegal)
                        throwAsCaller(MException('DataJoint:illegalOperator', ...
                            'join cannot be done on blob attributes'))
                    end
                    commonAttrs = intersect({header.name}, {header2.name});
                    commonAttrs = sprintf(',`%s`', commonAttrs{:});
                    sql = sprintf(...
                        '%s NATURAL JOIN %s GROUP BY %s', ...
                        sql, sql2, commonAttrs(2:end));
                    header = projectHeader(header, self.operands(3:end));
                    
                    if all(arrayfun(@(x) isempty(x.alias), header))
                        throw(MException('DataJoint:invalidRelation', ...
                            'Aggregate opeators must define at least one computation'))
                    end
                    
                case 'join'
                    [header, sql] = compile(self.operands{1},2);
                    [header2, sql2] = compile(self.operands{2},2);
                    header = [header; header2(~ismember({header2.name}, {header.name}))];
                    sql = sprintf('%s NATURAL JOIN %s', sql, sql2);
                    
                otherwise
                    error 'unknown operator'
            end 
            
            haveAliasedAttrs = ~all(arrayfun(@(x) isempty(x.alias), header));
            
            % apply restrictions
            if ~isempty(self.restrictions)
                % clear aliases and enclose 
                if haveAliasedAttrs
                    [attrStr, header] = makeAttrList(header);
                    sql = sprintf('(SELECT %s FROM %s) as `$s%x`', attrStr, sql, aliasCount);
                    haveAliasedAttrs = false;
                end
                % add WHERE clause
                sql = sprintf('%s%s', sql, makeWhereClause(header, self.restrictions));
            end
            
            % enclose in parentheses if necessary
            if enclose==1 && haveAliasedAttrs ...
                    || enclose==2 && (~strcmp(self.operator,'table') || ~isempty(self.restrictions)) ...
                    || enclose==3 && strcmp(self.operator, 'aggregate')  
                [attrStr, header] = makeAttrList(header);
                sql = sprintf('(SELECT %s FROM %s) AS `$a%x`', attrStr, sql, aliasCount);
            end                 
        end
    end
end



function clause = makeWhereClause(selfAttrs, restrictions)
% make the where clause from self.restrictions
persistent aliasCount
if isempty(aliasCount)
    aliasCount = 0;
else
    aliasCount = aliasCount + 1;
end

assert(all(arrayfun(@(x) isempty(x.alias), selfAttrs)), ...
    'aliases must be resolved before restriction')

clause = '';
word = ' WHERE';
not = '';

for arg = restrictions
    cond = arg{1};
    switch true
        case ischar(cond) && strcmpi(cond,'NOT')
            % negation of the next condition
            not = 'NOT ';
            continue
            
        case ischar(cond) && ~strcmpi(cond, 'NOT')
            % SQL condition
            clause = sprintf('%s %s %s(%s)', clause, word, not, cond);
            
        case isstruct(cond)
            % struct array
            clause = sprintf('%s %s %s(%s)', clause, word, not, ...
                struct2cond(cond, selfAttrs));
            
        case isa(cond, 'dj.GeneralRelvar')
            % semijoin or antijoin
            [condAttrs, condSQL] = cond.compile;
            
            % isolate previous projection (if not already)
            if ismember(cond.operator, {'pro','aggregate'}) && isempty(cond.restrictions)
                [attrStr, condAttrs] = makeAttrList(condAttrs);
                condSQL = sprintf('(SELECT %s FROM %s) as `$u%x`', attrStr, condSQL, aliasCount);
            end
                        
            % common attributes for matching. Blobs are not included 
            commonAttrs = intersect(...
                {selfAttrs(~[selfAttrs.isBlob]).name}, ...
                {condAttrs(~[condAttrs.isBlob]).name});
            if isempty(commonAttrs)
                if ~isempty(not)
                    warning('DataJoint:suspiciousRelation', ...
                        'antijoin without common parameters: no restriction applied')
                else
                    warning('DataJoint:suspiciousRelation', ...
                        'semijoin without common attributes: empty relation')
                    clause = ' WHERE FALSE';
                end
            else
                % make semijoin or antijoin clause
                commonAttrs = sprintf( ',`%s`', commonAttrs{:});
                commonAttrs = commonAttrs(2:end);
                clause = sprintf('%s %s ((%s) %sIN (SELECT %s FROM %s))',...
                    clause, word, commonAttrs, not, commonAttrs, condSQL);
            end
    end
    not = '';
    word = ' AND';
end
end



function cond = struct2cond(keys, header)
% convert the structure array keys into an SQL condition
if length(keys)>512
    warning('DataJoint:longCondition', ...
        'consider replacing the long array of keys with a more succinct condition')
end
conds = cell(1,length(keys));
for iKey= 1:length(keys)
    key = keys(iKey);
    keyFields = fieldnames(key)';
    foundAttributes = ismember(keyFields, {header.name});
    word = '';
    cond = '';
    for field = keyFields(foundAttributes)
        value = key.(field{1});
        if ~isempty(value)
            iField = find(strcmp(field{1}, {header.name}));
            assert(~header(iField).isBlob,...
                'The key must not include blob header.');
            if header(iField).isString
                assert( ischar(value), ...
                    'Value for key.%s must be a string', field{1})
                value=sprintf('"%s"',value);
            else
                assert(isnumeric(value), ...
                    'Value for key.%s must be numeric', field{1});
                value=sprintf('%1.16g',value);
            end
            cond = sprintf('%s%s`%s`=%s', ...
                cond, word, header(iField).name, value);
            word = ' AND';
        end
    end
    conds{iKey} = cond;
end
cond = sprintf('OR (%s)', conds{:});
cond = cond(4:end);
end



function [limit, args] = makeLimitClause(varargin)
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



function header = projectHeader(header, params)
% This is a helper function for dj.Revlar.pro.
% Update the header based on a list of attributes

include = [header.iskey];  % always include the primary key
for iAttr=1:length(params)
    if strcmp('*',params{iAttr})
        include = include | true;   % include all attributes
    else
        % process a renamed attribute
        toks = regexp(params{iAttr}, ...
            '^([a-z]\w*)\s*->\s*(\w+)', 'tokens');
        if ~isempty(toks)
            ix = find(strcmp(toks{1}{1},{header.name}));
            assert(length(ix)==1,'Attribute `%s` not found',toks{1}{1});
            if ismember(toks{1}{2},union({header.alias},{header.name}))
                throw(MException('DataJoint:invalidOperator',  ...
                    sprintf('Duplicate attribute alias `%s`',toks{1}{2})))
            end
            header(ix).name = toks{1}{2};
            header(ix).alias = toks{1}{1};
        else
            % process a computed attribute
            toks = regexp(params{iAttr}, ...
                '(.*\S)\s*->\s*(\w+)', 'tokens');
            if ~isempty(toks)
                %add computed attribute
                ix = length(header)+1;
                header(ix) = struct(...
                    'table','', ...
                    'name', toks{1}{2}, ...
                    'iskey', false, ...
                    'type','<sql_computed>',...
                    'isnullable', false,...
                    'comment','server-side computation', ...
                    'default', [], ...
                    'isNumeric', true, ...  % only numeric computations allowed for now, deal with character string expressions somehow
                    'isString', false, ...
                    'isBlob', false, ...
                    'alias', toks{1}{1});
            else
                % process a regular attribute
                ix = find(strcmp(params{iAttr},{header.name}));
                if isempty(ix)
                    throw(MException('DataJoint:invalidOperator', ...
                        sprintf('Attribute `%s` does not exist', params{iAttr})));
                end
            end
        end
        include(ix)=true;
    end
end
header = header(include);
end



function [str, header] = makeAttrList(header)
% make an SQL list of attributes for header, expanding aliases and strip
% aliases from header
str = '';
if ~isempty(header)
    for i = 1:length(header)
        if isempty(header(i).alias)
            str = sprintf('%s,`%s`', str, header(i).name);
        else
            str = sprintf('%s,(%s) AS `%s`', str, header(i).alias, header(i).name);
            header(i).alias = '';
        end
    end
    str = str(2:end);
end
end

