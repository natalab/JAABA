classdef FeatureVocabularyForSelectFeatures < handle
  
  % instance variables
  properties
%     jld  % instance of JLabelData, a ref
%     scoresAsInput  % the scores-as-input structure, detailing the files that
%                    % hold classifiers to be used as inputs, and their
%                    % per-frame feature names
%     windowFeatureParams
%    featureLexicon  % the dictionary of possible per-frame features
    wfParamsFromAmount  % scalar structure holding the window feature parameters
                        % that go with each of the possible "amount" levels.
                        % e.g. 'normal', 'more', 'less'.
    pfCategoriesFromName  % scalar structure.  Each field is the name of a 
                          % per-frame feature, and the value is a cell
                          % array of strings, telling what categories that
                          % per-frame feature is in.  Most PFs are in only
                          % one category, but some are in more than one.
    pfCategoryList  % a cell array of strings, holding the names of all the
                    % possible per-frame feature categories
    pfNameList  % A cell array of strings, containing the names of all the 
                % per-frame features.
    defaultPFTransTypesFromName  
      % A structure, each field is a per-frame feature, and each value is a cell 
      % array of strings holding the default translation types
      % for that per-frame feature  (formerly transType)
    vocabulary
      % a structure where each field is a per-frame feauture, and the value
      % holds the window feature parameters for that PF.
      % Should have as many fields as there are per-frame features in the
      % lexicon.  vocabulary.(perframeFeatureName).enabled is a boolean
      % indicating whether that per-frame feature is in the vocabulary.
      % If a PF in the lexicon is absent from vocabulary, it means that one
      % is not in the vocabulary.  (formerly data)
  end  % properties
  
  % things that look like instance vars from the outside, but
  % which are calculated on-the-fly
  properties (Dependent=true)
    wfAmounts
  end
  
  % class constants
  properties (Access=public,Constant=true)
    % Window features come in different types.  This is a list of the
    % different types.  (formerly windowComp)
    wfTypes = {'default','mean','min','max','hist','prctile',...
               'change','std','harmonic','diff_neighbor_mean',...
               'diff_neighbor_min','diff_neighbor_max','zscore_neighbors'};
    % Window features have parameters.  These are the names of those parameters.
    % (Formerly winParams.)
    wfParamNames = {'max_window_radius','min_window_radius','nwindow_radii',...
                    'trans_types','window_offsets'};
    % These are the default values for the window feature parameters.  (Formerly defaultWinParams.)              
    defaultWFParams = {10,1,3,{'none'},0};
    % Window features sometimes have extra parameters.  These are the names 
    % of those parameters.  (Formerly winextraParams.)                  
    wfExtraParamNames = {'','','','','hist_edges','prctiles','change_window_radii',...
                         '','num_harmonic','','','',''};
    % These are the default values for the extra window feature parameters.  (Formerly winextraDefaultParams.)              
    defaultWFExtraParams = {[],[],[],[],[-400000 0 40000],[5 10 30 50 70 90 95],[1 3],...
                            [],2,[],[],[],[]};
  end  % class constants
  
  % class methods
  methods (Access=public,Static=true)
    % ---------------------------------------------------------------------
    function wfParamsFromAmount= ...
      computeWFParamsFromAmount(featureLexicon, ...
                                wfParamNames,defaultWFParams, ...
                                wfExtraParamNames,defaultWFExtraParams)
      % Read the default parameters for different categories.
      categories = fieldnames(featureLexicon.defaults);

      if isempty(categories) 
        % If no default have been specified in the config file.

        categories{1} = 'default';
        curParams = struct;

        % Default values.
        for ndx = 1:numel(wfParamNames)
          curwinpname = wfParamNames{ndx};
          curParams.default.values.(curwinpname) = defaultWFParams{ndx};
        end
        curParams.default.enabled = true;
        curParams.default.values.sanitycheck = false;

        % For each defined window computation.
        for ndx = 2:numel(wfTypes)
          % Copy the default values.
          curwname = wfTypes{ndx};
          for pndx = 1:numel(wfParamNames)
            curwinpname = wfParamNames{pndx};
            curParams.(curwname).values.(curwinpname) = defaultWFParams{pndx};
          end

          if ~isempty(wfExtraParamNames{ndx})
            extraParam = wfExtraParamNames{ndx};
            curParams.(curwname).values.(extraParam) = wfExtraParamNames{ndx};
          end
          curParams.(curwname).enabled = false;
        end
        wfParamsFromAmount.(categories{1}) = curParams;


      else
        % fill the window params for different feature categories.

        for j = 1:numel(categories)
          curParams = struct;
          cur = featureLexicon.defaults.(categories{j});

          % Default values.
          for ndx = 1:numel(wfParamNames)
            curwinpname = wfParamNames{ndx};
            curParams.default.values.(curwinpname) = cur.(curwinpname);
          end
          curParams.default.enabled = true;
          curParams.default.values.sanitycheck = false;

          % For each defined window computation.
          for ndx = 2:numel(wfTypes)
            % Copy the default values.
            curwname = wfTypes{ndx};
            for pndx = 1:numel(wfParamNames)
              curwinpname = wfParamNames{pndx};
              curParams.(curwname).values.(curwinpname) = curParams.default.values.(curwinpname);
            end

            % Override the default window params for the current window computation type
            if isfield(cur,curwname)
              curParams.(curwname).enabled = true;
              diffFields = fieldnames(cur.(curwname));
              for dndx = 1:numel(diffFields)
                if any(strcmp(wfParamNames,diffFields{dndx}))
                  curwinpname = diffFields{dndx};
                  curParams.(curwname).values.(curwinpname) = cur.(curwname).(curwinpname);
                end
              end

              if ~isempty(wfExtraParamNames{ndx})
                extraParam = wfExtraParamNames{ndx};
                if isfield(cur.(curwname),extraParam)
                  curParams.(curwname).values.(extraParam) = cur.(curwname).(extraParam);
                else
                  curParams.(curwname).values.(extraParam) = '';
                end
              end
            else
              curParams.(curwname).enabled = false;
            end
          end
          wfParamsFromAmount.(categories{j}) = curParams;
        end
      end
    end  % method    
    
  end
  
  
  % -----------------------------------------------------------------------  
  % public instance methods
  methods
    % ---------------------------------------------------------------------
    function self=FeatureVocabularyForSelectFeatures(jld)
      % Constructor.  jld an instance of JLabelData
      scoresAsInput = jld.scoresasinput;
      windowFeatureParams = jld.GetPerframeParams();
      featureLexicon = jld.featureLexicon;
      self.digestFeatureLexicon(featureLexicon,scoresAsInput,jld.allperframefns);

      if ~isempty(jld.featureWindowSize)
        %set(self.editSize,'String',num2str(jld.featureWindowSize));
        curVal = jld.featureWindowSize;
        wfAmounts = fieldnames(self.wfParamsFromAmount);
        winComp = self.wfTypes;
        for cndx = 1:numel(wfAmounts)
          curCat = wfAmounts{cndx};
          for wndx = 1:numel(winComp)
            if ~isfield(self.wfParamsFromAmount.(curCat),winComp{wndx}); continue; end
            self.wfParamsFromAmount.(curCat).(winComp{wndx}).values.max_window_radius = curVal;
          end
        end
      end

      pfNameList = fieldnames(self.pfCategoriesFromName);
      self.pfNameList = pfNameList;
      validPfs = fieldnames(windowFeatureParams);
      wfParamNames = self.wfParamNames;
      nPFNames=length(pfNameList);
      vocabulary = cell(1,nPFNames);      
      for ndx = 1:nPFNames
        curPfName = pfNameList{ndx};
        vocabulary{ndx}.name = curPfName;
        pNdx = find(strcmp(curPfName,validPfs));
        if pNdx
          vocabulary{ndx}.enabled = true;  
          vocabulary{ndx}.sanitycheck = windowFeatureParams.(curPfName).sanitycheck;
          % Fill the default values.
          for wfParamNamesNdx = 1:numel(wfParamNames)
            curType = wfParamNames{wfParamNamesNdx};
            if isfield(windowFeatureParams.(curPfName),curType)
              vocabulary{ndx}.default.values.(curType) = windowFeatureParams.(curPfName).(curType);
            else % Fill in the default value
              vocabulary{pfNdx}.default.values.(curType) = ...
                self.defaultWFParams{wfParamNamesNdx};
            end
            vocabulary{ndx}.default.enabled = true;
          end
          % Fill for different window function type.
          % Find which ones are valid.
          curParam = windowFeatureParams.(curPfName);
          validWinfn = fieldnames(curParam);
          for winfnNdx = 2:numel(self.wfTypes)
            curFn = self.wfTypes{winfnNdx};
            wNdx = find(strcmp(curFn,validWinfn));
            if wNdx,
              vocabulary{ndx}.(curFn).enabled = true;
              curWinFnParams = windowFeatureParams.(curPfName).(curFn);
              for wfParamNamesNdx = 1:numel(wfParamNames)
                curType = wfParamNames{wfParamNamesNdx};
                if isfield(curWinFnParams,curType)
                  vocabulary{ndx}.(curFn).values.(curType) = curWinFnParams.(curType);
                else % fill in the default values
                  vocabulary{ndx}.(curFn).values.(curType) = vocabulary{ndx}.default.values.(curType);
                end
              end
              if ~isempty(self. wfExtraParamNames{winfnNdx})
                extraParam = self. wfExtraParamNames{winfnNdx};
                vocabulary{ndx}.(curFn).values.(extraParam) = curWinFnParams.(extraParam);
              end
            else % Values for window comp haven't been defined.
              vocabulary{ndx}.(curFn).enabled = false;
              for wfParamNamesNdx = 1:numel(wfParamNames)
                curType = wfParamNames{wfParamNamesNdx};
                vocabulary{ndx}.(curFn).values.(curType) = vocabulary{ndx}.default.values.(curType);
              end
              if ~isempty(self. wfExtraParamNames{winfnNdx})
                extraParam = self. wfExtraParamNames{winfnNdx};
                vocabulary{ndx}.(curFn).values.(extraParam) = self.defaultWFExtraParams{winfnNdx};
              end
            end
          end
        else % Default values for invalid pf's.
          vocabulary{ndx}.enabled = false;
          vocabulary{ndx}.sanitycheck = false;
          vocabulary{ndx}.default.enabled = true;
          for wfParamNamesNdx = 1:numel(self.wfParamNames)
            curType = self.wfParamNames{wfParamNamesNdx};
            vocabulary{ndx}.default.values.(curType) = ...
              self.defaultWFParams{wfParamNamesNdx};
          end
          % Copy the default values into the other window params.
          for winfnNdx = 2:numel(self.wfTypes)
            curFn = self.wfTypes{winfnNdx};
            vocabulary{ndx}.(curFn).enabled = false;
            for wfParamNamesNdx = 1:numel(self.wfParamNames)
              curType = self.wfParamNames{wfParamNamesNdx};
              vocabulary{ndx}.(curFn).values.(curType) = ...
                vocabulary{ndx}.default.values.(curType);
            end
            if ~isempty(self.wfExtraParamNames{winfnNdx})
              extraParam = self.wfExtraParamNames{winfnNdx};
              vocabulary{ndx}.(curFn).values.(extraParam) = self.defaultWFExtraParams{winfnNdx};
            end
          end
        end
      end
      self.vocabulary = vocabulary;
    end  % constructor method
    
    
    % ---------------------------------------------------------------------
    function enableAllPFsInCategory(self,pfCategoryIndex)
      %pfCategory=self.pfCategoryList{pfCategoryIndex};
      %pfNameList=self.pfNameList;
      %pfCategoriesFromName=self.pfCategoriesFromName;
      pfNamesThisCategory=self.getPFNamesInCategory(pfCategoryIndex);
      % Iterate over the per-frame features, looking for ones that are
      % within the selected category.
      for i = 1:length(pfNamesThisCategory)
        pfName=pfNamesThisCategory{i};
        self.enablePerframeFeature(pfName)
      end
    end  % method

    
    % ---------------------------------------------------------------------
    function setAllPFsInCategoryToWFAmount(self,pfCategoryIndex,wfAmount)
      % This does what it says, but note that it doesn't add or subtract
      % any PFs from the vocabulary.
      %pfCategory=self.pfCategoryList{pfCategoryIndex};
      %pfNameList=self.pfNameList;
      %pfCategoriesFromName=self.pfCategoriesFromName;
      pfNamesThisCategory=self.getPFNamesInCategory(pfCategoryIndex);
      % Iterate over the per-frame features, looking for ones that are
      % within the selected category.
      for i = 1:length(pfNamesThisCategory)
        pfName=pfNamesThisCategory{i};
        self.setPFToWFAmount(pfName,wfAmount)
      end
    end  % method
    
    
    % ---------------------------------------------------------------------
    function enablePerframeFeature(self,pfName)
      % Turn on the given per-frame feature, but leave the window feature 
      % parameters alone.
      pfIndex=find(strcmp(pfName,self.pfNameList));  
      %pfTransTypes=self.defaultPFTransTypesFromName.(pfName);
      self.vocabulary{pfIndex}.enabled = true;  %#ok
      %pfCategories=self.pfCategoriesFromName.(pfName);
      %pfCategory = pfCategories{1};  % why the first one?
      %categoryNdx = find(strcmp(pfCategory,self.pfCategoryList));
      %wfParams=self.wfParamsFromAmount.(wfAmount);
      %self.vocabulary{pfIndex}.enabled = true;
