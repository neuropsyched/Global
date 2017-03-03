function myprogress(varargin)
% Small function to show progress in command window
% Example:
%       progress(i/nfiles, 'reading file %d of %d\n', i, nfiles);

% persistent strlen

if nargin>1
    strlen = length(sprintf(varargin{2:end}));
    %     if usejava('desktop')
    %         % a newline is appropriate when using the desktop environment
    %         varargin{2} = [varargin{2}];
    %     end
    if varargin{3}==10 || varargin{3}==100 || varargin{3}==1000 || varargin{3}==10000 || varargin{3}==100000
        strlen=strlen-1;
    end
    if varargin{3}~=1
        %fprintf(repmat('\b',[1 strlen]));
        fprintf([repmat('\b',[1 strlen]), sprintf(varargin{2:end})])
    else   
        fprintf(varargin{2:end})
    end
    %fprintf([repmat(sprintf('\b'),[1 strlen]), varargin{2:end}])
    
end