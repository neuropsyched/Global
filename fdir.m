function [files,subs] = fdir(Path,ext)
% Returns contents of path as struct
% Option to keep only files with input extension
%
% Inputs:
%
% 
% Ari Kappel, 2017
%

if isempty(Path) || ~exist('Path','var')
    Path = pwd;
end
    
contents = dir(Path);
contents = contents(cellfun(@(x) isempty(regexp(x, '^\.', 'once')), {contents.name}));

if ~isempty({contents(~[contents.isdir]).name})
    files = contents(~[contents.isdir]);
end
if ~isempty({contents([contents.isdir]).name})
    subs = contents([contents.isdir]);
end

if nargin==2
    files = files(~cellfun(@isempty , strfind({files.name},ext)));
end

end
