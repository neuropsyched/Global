function [subs] = subdirs( path )
% SUBDIRS List subdirectories of a directory.
%     DIR directory_name lists the subdirectories of a directory.
%  
%     subs = SUBDIRS('directory_name') returns the results in an M-by-1
%     structure with the fields: 
%         name  -- name of subfolder
%         path  -- path to subfolder
%         folders -- sub-sub-folders in current 
%         files -- files in subfolder
%     where subs(1) refers to the root directory
%
%     If no subdirectories are present, information about the root 
%       directory is provided in a 1x1 struct.
%
%   See also DIR, CD, DIRDIR

%   author:  Ari Kappel
%   version: 1.0 
%   date:    11-27-2016
%

%------------------------------------------------
if nargin==0
    path = pwd;
else
end
tmp = dir(path);

if ismac
tmp = tmp(~ismember({tmp.name},{'.' '..' '.DS_Store'}));
else % optimized for MACI64
tmp = tmp(~ismember({tmp.name},{'.' '..' '.DS_Store'}));
end

subs(1).name = 'root';
subs(1).path = path;
subs(1).folders = {tmp([tmp.isdir]).name};
subs(1).files = {tmp(~[tmp.isdir]).name};

for i = 1:length(subs(1).folders)
    CurrRoot = subs(1);
    Branchidx = i+1;
    % Branchidx = length(subdir)+1;
    subs(Branchidx).name =  CurrRoot.folders{i};
    subs(Branchidx).path =  fullfile(CurrRoot.path,CurrRoot.folders{i});
    
    CurrBranch = dir(subs(Branchidx).path);
    if ismac
    CurrBranch = CurrBranch(~ismember({CurrBranch.name},{'.' '..' '.DS_Store'}));
    else % optimized for MACI64
    CurrBranch = CurrBranch(~ismember({CurrBranch.name},{'.' '..' '.DS_Store'}));
    end
    
    subs(Branchidx).folders = {CurrBranch([CurrBranch.isdir]).name};
    subs(Branchidx).files   = {CurrBranch(~[CurrBranch.isdir]).name};
    
end

