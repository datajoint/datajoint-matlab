classdef GeneralRelvar < handle
    % GeneralRelvar: a relational variable supporting relational operators.
    % General relvars do not have a table associated with them. They
    % represent a relational expression based on other relvars.
    
    
    properties(Dependent, SetAccess = private)
        attrs        % computed attributes and their properties
        sql          % computed sql expression
        schema       % schema object
        primaryKey   % primary key attribute names
        nonKeyFields % non-key attribute names
    end
    
    
    properties(SetAccess = private, GetAccess = protected)
        operator          % node type: table, join, or pro
        operands = {}     % list of operands (other relvars)
        restrictions = {} % list of restrictions applied to operator output
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
        
        function attrs = get.attrs(self)
            attrs = self.compile();
        end
                
        function s = get.sql(self)
            [~, s] = self.compile();
        end
        
        function schema = get.schema(self)
            leaf = self.getLeaf();
            schema = leaf.schema;
        end
                
        function names = get.primaryKey(self)
            if isempty(self.attrs)
                warning('DataJoint:emptyPrimaryKey', 'empty primary key?')
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
            % dj.GeneralRelvar/display - display the contents of the relation.
            % Only non-blob attrs of the first several tuples are shown.
            % The total number of tuples is printed at the end.
            tic
            justify = nargin==1 || justify;
            display@handle(self)
            nTuples = self.count;
            
            attrs = self.attrs;
            
            if nTuples>0
                % print header
                ix = find( ~[attrs.isBlob] );  % attrs to display
                fprintf \n
                fprintf('  %12.12s', attrs(ix).name)
                fprintf \n
                maxRows = 12;
                tuples = self.fetch(attrs(ix).name,maxRows+1);
                
                % print rows
                for s = tuples(1:min(end,maxRows))'
                    for iField = ix
                        v = s.(attrs(iField).name);
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
        
        
        %%%%%%%%%%%%%%%%%% FETCHING DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function n = count(self)
            % GeneralRelvar/count - the number of tuples in the relation.
            n = self.schema.conn.query(sprintf('SELECT count(*) as n FROM %s',self.sql));
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
            % See also dj.GeneralRelvar.pro, dj.GeneralRelvar/fetch1, dj.GeneralRelvar/fetchn
            
            [limit, args] = makeLimitClause(varargin{:});
            self = self.pro(args{:});
            [attrs, sql] = self.compile;
            ret = self.schema.conn.query(sprintf('SELECT %s FROM %s%s', ...
                makeAttrList(attrs), sql, limit));
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
            [attrs, sql] = self.compile;
            ret = self.schema.conn.query(sprintf('SELECT %s FROM %s%s%s',...
                makeAttrList(attrs), sql, limit));
            
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
            ret = init(dj.GeneralRelvar, self.operator, self.operands, ...
                [self.restrictions {arg}]);
        end
        
        
        function ret = minus(self, arg)
            ret = init(dj.GeneralRelvar, self.operator, self.operands, ...
                [self.restrictions {'not' arg}]);
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
            
            % always include primary key in projection
            pk = self.primaryKey;
            params(ismember(params,pk))=[];
            params = [pk params];
            
            if isempty(params) || ~iscellstr(params)
                throwAsCaller(MException('DataJoint:invalidOperotor', ...
                    'dj.GeneralRelvar/pro requires a list of strings as attribute specs'))
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
            % Blobs and nullable attrs should not be joined on.
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
        
        
        function ret = times(self, arg)
            % alias for backward compatibility
            ret = self & arg;
        end
        
        
        function ret = rdivide(self, arg)
            %alias for backward compatibility
            ret = self - arg;
        end

    end
    
    
    %%%%%%%%%%%%%%% IPRIVATE HELPER FUNCTIONS %%%%%%%%%%%%%%%%%%%%%
    
    
    methods(Access = private)
        function leaf = getLeaf(self)
            leaf = self.operands{1};
            if ~strcmp(self.operator, 'table')
                leaf = leaf.getLeaf();
            end
        end
            
            
        function [attrs, sql] = compile(self)
            % compile the expression tree into an SQL expression
            % OUTPUTS:
            %   sql =   "... [WHERE ...] [GROUP BY (...)]'
            %   attrs = array of attribute structures
            
            persistent aliasCount
            
            if strcmp(self.operator, 'table')
                % terminal node
                r = self.operands{1};
                attrs = r.attrs;
                sql = sprintf('`%s`.`%s`', r.schema.dbname, r.info.name);
            else               
                if isempty(aliasCount)
                    aliasCount = 0;
                else
                    aliasCount = aliasCount + 1;
                end
                
                % first operand
                r = self.operands{1};
                [attrs, sql] = r.compile;
                
                % isolate previous projection (if not already)
                if ismember(r.operator, {'pro','aggregate'}) && isempty(r.restrictions)
                    [attrStr, attrs] = makeAttrList(attrs);
                    sql = sprintf('(SELECT %s FROM %s) AS `$a%x`', attrStr, sql, aliasCount);
                end
                
                % second operand (if dj.GeneralRelvar)
                if isa(self.operands{2}, 'dj.GeneralRelvar')
                    r2 = self.operands{2};
                    [attrs2, sql2] = r2.compile;
                    % isolate previous projection (if not already)
                    if ismember(r2.operator, {'pro','aggregate'}) && isempty(r2.restrictions)
                        [attrStr2, attrs2] = makeAttrList(attrs2);
                        sql2 = sprintf('(SELECT %s FROM %s) AS `$b%x`', attrStr2, sql2, aliasCount);
                    end
                end
                
                % apply relational operator
                switch self.operator                    
                    case 'pro'
                        attrs = compileAttrs(attrs, self.operands(2:end));
                        
                    case 'aggregate'
                        commonAttrs = intersect({attrs.name}, {attrs2.name});
                        commonAttrs = sprintf(',`%s`', commonAttrs{:});
                        sql = sprintf(...
                            '%s as `$r%x` NATURAL JOIN %s as `$q%x` GROUP BY (%s)', ...
                            sql, aliasCount, sql2, aliasCount, commonAttrs(2:end));
                        attrs = compileAttrs(attrs, self.operands(3:end));
                        
                        if all(arrayfun(@(x) isempty(x.alias), attrs))
                            throw(MException('DataJoint:invalidRelation', ...
                                'Aggregate opeators must define at least one computation'))
                        end
                        
                    case 'join'                       
                        attrs = [attrs; attrs2(~ismember({attrs2.name}, {attrs.name}))];
                        sql = sprintf('%s NATURAL JOIN %s', sql, sql2);
                        
                    otherwise
                        error 'unknown operator'
                end
            end
            
            % apply restrictions
            if ~isempty(self.restrictions)
                % clear aliases
                if ~all(arrayfun(@(x) isempty(x.alias), attrs))
                    [attrStr, attrs] = makeAttrList(attrs);
                    sql = sprintf('(SELECT %s FROM %s) as `$s%x`', attrStr, sql, aliasCount);
                end                
                sql = sprintf('%s%s', sql, whereClause(attrs, self.restrictions));
            end      
        end
    end
