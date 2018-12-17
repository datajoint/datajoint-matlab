classdef ERD < handle
    % Entity relationship diagram (ERD) is a directed graph formed between
    % nodes (tables in the database) connected with foreign key dependencies.
    
    properties(SetAccess=protected)
        conn       % a dj.Connection object contianing dependencies
        nodes      % list of nodes
        graph      % the digraph object
    end
    
    
    methods
        
        function self = ERD(obj)
            % initialize ERD node list. obj may be a schema object or a
            % single Relvar object or another ERD.
            if nargin==0
                % default constructor
                self.conn = [];
                self.graph = [];
                self.nodes = {};
            else
                switch true
                    case isa(obj, 'dj.internal.Table')
                        self.nodes = {obj.fullTableName};
                        self.conn = obj.schema.conn;
                    case isa(obj, 'dj.Schema')
                        self.nodes = cellfun(@(s) sprintf('`%s`.`%s`', obj.dbname, s), ...
                            obj.tableNames.values, 'uni', false);
                        self.conn = obj.conn;
                    case isa(obj, 'dj.ERD')
                        % copy constructor
                        self.nodes = obj.nodes;
                        self.conn = obj.conn;
                        self.graph = obj.graph;
                    otherwise
                        error 'invalid ERD initalization'
                end
            end
        end
        
        function up(self)
            % add one layer of nodes upstream in hierarchy
            parents = cellfun(@(s) self.conn.parents(s), self.nodes, 'uni', false);
            self.nodes = union(self.nodes, cat(2, parents{:}));
        end
        
        function down(self)
            % add one layer of nodes downstream in hierarchy
            children = cellfun(@(s) self.conn.children(s), self.nodes, 'uni', false);
            self.nodes = union(self.nodes, cat(2,children{:}));
        end
        
        
        function ret = plus(self, obj)
            % union of ERD graphs
            % A + B is an ERD with all the nodes from A and B.
            % or when B is an integer, expand A by B levels upstream.
            
            ret = dj.ERD(self);  % copy
            switch true
                case isa(obj, 'dj.ERD')
                    if isempty(ret.nodes)
                        ret = dj.ERD(obj);
                    else
                        ret.nodes = union(ret.nodes, obj.nodes);
                    end
                case isnumeric(obj)
                    n = length(ret.nodes);
                    for i=1:obj
                        ret.down
                        if length(ret.nodes)==n
                            break
                        end
                        n = length(ret.nodes);
                    end
                otherwise
                    error 'invalid ERD addition argument'
            end
        end
        
        
        function ret = minus(self, obj)
            % difference of ERD graphs
            % A - B is an ERD with all the nodes from A that are not in B.
            % or when B is an integer, expand A by B levels downstream.
            
            ret = dj.ERD(self);  % copy
            switch true
                case isa(obj, 'dj.ERD')
                    ret.nodes = setdiff(ret.nodes, obj.nodes);
                case isnumeric(obj)
                    n = length(ret.nodes);
                    for i=1:obj
                        ret.up
                        if length(ret.nodes)==n
                            break
                        end
                        n = length(ret.nodes);
                    end
                otherwise
                    error 'invalid ERD difference argument'
            end
        end
        
        
        function display(self)
            self.draw
        end
        
        
        function draw(self)
            % draw the diagram
            
            % exclude auxiliary tables (job tables, etc.)
            j = cellfun(@isempty, regexp(self.nodes, '^`[a-z]\w*`\.`~\w+`$'));
            self.nodes = self.nodes(j);
            
            self.makeGraph
            
            rege = cellfun(@(s) sprintf('^`[a-z]\\w*`\\.`%s[a-z]\\w*`$',s), dj.Schema.tierPrefixes, 'uni', false);
            rege{end+1} = '^`[a-z]\w*`\.`\W?\w+__\w+`$';   % for part tables
            rege{end+1} = '^\d+$';  % for numbered nodes
            tiers = cellfun(@(l) find(~cellfun(@isempty, regexp(l, rege)), 1, 'last'), self.graph.Nodes.Name);
            colormap(0.3+0.7*[
                0.3 0.3 0.3
                0.0 0.5 0.0
                0.0 0.0 1.0
                1.0 0.0 0.0
                1.0 1.0 1.0
                0.0 0.0 0.0
                1.0 0.0 0.0
                ]);
            marker = {'hexagram' 'square' 'o' 'pentagram' '.' '.' '.'};
            self.graph.Nodes.marker = marker(tiers)';
            h = self.graph.plot('layout', 'layered', 'NodeLabel', []);
            h.NodeCData = tiers;
            caxis([0.5 7.5])
            h.MarkerSize = 12;
            h.Marker = self.graph.Nodes.marker;
            h.EdgeColor = [1 1 1]*0;
            h.EdgeAlpha = 0.25;
            axis off
            for i=1:self.graph.numnodes
                if tiers(i)<7  % ignore jobs, logs, etc.
                    isPart = tiers(i)==6;
                    fs = dj.set('erdFontSize')*(1 - 0.3*isPart);
                    fc = isPart*0.3*[1 1 1];
                    name = self.conn.tableToClass(self.graph.Nodes.Name{i});
                    text(h.XData(i)+0.1, h.YData(i), name, ...
                        'fontsize', fs, 'rotation', -16, 'color', fc, ...
                        'Interpreter', 'none');
                end
            end
            if self.graph.numedges
                line_widths = [1 2];
                h.LineWidth = line_widths(2-self.graph.Edges.primary);
                line_styles = {'-', ':'};
                h.LineStyle = line_styles(2-self.graph.Edges.primary);
                ee = cellfun(@(e) find(strcmp(e, self.graph.Nodes.Name), 1, 'first'), ...
                    self.graph.Edges.EndNodes(~self.graph.Edges.multi,:));
                highlight(h, ee(:,1), ee(:,2), 'LineWidth', 3)
                ee = cellfun(@(e) find(strcmp(e, self.graph.Nodes.Name), 1, 'first'), ...
                    self.graph.Edges.EndNodes(self.graph.Edges.aliased,:));
                highlight(h, ee(:,1), ee(:,2), 'EdgeColor', 'r')
            end
            figure(gcf)   % bring figure to foreground
        end
    end
    
    
    methods(Access=protected)
        
        function makeGraph(self)
            % take foreign key and construct a digraph including all the
            % nodes from the list
            
            list = self.nodes;
            if isempty(self.conn.foreignKeys)
                ref = [];
                from = [];
            else
                from = arrayfun(@(item) find(strcmp(item.from, list)), self.conn.foreignKeys, 'uni', false);
                ref = arrayfun(@(item) find(strcmp(item.ref, list)), self.conn.foreignKeys, 'uni', false);
                ix = ~cellfun(@isempty, from) & ~cellfun(@isempty, ref);
                if ~isempty(ref)
                    primary = [self.conn.foreignKeys(ix).primary];
                    aliased = [self.conn.foreignKeys(ix).aliased];
                    multi = [self.conn.foreignKeys(ix).multi];
                    ref = [ref{ix}];
                    from = [from{ix}];
                    % for every renamed edge, introduce a new node
                    for m = find(aliased)
                        t = length(list)+1;
                        list{t} = sprintf('%d',t);
                        q = length(ref)+1;
                        ref(q) = ref(m);
                        from(q) = t;
                        ref(m) = t;
                        primary(q) = primary(m);
                        aliased(q) = aliased(m);
                        multi(q) = multi(m);
                    end
                end
            end
            
            self.graph = digraph(ref, from, 1:length(ref), list);
            if self.graph.numedges
                self.graph.Edges.primary = primary(self.graph.Edges.Weight)';
                self.graph.Edges.aliased = aliased(self.graph.Edges.Weight)';
                self.graph.Edges.multi = multi(self.graph.Edges.Weight)';
            end
        end
    end
    
    
end
