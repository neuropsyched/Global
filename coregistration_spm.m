function output = coregistration_spm(varargin)
%% Coregister and reslice
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Coregistration of Preop and Postop MRIs                                %
% for Ablation Volume Reconstruction                                     %
% Requires uncompressed NiFTI (*.nii) Images:
%     1) Preop high resolution MRI without contrast                      %
%     2) 1 month Postop MRI with contrast                                %
% 3-D volumetric reconstructionswill be performed on Image 1
% Postoperative ablation volume will be reconstructed from image 2.
% Use Freesurfer mri_convert (*.dcm to *.nii) or recon-all + mri_convert
% (*.mgz to *.nii). Requires:
%     ~/PtId_FS/PtId_preop_T1.nii and 
%     ~/PtId_FS/PtId_postop_T1.nii

% After running the .m file open Preop (source) followed by Postop
% (reference) images. DONE.

% Requires: Matlabbatch availabe here:
% (https://sourceforge.net/projects/matlabbatch/)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Coregister and reslice the Preop MRI (source) to Postop MRI (reference)
% if nargin<2
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Navigate to '...PtId_FS/output' folder and select Preop NIfTI 
% Press Open Select Postop NIfTI and Press Open again
if nargin==2
    [path2ref, ref, ext] = fileparts(varargin{1});
    reference = [ref ext]; clear ref ext
    [path2src, src, ext] = fileparts(varargin{2});
    source = [src ext]; clear src ext
elseif nargin~=2  
    %
    cwd = pwd;
    try
        [ref, path2ref, ext] = ea_uigetfile(cwd,'Choose Reference Image');
        reference = [ref{1} ext{1}];
        path2ref = path2ref{1}; clear ref ext
    catch
        %[reference, path2ref] = uigetfile('*.*','Choose Reference Image','..');
        %disp('Choose Reference Image')
    end
    try
        [src, path2src, ext] = ea_uigetfile(path2ref,'Choose Moving Image');
        source = [src{1} ext{1}];
        path2src = path2src{1}; clear src ext
    catch
        %[source, path2src] = uigetfile('*.*','Choose Moving Image',path2ref);
        %disp('Choose Moving Image')
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%a
% else
%     fullfilename = which 
% end
% fixed = [fullfile(path2ref,reference) ',1'];
% moving = [fullfile(path2src,source) ',1'];
% otherfiles = {''};
%% Coregister with SPM Commands
% Requires SPM12 in matlabpath
% SPM Commands
matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {[fullfile(path2ref,reference) ',1']};
matlabbatch{1}.spm.spatial.coreg.estwrite.source = {[fullfile(path2src,source) ',1']};
matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 1;
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';

% % Executes the SPM commands
spm('defaults','FMRI');
output = spm_jobman('serial',matlabbatch);
% matlabbatch{1}.spm.spatial.coreg.estimate.ref = {fixed};
% matlabbatch{1}.spm.spatial.coreg.estimate.source = {moving};
% matlabbatch{1}.spm.spatial.coreg.estimate.other = otherfiles;
% matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'mi';
% matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [12 10 8 6 4 2];
% matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
% matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];
spm_jobman('run',{matlabbatch});

function [filename, pathname, extension] = ea_uigetfile(start_path, dialog_title)
%
% Syntax: 
%       [filename, pathname, extension] = ea_uigetfile(start_path, dialog_title)

import javax.swing.JFileChooser;

if nargin == 0 || strcmp(start_path,'') % Allow a null argument.
    start_path = pwd;
end

jchooser = javaObjectEDT('javax.swing.JFileChooser', start_path);

jchooser.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);
if nargin > 1
    jchooser.setDialogTitle(dialog_title);
end

jchooser.setMultiSelectionEnabled(true);

status = jchooser.showOpenDialog([]);

if status == JFileChooser.APPROVE_OPTION
    jFile = jchooser.getSelectedFiles();
    pathname{size(jFile, 1)}=[];
    for i=1:size(jFile, 1)
        [pathname{i}, filename{i}, extension{i}] = fileparts(char(jFile(i).getAbsolutePath));
    end

elseif status == JFileChooser.CANCEL_OPTION
    pathname = [];
else
    error('Error occured while picking file.');
end

