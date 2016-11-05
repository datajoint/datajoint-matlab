function choice = ask(question,choices)
if nargin<=1
    choices = {'yes','no'};
end
choice = '';    
choiceStr = sprintf('/%s',choices{:});
question = strrep(question, '\', '\\'); % Backslash is a special character in INPUT, needs to be escaped.
while ~ismember(choice, lower(choices))
    choice = lower(input([question ' (' choiceStr(2:end) ') > '], 's'));
end