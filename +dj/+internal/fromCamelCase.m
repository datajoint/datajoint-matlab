function str = fromCamelCase(str)
% converts CamelCase to underscore_compound_words.
%
% Examples:
%   fromCamelCase('oneTwoThree')    --> 'one_two_three'
%   fromCamelCase('OneTwoThree')    --> 'one_two_three'
%   fromCamelCase('one two three')  --> !error! white space is not allowed
%   fromCamelCase('ABC')            --> 'a_b_c'

assert(isempty(regexp(str, '\s', 'once')), 'white space is not allowed')
assert(~ismember(str(1), '0':'9'), 'string cannot begin with a digit')

assert(~isempty(regexp(str, '^[a-zA-Z0-9]*$', 'once')), ...
    'fromCamelCase string can only contain alphanumeric characters');
str = regexprep(str, '([A-Z])', '_${lower($1)}');
str = str(1+(str(1)=='_'):end);  % remove leading underscore
end