%       for wfTypeIndex = 1:numel(self.wfTypes)
%         wfType = self.wfTypes{wfTypeIndex};
%         wfParamsThisType=wfParams.(wfType);
%         if ~wfParamsThisType.enabled
%           self.vocabulary{pfIndex}.(wfType).enabled = false;
%           continue;
%         end
%         %self = CopyDefaultWindowParams(self,...
%         %  wfAmount, pfIndex,wfTypeIndex);
%         self.setWindowFeaturesOfTypeToAmount(pfIndex,wfTypeIndex,wfAmount);
%         self.vocabulary{pfIndex}.(wfType).values.trans_types = pfTransTypes;
%       end
    end  % method
    
    
    % ---------------------------------------------------------------------
    function setPFToWFAmount(self,pfName,wfAmount)
      % Set the window feature parameters for the named PF to those
      % specified by the named wfAmount (normal, more, less).  This is
      % orthogonal to whether that PF is enabled or not.  Note that this
      % also sets the transformation types for the PF to the default
      % set.
      pfIndex=find(strcmp(pfName,self.pfNameList));  
      defaultPFTransTypes=self.defaultPFTransTypesFromName.(pfName);
      %self.vocabulary{pfIndex}.enabled = true;
      %pfCategories=self.pfCategoriesFromName.(pfName);
      %pfCategory = pfCategories{1};  % why the first one?
      %categoryNdx = find(strcmp(pfCategory,self.pfCategoryList));
      wfParamTemplate=self.wfParamsFromAmount.(wfAmount);
      %self.vocabulary{pfIndex}.enabled = true;
      for wfTypeIndex = 1:numel(self.wfTypes)
        wfType = self.wfTypes{wfTypeIndex};
        %wfParamsThisType=wfParamTemplate.(wfType);
        %if ~wfParamsThisType.enabled
        %  self.vocabulary{pfIndex}.(wfType).enabled = false;
        %  continue;
        %end
        self.setWindowFeaturesOfSingleType(pfIndex,wfTypeIndex,wfParamTemplate);
        self.vocabulary{pfIndex}.(wfType).values.trans_types = defaultPFTransTypes;
      end
    end  % method
    
    
    % ---------------------------------------------------------------------
    function disablePerframeFeature(self,pfName)
      % Turn off the given per-frame feature.  (I.e. remove all it's window 
      % features from the vocabulary)
      pfIndex=find(strcmp(pfName,self.pfNameList));  
      self.vocabulary{pfIndex}.enabled = false;  %#ok
    end  % method
    
    
    % ---------------------------------------------------------------------
    function setWFTypeEnablement(self,pfName,wfType,enable)
      % For the given per-frame feature name, enable/disable the given
      % window-feature type
      pfIndex=find(strcmp(pfName,self.pfNameList));
      self.vocabulary{pfIndex}.(wfType).enabled = enable;  %#ok
    end
    
    
    % ---------------------------------------------------------------------
    function setWFParam(self,pfName,wfType,wfParamName,newValue)
      % For the given per-frame feature name, window-feature type, and
      % window-feature parameter name, set the parameter to newValue
      if ischar(pfName)
        % the usual case
        pfIndex=find(strcmp(pfName,self.pfNameList));
      else
        % this means pfName is really an index
        pfIndex=pfName;
        %pfName=self.pfNameList{pfIndex};
      end
      if ~ischar(wfType)
        % this means wfType is really an index
        wfIndex=wfType;
        wfType=FeatureVocabulary.wfTypes{wfIndex};
      end      
      self.vocabulary{pfIndex}.(wfType).values.(wfParamName) = newValue;
    end

    
    % ---------------------------------------------------------------------
    function addWFTransformation(self,pfName,wfType,newTransformation)
      % For per-frame feature pfName, window feature type wfType, add a new
      % transformation, newTransformation.  (A transformation is one of 'none',
      % 'flip', 'abs', 'relative'.)
      pfIndex=find(strcmp(pfName,self.pfNameList));
      transformations = self.vocabulary{pfIndex}.(wfType).values.trans_types;     
      if ~any(strcmp(newTransformation,transformations))
        % if it's not in the list, add it to the end
        transformations{end+1}=newTransformation;
        self.vocabulary{pfIndex}.(wfType).values.trans_types=transformations;
      end
    end  % method
    
    
    % ---------------------------------------------------------------------
    function removeWFTransformation(self,pfName,wfType,transformation)
      % For per-frame feature pfName, window feature type wfType, remove a 
      % transformation, transformation.  (A transformation is one of 'none',
      % 'flip', 'abs', 'relative'.)  If transformation is not in the
      % transformation list for that window feature, nothing changes.  If
      % removing the given transformation would leave the transformation
      % list empty, nothing changes.
      pfIndex=find(strcmp(pfName,self.pfNameList));
      transformations = self.vocabulary{pfIndex}.(wfType).values.trans_types;
      toBeRemoved = strcmp(transformation,transformations);
      transformations(toBeRemoved) = [];
      % only commit the change if there is still at least one transformation
      % left
      if ~isempty(transformations)
        self.vocabulary{pfIndex}.(wfType).values.trans_types=transformations;
      end
    end  % method

    
    % ---------------------------------------------------------------------
    function result=isWFTransformation(self,pfName,wfType,transformation)
      % For per-frame feature pfName, window feature type wfType, returns
      % true iff the given transformation is in the transformation list.
      pfIndex=find(strcmp(pfName,self.pfNameList));
      transformations = self.vocabulary{pfIndex}.(wfType).values.trans_types;  %#ok
      result=ismember(transformation,transformations);
    end  % method

    
    % ---------------------------------------------------------------------
    function setMaxWindowRadiusForAllWFAmounts(self,newValue)
      % This sets the maximum window radius for all of the preset window
      % feature amounts, for all window feature types.  Note, however, that
      % it does not change the window feature parameters
      % themselves.  So WF params that were previously set using one of the
      % WF amount pre-sets will retain the old values.
      wfAmounts = fieldnames(self.wfParamsFromAmount);
      wfTypes = self.wfTypes;
      for i = 1:numel(wfAmounts)
        wfAmount = wfAmounts{i};
        for j = 1:numel(wfTypes)
          wfType=wfTypes{j};
          wfParams=handles.wfParamsFromAmount.(wfAmount)
          if isfield(wfParams,wfType),
            handles.wfParamsFromAmount.(wfAmount).(wfType).values.max_window_radius = newValue;
          end
        end
      end
    end  % method
    
    
    % ---------------------------------------------------------------------
    function copyWFParams(self,pfNdxFrom,wfTypeNdxFrom,pfNdxTo,wfTypeNdxTo)
      wfTypeFrom = self.wfTypes{wfTypeNdxFrom};
      % something to copy from?
      if ~isfield(self.vocabulary{pfNdxFrom},wfTypeFrom),
        return;
      end
      wfTypeTo = self.wfTypes{wfTypeNdxTo};
      self.vocabulary{pfNdxTo}.(wfTypeTo).enabled = self.vocabulary{pfNdxFrom}.(wfTypeFrom).enabled;
      for i = 1:numel(self.wfParamNames),
        wfParamName = self.wfParamNames{i};
        self.vocabulary{pfNdxTo}.(wfTypeTo).values.(wfParamName) = ...
          self.vocabulary{pfNdxFrom}.(wfTypeFrom).values.(wfParamName);
      end
      if ~isempty(self.wfExtraParamNames{wfTypeNdxTo})
        extraParam = self.wfExtraParamNames{wfTypeNdxTo};
        if isfield(self.vocabulary{pfNdxFrom}.(wfTypeFrom).values,extraParam)
          self.vocabulary{pfNdxTo}.(wfTypeTo).values.(extraParam) = ...
            self.vocabulary{pfNdxFrom}.(wfTypeFrom).values.(extraParam);
        else
          self.vocabulary{pfNdxTo}.(wfTypeTo).values.(extraParam) = '';
        end
      end
    end  % method    
    
    
    % ---------------------------------------------------------------------
    function result=get.wfAmounts(self)
      result=fieldnames(self.wfParamsFromAmount);
    end  % method      

    
    % ---------------------------------------------------------------------
    function result=pfIsInVocabulary(self,pfIndex)
      if ischar(pfIndex)
        % means pfIndex is really a per-frame feature name
        pfName=pfIndex;
        pfIndex=find(strcmp(pfName,self.pfNameList));
      end
      result=self.vocabulary{pfIndex}.enabled;
    end  % method      

    
    % ---------------------------------------------------------------------
    function result=wfTypeIsInVocabulary(self,pfIndex,wfType)
      if ischar(pfIndex)
        % means pfIndex is really a per-frame feature name
        pfName=pfIndex;
        pfIndex=find(strcmp(pfName,self.pfNameList));
      end
      if isnumeric(wfType)
        % means wfType is really a window feature index
        wfIndex=wfType;
        wfType=self.wfTypes{wfIndex};
      end
      result=self.vocabulary{pfIndex}.(wfType).enabled;
    end  % method      
    
    
    % ---------------------------------------------------------------------    
    function windowFeatureParams = getInJLabelDataFormat(self)
      % Converts the feature vocabulary into the format used by JLabelData,
      % returns this.
      windowFeatureParams = struct;
      for pfIndex = 1:numel(self.pfNameList)
        pfName = self.pfNameList{pfIndex};
        if ~self.vocabulary{pfIndex}.enabled; continue;end
        pfParams = self.vocabulary{pfIndex};
        windowFeatureParams.(pfName).sanitycheck = pfParams.sanitycheck;
        % the default window feature type is always included
        for wfParamsIndex = 1:numel(self.wfParamNames)
          wfParamName = self.wfParamNames{wfParamsIndex};
          windowFeatureParams.(pfName).(wfParamName) = pfParams.default.values.(wfParamName);
        end
        for wfTypeIndex = 2:numel(self.wfTypes)
          wfType = self.wfTypes{wfTypeIndex};
          if pfParams.(wfType).enabled,
            for wfParamsIndex = 1:numel(self.wfParamNames)
              wfParamName = self.wfParamNames{wfParamsIndex};
              windowFeatureParams.(pfName).(wfType).(wfParamName) =...
                  pfParams.(wfType).values.(wfParamName);
            end
            if ~isempty(self.wfExtraParamNames{wfTypeIndex})
              extraParam = self.wfExtraParamNames{wfTypeIndex};
              extraParamVal = pfParams.(wfType).values.(extraParam);
              windowFeatureParams.(pfName).(wfType).(extraParam) = extraParamVal;
            end
          end
        end
      end
    end  % method
    
    
    % ---------------------------------------------------------------------
    function pfNames=getPFNamesInCategory(self,pfCategoryName)
      % For the given per-frame feature category, return a cell array of
      % strings containing the names of all per-frame features in that
      % category.
      if isnumeric(pfCategoryName)
        % this means the category name is really a category index
        pfCategoryIndex=pfCategoryName;
        pfCategoryName=self.pfCategoryList{pfCategoryIndex};
      end
      pfNames=cell(1,0);
      for iPF = 1:numel(self.pfNameList)
        pfName=self.pfNameList{iPF};
        categoriesThisPF=self.pfCategoriesFromName.(pfName);
        if ismember(pfCategoryName,categoriesThisPF)
          % if the selected category contains this per-frame feature,
          % do stuff
          pfNames{1,end+1}=pfName;  %#ok
        end
      end
    end  % method    
    

    % ---------------------------------------------------------------------
    function level=getPFCategoryLevel(self,pfCategoryName)
      % For the given per-frame feature category, calculate what 'level' of 
      % per-frame features are in the vocabulary.  Returns one of 'none',
      % 'custom', 'all'.
      pfNamesInCategory=self.getPFNamesInCategory(pfCategoryName);
      nPFsInCategory=length(pfNamesInCategory);
      nPFsInCategoryAndVocab=0;
      for i = 1:nPFsInCategory
        pfName=pfNamesInCategory{i};
        if self.pfIsInVocabulary(pfName),
          nPFsInCategoryAndVocab=nPFsInCategoryAndVocab+1;
        end
      end
      if nPFsInCategoryAndVocab==0
        level='none';
      elseif nPFsInCategoryAndVocab==nPFsInCategory
        level='all';
      else
        level='custom';
      end
    end  % method

    
    % ---------------------------------------------------------------------
    function wfAmount=getWFAmountForPF(self,pfIndex)
      % get the current amount for the given per-frame feature.  Returns
      % one of 'normal', 'more', 'less', and 'custom'.
      if ischar(pfIndex)
        % means it's really a name
        pfName=pfIndex;
        pfIndex=find(strcmp(pfName,self.pfNameList));  
      else
        % pfIndex is really an index
        pfName=self.pfNameList{pfIndex};
      end
      wfAmount='custom';  % if no match, we default to custom
      defaultPFTransTypes=self.defaultPFTransTypesFromName.(pfName);
      nAmounts=length(self.wfAmounts);
      for j=1:nAmounts
        wfAmountTest=self.wfAmounts{j};
        isMatch=true;
        wfParamTemplate=self.wfParamsFromAmount.(wfAmountTest);
        for wfTypeIndex = 1:length(self.wfTypes)
          wfType = self.wfTypes{wfTypeIndex};
          if isfield(self.vocabulary{pfIndex},wfType) && ~isfield(wfParamTemplate,wfType),
            % If this window-feature type is present in the vocabulary, but not
            % in the template, then skip to next wfType
            continue
          end
          % Set the enablement in the vocab to match the template
          if self.vocabulary{pfIndex}.(wfType).enabled ~= wfParamTemplate.(wfType).enabled ,
            isMatch=false;
            break
          end
          % For all the regular WF parameter names, copy them over
          for i = 1:numel(self.wfParamNames),
            wfParamName = self.wfParamNames{i};
            if self.vocabulary{pfIndex}.(wfType).values.(wfParamName) ~= ...
               wfParamTemplate.(wfType).values.(wfParamName) ,
              isMatch=false;
              break
            end
          end
          if ~isMatch, break, end
          % If there is an extra WF parameter for this WF type, copy it over
          % also.
          extraWFParamName = self.wfExtraParamNames{wfTypeNdx};
          if ~isempty(extraWFParamName) && ...
             isfield(wfParamTemplate.(wfType).values,extraWFParamName) && ...
             (self.vocabulary{pfIndex}.(wfType).values.(extraWFParamName) ~= ...
              wfParamTemplate.(wfType).values.(extraWFParamName) ),
            isMatch=false;
            break
          end
          % Check the transformation types also
          if ~all(unique(self.vocabulary{pfIndex}.(wfType).values.trans_types) == ...
                  unique(defaultPFTransTypes) ) ,
            isMatch=false;
            break
          end
        end  % for wfTypeIndex = 1:length(self.wfTypes)
        if isMatch,
          wfAmount=wfAmountTest;
          break  % if match, we're done
        else
          continue  % if no match, try next wfAmount
        end
      end  % for wfAmountTest=self.wfAmounts
    end  % method
      
  end  % public instance methods
  
  
  % -----------------------------------------------------------------------
  % private instance methods
  methods (Access=private)
    % ---------------------------------------------------------------------
    function digestFeatureLexicon(self,featureLexicon,scoresAsInput,perframeL)
      % Initializes the instance variables wfParamsFromAmount, defaultPFTransTypesFromName,
      % pfCategoriesFromName, and pfCategoryList, based on value of
      % inputs and some instance vars that are should already have been
      % initialized.

      % Read the default parameters for different categories.
      categories = fieldnames(featureLexicon.defaults);

      if isempty(categories) 
        % If no default have been specified in the config file.

        categories{1} = 'default';
        curParams = struct;

        % Default values.
        for ndx = 1:numel(self.wfParamNames)
          curwinpname = self.wfParamNames{ndx};
          curParams.default.values.(curwinpname) = self.defaultWFParams{ndx};
        end
        curParams.default.enabled = true;
        curParams.default.values.sanitycheck = false;

        % For each defined window computation.
        for ndx = 2:numel(self.wfTypes)
          % Copy the default values.
          curwname = self.wfTypes{ndx};
          for pndx = 1:numel(self.wfParamNames)
            curwinpname = self.wfParamNames{pndx};
            curParams.(curwname).values.(curwinpname) = self.defaultWFParams{pndx};
          end

          if ~isempty(self.wfExtraParamNames{ndx})
            extraParam = self.wfExtraParamNames{ndx};
            curParams.(curwname).values.(extraParam) = self.wfExtraParamNames{ndx};
          end
          curParams.(curwname).enabled = false;
        end
        self.wfParamsFromAmount.(categories{1}) = curParams;


      else
        % fill the window params for different feature categories.

        for j = 1:numel(categories)
          curParams = struct;
          cur = featureLexicon.defaults.(categories{j});

          % Default values.
          for ndx = 1:numel(self.wfParamNames)
            curwinpname = self.wfParamNames{ndx};
            curParams.default.values.(curwinpname) = cur.(curwinpname);
          end
          curParams.default.enabled = true;
          curParams.default.values.sanitycheck = false;

          % For each defined window computation.
          for ndx = 2:numel(self.wfTypes)
            % Copy the default values.
            curwname = self.wfTypes{ndx};
            for pndx = 1:numel(self.wfParamNames)
              curwinpname = self.wfParamNames{pndx};
              curParams.(curwname).values.(curwinpname) = curParams.default.values.(curwinpname);
            end

            % Override the default window params for the current window computation type
            if isfield(cur,curwname)
              curParams.(curwname).enabled = true;
              diffFields = fieldnames(cur.(curwname));
              for dndx = 1:numel(diffFields)
                if any(strcmp(self.wfParamNames,diffFields{dndx}))
                  curwinpname = diffFields{dndx};
                  curParams.(curwname).values.(curwinpname) = cur.(curwname).(curwinpname);
                end
              end

              if ~isempty(self.wfExtraParamNames{ndx})
                extraParam = self.wfExtraParamNames{ndx};
                if isfield(cur.(curwname),extraParam)
                  curParams.(curwname).values.(extraParam) = cur.(curwname).(extraParam);
                else
                  curParams.(curwname).values.(extraParam) = '';
                end
              end
            else
              curParams.(curwname).enabled = false;
            end
          end
          self.wfParamsFromAmount.(categories{j}) = curParams;
        end
      end

      % Now for each different perframe feature read the type default trans_types.
      %perframeL = jld.allperframefns;
      scores_perframe = {scoresAsInput(:).scorefilename};
      defaultPFTransTypesFromName = struct;
      pfCategoriesFromName = struct;

      % perframeL might not contain all the perframe features.
      for pfndx = 1:numel(perframeL)
        curpf = perframeL{pfndx};

        if any(strcmp(curpf ,scores_perframe)), % This is a score perframe.
          defaultPFTransTypesFromName.(curpf) = {'none'};
          pfCategoriesFromName.(curpf) = {'scores'};
          continue;
        end

        defaultPFTransTypesFromName.(curpf) = featureLexicon.perframe.(curpf).trans_types;
        if ischar(defaultPFTransTypesFromName.(curpf))
          defaultPFTransTypesFromName.(curpf) = {defaultPFTransTypesFromName.(curpf)};
        end
        curtypes  = featureLexicon.perframe.(curpf).type; 
        if ischar(curtypes)
          pfCategoriesFromName.(curpf)  = {curtypes}; 
        else    
          pfCategoriesFromName.(curpf)  = curtypes; 
        end
      end

      fallpf = fieldnames(featureLexicon.perframe);
      pfCategoryList = {};
      for pfndx = 1:numel(fallpf)
        curpf = fallpf{pfndx};
        curtypes  = featureLexicon.perframe.(curpf).type; 
        if ischar(curtypes)
          curT = curtypes;
          if ~any(strcmp(pfCategoryList,curT))
            pfCategoryList{end+1} = curT;  %#ok
          end
        else    
          for tndx = 1:numel(curtypes)
            curT = curtypes{tndx};
            if ~any(strcmp(pfCategoryList,curT))
              pfCategoryList{end+1} = curT;  %#ok
            end
          end
        end
      end
      if ~any(strcmp(pfCategoryList,'scores')),
        pfCategoryList{end+1} = 'scores';
      end

      % Store things in self
      self.defaultPFTransTypesFromName = defaultPFTransTypesFromName;
      self.pfCategoriesFromName = pfCategoriesFromName;
      self.pfCategoryList = pfCategoryList;
    end  % method
    
    
