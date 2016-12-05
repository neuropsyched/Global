function [folders,files] = dirdir(path)
%   DIRDIR  lists all subfolders and files in a given directory
%    
%   DIRDIR
%        returns all files under current path.
%
%   folders = DIRDIR('directory_name') 
%       stores all folders under given directory into a variable 'files'
%
%   [folders,files] = DIRDIR('directory_name')
%       stores all foldernames under given directory into a
%       variable 'folders' and all filenames into a variable 'files'.
%       use sort([files{:}]) to get sorted list of all filenames.
%
%   See also DIR, CD, SUBDIRS

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

files = {tmp(~[tmp.isdir]).name};
folders = {tmp([tmp.isdir]).name};
end% if