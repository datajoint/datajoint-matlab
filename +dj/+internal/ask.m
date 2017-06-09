function choice = ask(question,choices)
if nargin<=1
    choices = {'yes','no'};
end
choice = '';    
choiceStr = sprintf('/%s',choices{:});
while ~ismember(choice, lower(choices))
    choice = lower(input([question ' (' choiceStr(2:end) ') > '], 's'));
end