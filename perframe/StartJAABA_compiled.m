% JAABA start up script.

% Initialize all the paths.
% try
%   if matlabpool('size')<1
%     matlabpool open;
%   end
% catch ME
%   warndlg(sprintf('Could not start matlabpool with just "matlabpool open": %s',getReport(ME)));
% end

try
  if isdeployed,
    if ispc,
      setmcruserdata('ParallelProfile','ParallelComputingConfiguration_Local_Win4.settings');
    end
    matlabpool('open');
  end
catch ME,
  uiwait(warndlg('Error starting parallel computing: %s',getReport(ME)));
end

% Start JAABA.

if ismac,
  cd(getenv('JAABA_RUNDIR'));
%else
%  warndlg(sprintf('Starting JAABA in %s, ctfroot is %s, mfilename is %s',pwd,ctfroot,mfilename('fullpath')));
end
try
  JLabel();
catch ME,
  uiwait(warndlg(getReport(ME)));
end
