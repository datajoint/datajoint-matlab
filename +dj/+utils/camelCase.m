function str = camelCase(str)
% convert underscore-based names to CamelCase
% e.g.  'one_two_three' --> 'OneTwoThree'
%       'oneTwoThree' --> 'OneTwoThree'
%       '#$one_two,three' --> 'OneTwoThree'
str = regexprep(str, '(^|[_\W]+)([a-zA-Z]?)', '${upper($2)}');