end




function clause = whereClause(selfAttrs, restrictions)
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
            [condSQL, condAttrs] = cond.compile;
            
            % isolate previous projection (if not already)
            if ismember(cond.operator, {'pro','aggregate'}) && isempty(cond.restrictions)
                [attrStr, condAttrs] = makeAttrList(condAttrs);
                condSQL = sprintf('(SELECT %s FROM %s) as `$u%x`', attrStr, condSQL, aliasCount);
            end
            
            commonIllegal = intersect( ...
                {selfAttrs([selfAttrs.isnullable] | [selfAttrs.isBlob]).name},...
                {condAttrs([condAttrs.isnullable] | [condAttrs.isBlob]).name});
            
            if ~isempty(commonIllegal)
                throw(MException('DataJoint:illegalOperator', ...
                    sprintf('cannot join on blob or nullable field `%s`', ...
                    commonIllegal{1})))
            end
            
            commonAttrs = intersect({selfAttrs.name}, {condAttrs.name});
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
                clause = sprintf('%s %s ((%s) %sIN (SELECT %s FROM %s%s) as `$w%x`)',...
                    clause, word, commonAttrs(2:end), not, commonAttrs, condSQL, aliasCount);
            end
    end
    not = '';
    word = ' AND';
end
end



function cond = struct2cond(keys, attrs)
% convert the structure array keys into an SQL condition
if length(keys)>512
    warning('DataJoint:longCondition', ...
        'consider replacing the long array of keys with a more succinct condition')