%     % ---------------------------------------------------------------------
%     function setWindowFeaturesToAmount(self,pfIndex,wfAmount)
%       % For the per-frame feature with index pfIndex, sets the window features 
%       % to the amount given by wfAmount (one of 'normal', 'more', or 'less').
%       wfParams=self.wfParamsFromAmount.(wfAmount);
%       for wfTypeIndex = 1:numel(self.wfTypes)
%         wfType = self.wfTypes{wfTypeIndex};
%         wfParamsThisType=wfParams.(wfType);
%         if wfParamsThisType.enabled
%           self.setWindowFeaturesOfTypeToAmount(self,pfIndex,wfTypeIndex,wfAmount);
%           self.vocabulary{pfIndex}.(wfType).values.trans_types = pfTransTypes;
%         else
%           self.vocabulary{pfIndex}.(wfType).enabled = false;
%         end
%       end
%     end  % method
    
    
    % ---------------------------------------------------------------------
    function setWindowFeaturesOfSingleType(self,pfNdx,wfTypeNdx,wfParamTemplate)
      % For the per-frame feature with index pfNdx, sets the window features 
      % with type given by index wfTypeNdx to the amount given in wfParamTemplate.  

      wfType = self.wfTypes{wfTypeNdx};
      %wfParamTemplate=self.wfParamsFromAmount.(wfAmount);
      % Want to do something like:
      %   self.vocabulary{pfNdx}.(wfType)=pfParamTemplate.(wfType)  ,
      % but adapted to the particular PF, I guess ---ALT, Mar 31, 2013
      % something to copy from?
      if isfield(self.vocabulary{pfNdx},wfType) && ~isfield(wfParamTemplate,wfType),
        % If this window-feature type is present in the vocabulary, but not
        % in the template, then disable it in the vocab, and return.
        % (If this ever happens, doesn't it mean the template is broken?
        % And since we control the template, this need never happen.
        % --ALT, Mar 31, 2013)
        self.vocabulary{pfNdx}.(wfType).enabled = false;
        return
      end
      % Set the enablement in the vocab to match the template
      self.vocabulary{pfNdx}.(wfType).enabled = wfParamTemplate.(wfType).enabled;
      % For all the regular WF parameter names, copy them over
      for i = 1:numel(self.wfParamNames),
        wfParamName = self.wfParamNames{i};
        self.vocabulary{pfNdx}.(wfType).values.(wfParamName) = ...
          wfParamTemplate.(wfType).values.(wfParamName);
      end
      % If there is an extra WF parameter for this WF type, copy it over
      % also.
      extraWFParamName = self.wfExtraParamNames{wfTypeNdx};
      if ~isempty(extraWFParamName) 
        if isfield(wfParamTemplate.(wfType).values,extraWFParamName) ,
          value=wfParamTemplate.(wfType).values.(extraWFParamName);
        else
          % If no value is specified, set to empty matrix
          value=[];
        end
        self.vocabulary{pfNdx}.(wfType).values.(extraWFParamName) = ...
          value;
      end
    end  % method    
    
  end  % private methods
end  % classdef
