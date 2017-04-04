function str = toCamelCase(str)
% converts underscore_compound_words to CamelCase
% and double underscores in the middle into dots
%
% Not always exactly invertible
%
% Examples:
%   toCamelCase('one')            -->  'One'
%   toCamelCase('one_two_three')  -->  'OneTwoThree'
%   toCamelCase('#$one_two,three') --> 'OneTwoThree'
%   toCamelCase('One_Two_Three')  --> !error! upper case only mixes with alphanumerics
%   toCamelCase('5_two_three')    --> !error! cannot start with a digit

assert(isempty(regexp(str, '\s', 'once')), 'white space is not allowed')
assert(~ismember(str(1), '0':'9'), 'string cannot begin with a digit')
assert(isempty(regexp(str, '[A-Z]', 'once')), ...
    'underscore_compound_words must not contain uppercase characters')
str = regexprep(str, '(^|[_\W]+)([a-zA-Z])', '${upper($2)}');
end