end
conds = cell(1,length(keys));
for iKey= 1:length(keys)
    key = keys(iKey);
    keyFields = fieldnames(key)';
    foundAttributes = ismember(keyFields, {attrs.name});
    word = '';
    cond = '';
    for field = keyFields(foundAttributes)
        value = key.(field{1});
        if ~isempty(value)
            iField = find(strcmp(field{1}, {attrs.name}));
            assert(~attrs(iField).isBlob,...
                'The key must not include blob attrs.');
            if attrs(iField).isString
                assert( ischar(value), ...
                    'Value for key.%s must be a string', field{1})
                value=sprintf('"%s"',value);
            else
                assert(isnumeric(value), ...
                    'Value for key.%s must be numeric', field{1});
                value=sprintf('%1.16g',value);
            end
            cond = sprintf('%s%s`%s`=%s', ...
                cond, word, attrs(iField).name, value);
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



function attrs = compileAttrs(attrs, params)
% This is a helper function for dj.Revlar.pro.
% Parse and validate the list of relation attributes in params.

include = false(length(attrs),1);  
for iAttr=1:length(params)
    if strcmp('*',params{iAttr})
        include = include | true;   % include all attributes
    else
        % process a renamed attribute
        toks = regexp(params{iAttr}, ...
            '^([a-z]\w*)\s*->\s*(\w+)', 'tokens');
        if ~isempty(toks)
            ix = find(strcmp(toks{1}{1},{attrs.name}));
            assert(length(ix)==1,'Attribute `%s` not found',toks{1}{1});
            if ismember(toks{1}{2},union({attrs.alias},{attrs.name}))
                throw(MException('DataJoint:invalidOperator',  ...
                    sprintf('Duplicate attribute alias `%s`',toks{1}{2})))
            end
            attrs(ix).name = toks{1}{2};
            attrs(ix).alias = toks{1}{1};
        else
            % process a computed attribute
            toks = regexp(params{iAttr}, ...
                '(.*\S)\s*->\s*(\w+)', 'tokens');
            if ~isempty(toks)
                %add computed attribute
                ix = length(attrs)+1;
                attrs(ix) = struct(...
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
                ix = find(strcmp(params{iAttr},{attrs.name}));
                if isempty(ix)
                    throw(MException('DataJoint:invalidOperator', ...
                        sprintf('Attribute `%s` does not exist', params{iAttr})));
                end
            end
        end
        include(ix)=true;
    end
end
attrs = attrs(include);
end



function [str, attrs] = makeAttrList(attrs)
    % make an SQL list of attributes for attrs, expanding aliases and strip
    % aliases from attrs
    str = '';
    if ~isempty(attrs)
        for i = 1:length(attrs)
            if isempty(attrs(i).alias)
                str = sprintf('%s,`%s`', str, attrs(i).name);
            else
                str = sprintf('%s,(%s) AS `%s`', str, attrs(i).alias, attrs(i).name);
                attrs(i).alias = '';
            end
        end
        str = str(2:end);
    end
end

