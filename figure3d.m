%% ===== CREATE FIGURE =====
function hFig = figure3d()

    % Get renderer name
    rendererName = 'opengl';

    % === CREATE FIGURE ===
    hFig = figure('Visible',       'off', ...
                  'NumberTitle',   'off', ...
                  'IntegerHandle', 'off', ...
                  'MenuBar',       'none', ...
                  'Toolbar',       'none', ...
                  'DockControls',  'on', ...
                  'Units',         'pixels', ...
                  'Color',         [0 0 0], ...
                  'Tag',           '3DViz', ...
                  'Renderer',      rendererName, ...
                  'CloseRequestFcn',         @DeleteFigure, ...
                  'KeyPressFcn',             @FigureKeyPressedCallback, ...
                  'WindowButtonDownFcn',     @FigureClickCallback, ...
                  'WindowButtonMotionFcn',   @FigureMouseMoveCallback, ...
                  'WindowButtonUpFcn',       @FigureMouseUpCallback, ... 'ResizeFunction',          @ResizeCallback, ...
                  'BusyAction',    'queue', ...
                  'Interruptible', 'off');   
    % Define Mouse wheel callback separately (not supported by old versions of Matlab)
    if isprop(hFig, 'WindowScrollWheelFcn')
        set(hFig, 'WindowScrollWheelFcn',  @FigureMouseWheelCallback);
    end
    
    % === CREATE AXES ===
    hAxes = axes('Parent',        hFig, ...
                 'Units',         'normalized', ...
                 'Position',      [.05 .05 .9 .9], ...
                 'Tag',           'Axes3D', ...
                 'Visible',       'off', ...
                 'BusyAction',    'queue', ...
                 'Interruptible', 'off');
             
             axis vis3d
             axis equal
             axis off
             z = zoom(hFig);
             setAxes3DPanAndZoomStyle(z,hAxes,'camera');
    
    % === APPDATA STRUCTURE ===
    setappdata(hFig, 'Surface',     []); %repmat(db_template('TessInfo'), 0));
    setappdata(hFig, 'iSurface',    []);
    setappdata(hFig, 'StudyFile',   []);   
    setappdata(hFig, 'SubjectFile', []);      
    setappdata(hFig, 'DataFile',    []); 
    setappdata(hFig, 'ResultsFile', []);
    setappdata(hFig, 'isSelectingCorticalSpot', 0);
    setappdata(hFig, 'isSelectingCoordinates',  0);
    setappdata(hFig, 'hasMoved',    0);
    setappdata(hFig, 'isPlotEditToolbar',   0);
    setappdata(hFig, 'AllChannelsDisplayed', 0);
    setappdata(hFig, 'ChannelsToSelect', []);
    setappdata(hFig, 'isStatic', 0);
    setappdata(hFig, 'isStaticFreq', 1);
    setappdata(hFig, 'Colormap', []); %db_template('ColormapInfo'));
    setappdata(hFig, 'ElectrodeInfo', []);

    % === LIGHTING ===
    hl = [];
    % Fixed lights
    hl(1) = camlight(  0,  40, 'infinite');
    hl(2) = camlight(180,  40, 'infinite');
    hl(3) = camlight(  0, -90, 'infinite');
    hl(4) = camlight( 90,   0, 'infinite');
    hl(5) = camlight(-90,   0, 'infinite');
    % Moving camlight
    hl(6) = light('Tag', 'FrontLight', 'Color', [1 1 1], 'Style', 'infinite', 'Parent', hAxes);
    camlight(hl(6), 'headlight');
    % Mute the intensity of the lights
    for i = 1:length(hl)
        set(hl(i), 'color', .4*[1 1 1]);
    end
    UpdateFigureName(hFig);
    % Camera basic orientation
    SetStandardView(hFig, 'front');

    
    
%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, ev)
    % Get colorbar and axes handles
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    hAxes     = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if isempty(hAxes)
        return
    end
    hAxes = hAxes(1);
    % Get figure position and size in pixels
    figPos = get(hFig, 'Position');
    % Define constants
    colorbarWidth = 15;
    marginHeight  = 25;
    marginWidth   = 45;
    
    % If there is a colorbar 
    if ~isempty(hColorbar)
        % Reposition the colorbar
        set(hColorbar, 'Units',    'pixels', ...
                       'Position', [figPos(3) - marginWidth, ...
                                    marginHeight, ...
                                    colorbarWidth, ...
                                    max(1, min(90, figPos(4) - marginHeight - 3))]);
        % Reposition the axes
        marginAxes = 10;
        set(hAxes, 'Units',    'pixels', ...
                   'Position', [marginAxes, ...
                                marginAxes, ...
                                figPos(3) - colorbarWidth - marginWidth - 2, ... % figPos(3) - colorbarWidth - marginWidth - marginAxes, ...
                                max(1, figPos(4) - 2*marginAxes)]);
    % No colorbar : data axes can take all the figure space
    else
        % Reposition the axes
        set(hAxes, 'Units',    'normalized', ...
                   'Position', [.05, .05, .9, .9]);
    end

    
%% =========================================================================================
%  ===== KEYBOARD AND MOUSE CALLBACKS ======================================================
%  =========================================================================================
% Complete mouse and keyboard management over the main axes
% Supports : - Customized 3D-Rotation (LEFT click)
%            - Pan (SHIFT+LEFT click, OR MIDDLE click
%            - Zoom (CTRL+LEFT click, OR RIGHT click, OR WHEEL)
%            - Colorbar contrast/brightness
%            - Restore original view configuration (DOUBLE click)

%% ===== FIGURE CLICK CALLBACK =====
function FigureClickCallback(hFig, varargin)
    % Get selected object in this figure
    hObj = get(hFig,'CurrentObject');
    % Find axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if isempty(hAxes)
        return;
    end
    % Get figure type
    FigureId = getappdata(hFig, 'FigureId');
    % Double click: reset view           
    if strcmpi(get(hFig, 'SelectionType'), 'open')
        ResetView(hFig);
    end
    
    % Check if MouseUp was executed before MouseDown
    if isappdata(hFig, 'clickAction') && strcmpi(getappdata(hFig,'clickAction'), 'MouseDownNotConsumed')
        % Should ignore this MouseDown event
        setappdata(hFig,'clickAction','MouseDownOk');
        return;
    end
   
    % Start an action (pan, zoom, rotate, contrast, luminosity)
    % Action depends on : 
    %    - the mouse button that was pressed (LEFT/RIGHT/MIDDLE), 
    %    - the keys that the user presses simultaneously (SHIFT/CTRL)
    clickAction = '';
    switch(get(hFig, 'SelectionType'))
        % Left click
        case 'normal'
            % (3D): rotate
            clickAction = 'rotate';
            
            % CTRL+Mouse, or Mouse right
        case 'alt'
            SetStandardView(hFig,'right')
            clickAction = 'popup';
        % SHIFT+Mouse, or Mouse middle
        case 'extend'
            clickAction = 'pan';
    end
    
    % Record action to perform when the mouse is moved
    setappdata(hFig, 'clickAction', clickAction);
    setappdata(hFig, 'clickSource', hFig);
    setappdata(hFig, 'clickObject', hObj);
    % Reset the motion flag
    setappdata(hFig, 'hasMoved', 0);
    % Record mouse location in the figure coordinates system
    setappdata(hFig, 'clickPositionFigure', get(hFig, 'CurrentPoint'));
    % Record mouse location in the axes coordinates system
    setappdata(hFig, 'clickPositionAxes', get(hAxes, 'CurrentPoint'));


    
%% ===== FIGURE MOVE =====
function FigureMouseMoveCallback(hFig, varargin)  
    % Get axes handle
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'Axes3D');
    % Get current mouse action
    clickAction = getappdata(hFig, 'clickAction');   
    clickSource = getappdata(hFig, 'clickSource');   
    % If no action is currently performed
    if isempty(clickAction)
        return
    end
    % If MouseUp was executed before MouseDown
    if strcmpi(clickAction, 'MouseDownNotConsumed') || isempty(getappdata(hFig, 'clickPositionFigure'))
        % Ignore Move event
        return
    end
    % If source is not the same as the current figure: fire mouse up event
    if (clickSource ~= hFig)
        FigureMouseUpCallback(hFig);
        FigureMouseUpCallback(clickSource);
        return
    end

    % Set the motion flag
    setappdata(hFig, 'hasMoved', 1);
    % Get current mouse location in figure
    curptFigure = get(hFig, 'CurrentPoint');
    motionFigure = 0.3 * (curptFigure - getappdata(hFig, 'clickPositionFigure'));
    % Get current mouse location in axes
    curptAxes = get(hAxes, 'CurrentPoint');
    oldptAxes = getappdata(hFig, 'clickPositionAxes');
    if isempty(oldptAxes)
        return
    end
    motionAxes = curptAxes - oldptAxes;
    % Update click point location
    setappdata(hFig, 'clickPositionFigure', curptFigure);
    setappdata(hFig, 'clickPositionAxes',   curptAxes);
    % Get figure size
    figPos = get(hFig, 'Position');
       
    % Switch between different actions (Pan, Rotate, Zoom, Contrast)
    switch(clickAction)              
        case 'rotate'
            % Else : ROTATION
            % Rotation functions : 5 different areas in the figure window
            %     ,---------------------------.
            %     |             2             |
            % .75 |---------------------------| 
            %     |   3  |      5      |  4   |   
            %     |      |             |      | 
            % .25 |---------------------------| 
            %     |             1             |
            %     '---------------------------'
            %           .25           .75
            %
            % ----- AREA 1 -----
            if (curptFigure(2) < .25 * figPos(4))
                camroll(hAxes, motionFigure(1));
                camorbit(hAxes, 0,-motionFigure(2), 'camera');
            % ----- AREA 2 -----
            elseif (curptFigure(2) > .75 * figPos(4))
                camroll(hAxes, -motionFigure(1));
                camorbit(hAxes, 0,-motionFigure(2), 'camera');
            % ----- AREA 3 -----
            elseif (curptFigure(1) < .25 * figPos(3))
                camroll(hAxes, -motionFigure(2));
                camorbit(hAxes, -motionFigure(1),0, 'camera');
            % ----- AREA 4 -----
            elseif (curptFigure(1) > .75 * figPos(3))
                camroll(hAxes, motionFigure(2));
                camorbit(hAxes, -motionFigure(1),0, 'camera');
            % ----- AREA 5 -----
            else
                camorbit(hAxes, -motionFigure(1),-motionFigure(2), 'camera');
            end
            camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');

        case 'pan'
            % Get camera textProperties
            pos    = get(hAxes, 'CameraPosition');
            up     = get(hAxes, 'CameraUpVector');
            target = get(hAxes, 'CameraTarget');
            % Calculate a normalised right vector
            right = cross(up, target - pos);
            up    = up ./ realsqrt(sum(up.^2));
            right = right ./ realsqrt(sum(right.^2));
            % Calculate new camera position and camera target
            panFactor = 1;
            pos    = pos    + panFactor .* (motionFigure(1).*right - motionFigure(2).*up);
            target = target + panFactor .* (motionFigure(1).*right - motionFigure(2).*up);
            set(hAxes, 'CameraPosition', pos, 'CameraTarget', target);

        case 'zoom'
            if (motionFigure(2) == 0)
                return;
            elseif (motionFigure(2) < 0)
                % ZOOM IN
                Factor = 1-motionFigure(2)./100;
            elseif (motionFigure(2) > 0)
                % ZOOM OUT
                Factor = 1./(1+motionFigure(2)./100);
            end
            zoom(hFig, Factor);
            
        case {'moveSlices', 'popup'}
            FigureId.Type = getappdata(hFig, 'Tag');
            % TOPO: Select channels
            if strcmpi(FigureId.Type, 'Topography') 
                % Get current point
                curPt = curptAxes(1,:);
                % Limit selection to current display
                curPt(1) = bst_saturate(curPt(1), get(hAxes, 'XLim'));
                curPt(2) = bst_saturate(curPt(2), get(hAxes, 'YLim'));
                if ~isappdata(hFig, 'patchSelection')
                    % Set starting position
                    setappdata(hFig, 'patchSelection', curPt);
                    % Draw patch
                    hSelPatch = patch('XData', curptAxes(1) * [1 1 1 1], ...
                                      'YData', curptAxes(2) * [1 1 1 1], ...
                                      'ZData', .0001 * [1 1 1 1], ...
                                      'LineWidth', 1, ...
                                      'FaceColor', [1 0 0], ...
                                      'FaceAlpha', 0.3, ...
                                      'EdgeColor', [1 0 0], ...
                                      'EdgeAlpha', 1, ...
                                      'BackfaceLighting', 'lit', ...
                                      'Tag',       'TopoSelectionPatch', ...
                                      'Parent',    hAxes);
                else
                    % Get starting position
                    startPt = getappdata(hFig, 'patchSelection');
                    % Update patch position
                    hSelPatch = findobj(hAxes, '-depth', 1, 'Tag', 'TopoSelectionPatch');
                    % Set new patch position
                    set(hSelPatch, 'XData', [startPt(1), curPt(1),   curPt(1), startPt(1)], ...
                                   'YData', [startPt(2), startPt(2), curPt(2), curPt(2)]);
                end
            % MRI: Move slices
            else
                % Get MRI
                [sMri,TessInfo,iTess] = panel_surface('GetSurfaceMri', hFig);
                if isempty(iTess)
                    return
                end

                % === DETECT ACTION ===
                % Is moving axis and direction are not detected yet : do it
                if (~isappdata(hFig, 'moveAxis') || ~isappdata(hFig, 'moveDirection'))
                    % Guess which cut the user is trying to change
                    % Sometimes some problem occurs, leading to values > 800
                    % for a 1-pixel movement => ignoring
                    if (max(motionAxes(1,:)) > 20)
                        return;
                    end
                    % Convert MRI-CS -> SCS
                    motionAxes = motionAxes * sMri.SCS.R;
                    % Get the maximum deplacement as the direction
                    [value, moveAxis] = max(abs(motionAxes(1,:)));
                    moveAxis = moveAxis(1);
                    % Get the directions of the mouse deplacement that will
                    % increase or decrease the value of the slice
                    [value, moveDirection] = max(abs(motionFigure));                   
                    moveDirection = sign(motionFigure(moveDirection(1))) .* ...
                                    sign(motionAxes(1,moveAxis)) .* ...
                                    moveDirection(1);
                    % Save the detected movement direction and orientation
                    setappdata(hFig, 'moveAxis',      moveAxis);
                    setappdata(hFig, 'moveDirection', moveDirection);

                % === MOVE SLICE ===
                else                
                    % Get saved information about current motion
                    moveAxis      = getappdata(hFig, 'moveAxis');
                    moveDirection = getappdata(hFig, 'moveDirection');
                    % Get the motion value
                    val = sign(moveDirection) .* motionFigure(abs(moveDirection));
                    % Get the new position of the slice
                    oldPos = TessInfo(iTess).CutsPosition(moveAxis);
                    newPos = round(bst_saturate(oldPos + val, [1 size(sMri.Cube, moveAxis)]));

                    % Plot a patch that indicates the location of the cut
                    PlotSquareCut(hFig, TessInfo(iTess), moveAxis, newPos);

                    % Draw a new X-cut according to the mouse motion
                    posXYZ = [NaN, NaN, NaN];
                    posXYZ(moveAxis) = newPos;
                    panel_surface('PlotMri', hFig, posXYZ);
                end
            end
    
        case 'colorbar'
            % Delete legend
            % delete(findobj(hFig, 'Tag', 'ColorbarHelpMsg'));
            % Get colormap type
            ColormapInfo = getappdata(hFig, 'Colormap');
            % Changes contrast
            sColormap = bst_colormaps('ColormapChangeModifiers', ColormapInfo.Type, [motionFigure(1), motionFigure(2)] ./ 100, 0);
            if ~isempty(sColormap)
                set(hFig, 'Colormap', sColormap.CMap);
            end
    end


                
%% ===== FIGURE MOUSE UP =====        
function FigureMouseUpCallback(hFig, varargin)
    global GlobalData gChanAlign;
    % === 3DViz specific commands ===
    % Get application data (current user/mouse actions)
    clickAction = getappdata(hFig, 'clickAction');
    clickObject = getappdata(hFig, 'clickObject');
    hasMoved    = getappdata(hFig, 'hasMoved');
    hAxes       = findobj(hFig, '-depth', 1, 'tag', 'Axes3D');
    isSelectingCorticalSpot = getappdata(hFig, 'isSelectingCorticalSpot');
    isSelectingCoordinates  = getappdata(hFig, 'isSelectingCoordinates');
    TfInfo = getappdata(hFig, 'Timefreq');
    
    % Remove mouse appdata (to stop movements first)
    setappdata(hFig, 'hasMoved', 0);
    if isappdata(hFig, 'clickPositionFigure')
        rmappdata(hFig, 'clickPositionFigure');
    end
    if isappdata(hFig, 'clickPositionAxes')
        rmappdata(hFig, 'clickPositionAxes');
    end
    if isappdata(hFig, 'clickAction')
        rmappdata(hFig, 'clickAction');
    else
        setappdata(hFig, 'clickAction', 'MouseDownNotConsumed');
    end
    if isappdata(hFig, 'moveAxis')
        rmappdata(hFig, 'moveAxis');
    end
    if isappdata(hFig, 'moveDirection')
        rmappdata(hFig, 'moveDirection');
    end
    if isappdata(hFig, 'patchSelection')
        rmappdata(hFig, 'patchSelection');
    end
    % Remove SquareCut objects
    PlotSquareCut(hFig);
    
    % ===== SIMPLE CLICK ===== 
    % If user did not move the mouse since the click
    if ~hasMoved
        % === POPUP ===
        if strcmpi(clickAction, 'popup')
            % DisplayFigurePopup(hFig);
        end
        
    % ===== MOUSE HAS MOVED ===== 
    else
        % === COLORMAP HAS CHANGED ===
        if strcmpi(clickAction, 'colorbar')
            % Apply new colormap to all figures
            ColormapInfo = getappdata(hFig, 'Colormap');
            bst_colormaps('FireColormapChanged', ColormapInfo.Type);
            
        % === RIGHT-CLICK + MOVE ===
        elseif strcmpi(clickAction, 'popup')
            % === TOPO: Select channels ===
            if strcmpi(Figure.Id.Type, 'Topography') && ismember(Figure.Id.SubType, {'2DLayout', '2DDisc', '2DSensorCap'});
                % Get selection patch
                hSelPatch = findobj(hAxes, '-depth', 1, 'Tag', 'TopoSelectionPatch');
                if isempty(hSelPatch)
                    return
                elseif (length(hSelPatch) > 1)
                    delete(hSelPatch);
                    return
                end
                % Get selection rectangle
                XBounds = get(hSelPatch, 'XData');
                YBounds = get(hSelPatch, 'YData');
                XBounds = [min(XBounds), max(XBounds)];
                YBounds = [min(YBounds), max(YBounds)];
                % Delete selection patch
                delete(hSelPatch);
                % Find all the sensors that are in that selection rectangle
                if strcmpi(Figure.Id.SubType, '2DLayout')
                    channelLoc = GlobalData.DataSet(iDS).Figure(iFig).Handles.BoxesCenters;
                else
                    channelLoc = GlobalData.DataSet(iDS).Figure(iFig).Handles.MarkersLocs;
                end
                iChannels = find((channelLoc(:,1) >= XBounds(1)) & (channelLoc(:,1) <= XBounds(2)) & ...
                                 (channelLoc(:,2) >= YBounds(1)) & (channelLoc(:,2) <= YBounds(2)));
                % Convert to real channel indices
                if strcmpi(Figure.Id.SubType, '2DLayout')
                    iChannels = GlobalData.DataSet(iDS).Figure(iFig).Handles.SelChanGlobal(iChannels);
                else
                    iChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels(iChannels);
                end
                ChannelNames = {GlobalData.DataSet(iDS).Channel(iChannels).Name};
                % Select those channels
                bst_figures('SetSelectedRows', ChannelNames);
                
            % === SLICES WERE MOVED ===
            else
                % Update "Surfaces" panel
                panel_surface('UpdateSurfaceProperties');
            end
        end
    end 



%% ===== FIGURE MOUSE WHEEL =====
function FigureMouseWheelCallback(hFig, event, target)  
    % Parse inputs
    if (nargin < 3) || isempty(target)
        target = [];
    end
    % ONLY FOR 3D AND 2DLayout
    if isempty(event)
        return;
    elseif (event.VerticalScrollCount < 0)
        % ZOOM IN
        Factor = 1 - double(event.VerticalScrollCount) ./ 20;
    elseif (event.VerticalScrollCount > 0)
        % ZOOM OUT
        Factor = 1./(1 + double(event.VerticalScrollCount) ./ 20);
    else
        Factor = 1;
    end
    % Get axes
    hAxes = findobj(hFig, 'Tag', 'Axes3D');
    % 2D Layout
    if strcmpi(get(hFig,'Tag'), '2DLayout') 
        % Default behavior
        if isempty(target)
            % SHIFT + Wheel: Change the channel gain
            if ismember('shift', get(hFig,'CurrentModifier'))
                target = 'amplitude';
            % CONTROL + Wheel: Change the time window
            elseif ismember('control', get(hFig,'CurrentModifier'))
                target = 'time';
            % Wheel: Just zoom (like in regular figures)
            else
                target = 'camera';
            end
        end
        % Apply zoom factor
        switch (target)
            case 'amplitude'
                figure_topo('UpdateTimeSeriesFactor', hFig, Factor);
            case 'time'
                figure_topo('UpdateTopoTimeWindow', hFig, Factor);
            case 'camera'
                zoom(hAxes, Factor);
        end
    % Else: zoom
    else
        zoom(hAxes, Factor);
    end



%% ===== KEYBOARD CALLBACK =====
function FigureKeyPressedCallback(hFig, keyEvent)   
    global GlobalData TimeSliderMutex;
    % Prevent multiple executions
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    set([hFig hAxes], 'BusyAction', 'cancel');
    if isempty(hFig)
        return
    end
    FigureId = getappdata(hFig,'FigureId');
    % ===== GET SELECTED CHANNELS =====
    % Get selected channels
    %[SelChan, iSelChan] = GetFigSelectedRows(hFig);
    % Get if figure should contain all the modality sensors (display channel net)
    AllChannelsDisplayed = getappdata(hFig, 'AllChannelsDisplayed');
    % Check if it is a realignment figure
    isAlignFig = ~isempty(findobj(hFig, '-depth', 1, 'Tag', 'AlignToolbar'));
    % If figure is 2D
    is2D = 0;
    % isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
        
    % ===== PROCESS BY CHARACTERS =====
    switch (keyEvent.Character)
        % === NUMBERS : VIEW SHORTCUTS ===
        case '0'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'left', 'right', 'top'});
            end
        case '1'
            if ~is2D
                SetStandardView(hFig, 'left');
            end
        case '2'
            if ~is2D
                SetStandardView(hFig, 'bottom');
            end
        case '3'
            if ~is2D
                SetStandardView(hFig, 'right');
            end
        case '4'
            if ~is2D
                SetStandardView(hFig, 'front');
            end
        case '5'
            if ~is2D
                SetStandardView(hFig, 'top');
            end
        case '6'
            if ~is2D
                SetStandardView(hFig, 'back');
            end
        case '7'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'left', 'right'});
            end
        case '8'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'bottom', 'top'});
            end
        case '9'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'front', 'back'});      
            end
        case '.'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'left', 'right', 'top', 'left_intern', 'right_intern', 'bottom'});
            end
        case {'=', 'equal'}
            if ~isAlignFig && ~is2D
                ApplyViewToAllFigures(hFig, 1, 1);
            end
        case '*'
            if ~isAlignFig && ~is2D
                ApplyViewToAllFigures(hFig, 0, 1);
            end
        % === ZOOM ===
        case '+'
            %panel_scout('EditScoutsSize', 'Grow1');
            event.VerticalScrollCount = -2;
            FigureMouseWheelCallback(hFig, event, 'amplitude');
        case '-'
            %panel_scout('EditScoutsSize', 'Shrink1');
            event.VerticalScrollCount = 2;
            FigureMouseWheelCallback(hFig, event, 'amplitude');
            
        otherwise
            % ===== PROCESS BY KEYS =====
            switch (keyEvent.Key)
                % === LEFT, RIGHT, PAGEUP, PAGEDOWN  ===
                case {'leftarrow', 'rightarrow', 'pageup', 'pagedown', 'home', 'end'}
                    if isempty(TimeSliderMutex) || ~TimeSliderMutex
                        panel_time('TimeKeyCallback', keyEvent);
                    end
                    
                % === UP DOWN : Processed by Freq panel ===
                case {'uparrow', 'downarrow'}
                    panel_freq('FreqKeyCallback', keyEvent);
                % === DATA FILES ===
                % CTRL+A : View axis
                case 'a'
                    if ismember('control', keyEvent.Modifier)
                    	ViewAxis(hFig);
                    end 
                % CTRL+D : Dock figure
                case 'd'
                    if ismember('control', keyEvent.Modifier)
                        isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
                        bst_figures('DockFigure', hFig, ~isDocked);
                    end
                % CTRL+E : Sensors and labels
                case 'e'
                    if ~isAlignFig && ismember('control', keyEvent.Modifier) && ~isempty(GlobalData.DataSet(iDS).ChannelFile)
                        hLabels = findobj(hAxes, '-depth', 1, 'Tag', 'SensorsLabels');
                        hElectrodeGrid = findobj(hAxes, 'Tag', 'ElectrodeGrid');
                        isMarkers = ~isempty(findobj(hAxes, '-depth', 1, 'Tag', 'SensorsPatch')) || ~isempty(findobj(hAxes, '-depth', 1, 'Tag', 'SensorsMarkers'));
                        isLabels  = ~isempty(hLabels);
                        % All figures, except "2DLayout"
                        if ~strcmpi(FigureId.SubType, '2DLayout')
                            % Cycle between two modes : Nothing, Labels
                            if ~isempty(hElectrodeGrid)
                                ViewSensors(hFig, 0, ~isLabels);
                            % Cycle between three modes : Nothing, Sensors, Sensors+labels
                            else
                                % SEEG/ECOG: Display 3D Electrodes
                                if ismember(FigureId.Modality, {'SEEG','ECOG'})
                                    view_channels(GlobalData.DataSet(iDS).ChannelFile, FigureId.Modality, 1, 0, hFig, 1);
                                elseif isMarkers && isLabels
                                    ViewSensors(hFig, 0, 0);
                                elseif isMarkers
                                    ViewSensors(hFig, 1, 1);
                                else
                                    ViewSensors(hFig, 1, 0);
                                end
                            end
                        % "2DLayout"
                        else
                            isLabelsVisible = strcmpi(get(hLabels(1), 'Visible'), 'on');
                            if isLabelsVisible
                                set(hLabels, 'Visible', 'off');
                            else
                                set(hLabels, 'Visible', 'on');
                            end
                        end
                    end
                % CTRL+I : Save as image
                case 'i'
                    if ismember('control', keyEvent.Modifier)
                        out_figure_image(hFig);
                    end
                % CTRL+J : Open as image
                case 'j'
                    if ismember('control', keyEvent.Modifier)
                        out_figure_image(hFig, 'Viewer');
                    end
                % CTRL+F : Open as figure
                case 'f'
                    if ismember('control', keyEvent.Modifier)
                        out_figure_image(hFig, 'Figure');
                    end
                % CTRL+R : Recordings time series
                case 'r'
                    if ismember('control', keyEvent.Modifier) && ~isempty(GlobalData.DataSet(iDS).DataFile) && ~strcmpi(FigureId.Modality, 'MEG GRADNORM')
                        view_timeseries(GlobalData.DataSet(iDS).DataFile, FigureId.Modality);
                    end
                % CTRL+S : Sources (first results file)
                case 's'
                    if ismember('control', keyEvent.Modifier)
                        bst_figures('ViewResults', hFig); 
                    end
                % CTRL+T : Default topography
                case 't'
                    if ismember('control', keyEvent.Modifier) 
                        bst_figures('ViewTopography', hFig); 
                    end
                    
  
                % DELETE: SET CHANNELS AS BAD
                case {'delete', 'backspace'}
                    if ~isAlignFig && ~isempty(SelChan) && ~AllChannelsDisplayed && ~isempty(GlobalData.DataSet(iDS).DataFile) && ...
                            (length(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) ~= length(iSelChan))
                        % Shift+Delete: Mark non-selected as bad
                        newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                        if ismember('shift', keyEvent.Modifier)
                            newChannelFlag(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) = -1;
                            newChannelFlag(iSelChan) = 1;
                        % Delete: Mark selected channels as bad
                        else
                            newChannelFlag(iSelChan) = -1;
                        end
                        % Update channel flage
                        panel_channel_editor('UpdateChannelFlag', GlobalData.DataSet(iDS).DataFile, newChannelFlag);
                        % Reset selection
                        bst_figures('SetSelectedRows', []);
                    end
                % ESCAPE: RESET SELECTION
                case 'escape'
                    % Remove selection cross
                    delete(findobj(hAxes, '-depth', 1, 'tag', 'ptCoordinates'));
                    % Channel selection
                    if ~isAlignFig 
                        % Mark all channels as good
                        if ismember('shift', keyEvent.Modifier)
                            ChannelFlagGood = ones(size(GlobalData.DataSet(iDS).Measures.ChannelFlag));
                            panel_channel_editor('UpdateChannelFlag', GlobalData.DataSet(iDS).DataFile, ChannelFlagGood);
                        % Reset channel selection
                        else
                            bst_figures('SetSelectedRows', []);
                        end
                    end
            end
    end
    % Restore events
    if ~isempty(hFig) && ishandle(hFig) && ~isempty(hAxes) && ishandle(hAxes)
        set([hFig hAxes], 'BusyAction', 'queue');
    end



%% ===== RESET VIEW =====
% Restore initial camera position and orientation
function ResetView(hFig)
    if isempty(hFig)
        return
    end
    % Get axes
    hAxes = findobj(hFig, 'Tag', 'Axes3D');
    % Reset zoom
    zoom(hAxes, 'out');    
    
    % 3D figures
    % Get Axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    set(hFig, 'CurrentAxes', hAxes);
    % Camera basic orientation
    SetStandardView(hFig, 'left');
    % Try to find a light source. If found, align it with the camera
    camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');
    



%% ===== SET STANDARD VIEW =====
function SetStandardView(hFig, viewNames)
    % Make sure that viewNames is a cell array
    if ischar(viewNames)
        viewNames = {viewNames};
    end
    % Get Axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Get the data types displayed in this figure
    ColormapInfo = getappdata(hFig, 'Colormap');
    % Get surface information
    TessInfo = getappdata(hFig, 'Surface');

    % ===== ANATOMY ORIENTATION =====
    % If MRI displayed in the figure, use the orientation of the slices, instead of the orientation of the axes
    R = eye(3);
    % Get the mri surface
    Ranat = [];
    try if ismember('anatomy', ColormapInfo.AllTypes)
        iTess = find(strcmpi({TessInfo.Name}, 'Anatomy'));
        if ~isempty(iTess)
            % Get the subject MRI structure in memory
            sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
            % Calculate transformation: SCS => MRI  (inverse MRI => SCS)
            Ranat = pinv(sMri.SCS.R);
        end
    end; end
    % Displaying a surface: Load the SCS field from the MRI
    if isempty(Ranat) && ~isempty(TessInfo) && ~isempty(TessInfo(1).SurfaceFile)
        % Get subject
        sSubject = bst_get('SurfaceFile', TessInfo(1).SurfaceFile);
        % If there is an MRI associated with it
        if ~isempty(sSubject) && ~isempty(sSubject.Anatomy) && ~isempty(sSubject.Anatomy(sSubject.iAnatomy).FileName)
            % Load the SCS+MNI transformation from this file
            sMri = load(file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName), 'NCS', 'SCS', 'Comment');
            if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'R') && ~isempty(sMri.NCS.R) && isfield(sMri, 'SCS') && isfield(sMri.SCS, 'R') && ~isempty(sMri.SCS.R)
                % Calculate the SCS => MNI rotation   (inverse(MRI=>SCS) * MRI=>MNI)
                Ranat = sMri.NCS.R * pinv(sMri.SCS.R);
            end
        end
    end
    % Get the rotation to change orientation
    if ~isempty(Ranat)
        R = [0 1 0;-1 0 0; 0 0 1] * Ranat;
    end    
    
    % ===== MOVE CAMERA =====
    % Apply the first orientation to the target figure
    switch lower(viewNames{1})
        case {'left', 'right_intern'}
            newView = [-92.5283, 0.5498, 0]; %[-1,0,0];
            newCamup = [0.0058, -0.3204, 0.9473]; %[0 0 1];
        case {'right', 'left_intern'}
            newView = [80.3730, 0.1338, 0];
            newCamup = [-0.0270, -0.2690, 0.9628];
        case 'back'
            newView = [0,-1,0];
            newCamup = [0 0 1];
        case 'front'
            newView = [0,1,0];
            newCamup = [0 0 1];    
        case 'bottom'
            newView = [0,0,-1];
            newCamup = [1 0 0];
        case 'top'
            newView = [0,0,1];
            newCamup = [1 0 0];
    end
    % Update camera position
    view(hAxes, newView * R);
    camup(hAxes, double(newCamup * R));
    % Update head light position
    camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');
    % Select only one hemisphere
    if any(ismember(viewNames, {'right_intern', 'left_intern'}))
        set(0,'CurrentFigure', hFig, '3D');
        drawnow;
        %         if strcmpi(viewNames{1}, 'right_intern')
        %             panel_surface('SelectHemispheres', 'right');
        %         elseif strcmpi(viewNames{1}, 'left_intern')
        %             panel_surface('SelectHemispheres', 'left');
        %         else
        %             panel_surface('SelectHemispheres', 'none');
        %         end
    end
    
    % ===== OTHER FIGURES =====
    % If there are other view to represent
    if (length(viewNames) > 1)
        hClones = [];   % bst_figures('GetClones', hFig);
        % Process the other required views
        for i = 2:length(viewNames)
            if ~isempty(hClones)
                % Use an already cloned figure
                hNewFig = hClones(1);
                hClones(1) = [];
            else
                % Clone figure
                hNewFig = (hFig);
            end
            % Set orientation
            SetStandardView(hNewFig, viewNames(i));
        end
        % If there are some cloned figures left : close them
        if ~isempty(hClones)
            close(hClones);
        end
    end


%% ===== PLOT SQUARE/CUT =====
% USAGE:  PlotSquareCut(hFig, TessInfo, dim, pos)
%         PlotSquareCut(hFig)  : Remove all square cuts displayed
function PlotSquareCut(hFig, TessInfo, dim, pos)
    % Get figure description and MRI
    % [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Delete the previous patch
    delete(findobj(hFig, 'Tag', 'squareCut'));
    if (nargin < 4)
        return
    end
    hAxes  = findobj(hFig, '-depth', 1, 'tag', 'Axes3D');
    % Get maximum dimensions (MRI size)
    % sMri = bst_memory('GetMri', TessInfo.SurfaceFile);
    mriSize = size(sMri.Cube);

    % Get locations of the slice
    nbPts = 50;
    baseVect = linspace(-.01, 1.01, nbPts);
    switch(dim)
        case 1
            voxX = ones(nbPts)         .* (pos + 2); 
            voxY = meshgrid(baseVect)  .* mriSize(2);   
            voxZ = meshgrid(baseVect)' .* mriSize(3); 
            surfColor = [1 .5 .5];
        case 2
            voxX = meshgrid(baseVect)  .* mriSize(1); 
            voxY = ones(nbPts)         .* (pos + 2) + .1;    
            voxZ = meshgrid(baseVect)' .* mriSize(3); 
            surfColor = [.5 1 .5];
        case 3
            voxX = meshgrid(baseVect)  .* mriSize(1); 
            voxY = meshgrid(baseVect)' .* mriSize(2); 
            voxZ = ones(nbPts)         .* (pos + 2) + .1;        
            surfColor = [.5 .5 1];
    end

    % === Switch coordinates from MRI-CS to SCS ===
    % Apply Rotation/Translation
    voxXYZ = [voxX(:), voxY(:), voxZ(:)];
    scsXYZ = cs_convert(sMri, 'voxel', 'scs', voxXYZ);

    % === PLOT SURFACE ===
    % Plot new surface  
    hCut = surface('XData',     reshape(scsXYZ(:,1),nbPts,nbPts), ...
                   'YData',     reshape(scsXYZ(:,2),nbPts,nbPts), ...
                   'ZData',     reshape(scsXYZ(:,3),nbPts,nbPts), ...
                   'CData',     ones(nbPts), ...
                   'FaceColor',        surfColor, ...
                   'FaceAlpha',        .3, ...
                   'EdgeColor',        'none', ...
                   'AmbientStrength',  .5, ...
                   'DiffuseStrength',  .9, ...
                   'SpecularStrength', .1, ...
                   'Tag',    'squareCut', ...
                   'Parent', hAxes);
               
%% ===== CREATE FIGURE =====
% USAGE:  [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId)
%         [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId, 'AlwaysCreate')
%         [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId, 'AlwaysCreate', Constrains)
function [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId, CreateMode, Constrains)
    global GlobalData;
    hFig = [];
    iFig = [];
    % Parse inputs
    if (nargin < 4)
        Constrains = [];
    end
    if (nargin < 3) || isempty(CreateMode)
        CreateMode = 'Default';
    end
    isAlwaysCreate = strcmpi(CreateMode, 'AlwaysCreate');
    isDoLayout = 1;
    
    % If figure creation is not forced
    if ~isAlwaysCreate
        % Get all existing (valid) figure for this dataset
        [hFigures, iFigures] = GetFigure(iDS, FigureId);
        % If at least one valid figure was found
        if ~isempty(hFigures)
            % Refine selection for certain types of figures
            if ~isempty(Constrains) && ischar(Constrains) && ismember(FigureId.Type, {'Timefreq', 'Spectrum', 'Connect', 'Pac'})
                for i = 1:length(hFigures)
                    TfInfo = getappdata(hFigures(i), 'Timefreq');
                    if ~isempty(TfInfo) && file_compare(TfInfo.FileName, Constrains)
                        hFig(end+1) = hFigures(i);
                        iFig(end+1) = iFigures(i);
                    end
                end
                % If there are more than one figure possible, try to take the last used one
                if (length(hFig) > 1)
                    if ~isempty(GlobalData.CurrentFigure.TypeTF)
                        iLast = find(hFig == GlobalData.CurrentFigure.TypeTF);
                        if ~isempty(iLast)
                            hFig = hFig(iLast);
                            iFig = iFig(iLast);
                        end
                    end
                    % If could not find a valid figure
                    if (length(hFig) > 1)
                        hFig = hFig(1);
                        iFig = iFig(1);
                    end
                end
            % Topography: Recordings or Timefreq
            elseif ~isempty(Constrains) && ischar(Constrains) && strcmpi(FigureId.Type, 'Topography')
                for i = 1:length(hFigures)
                    TfInfo = getappdata(hFigures(i), 'Timefreq');
                    FileType = file_gettype(Constrains);
                    if (ismember(FileType, {'data', 'pdata'}) && isempty(TfInfo)) || ...
                       (ismember(FileType, {'timefreq', 'ptimefreq'}) && ~isempty(TfInfo) && file_compare(TfInfo.FileName, Constrains))
                        hFig = hFigures(i);
                        iFig = iFigures(i);
                        break;
                    end
                end
            % Data time series => Selected sensors must be the same
            elseif ~isempty(Constrains) && strcmpi(FigureId.Type, 'DataTimeSeries')
                for i = 1:length(hFigures)
                    TsInfo = getappdata(hFigures(i), 'TsInfo');
                    if isequal(TsInfo.RowNames, Constrains)
                        hFig = hFigures(i);
                        iFig = iFigures(i);
                        break;
                    end
                    %isDoLayout = 0;
                end
            % Result time series (scouts)
            elseif ~isempty(Constrains) && strcmpi(FigureId.Type, 'ResultsTimeSeries')
                for i = 1:length(hFigures)
                    TfInfo = getappdata(hFigures(i), 'Timefreq');
                    ResultsFiles = getappdata(hFigures(i), 'ResultsFiles');
                    if iscell(Constrains)
                        BaseFile = Constrains{1};
                    elseif ischar(Constrains)
                        BaseFile = Constrains;
                    end
                    FileType = file_gettype(BaseFile);
                    if (strcmpi(FileType, 'data') && isempty(TfInfo)) || ...
                       (strcmpi(FileType, 'timefreq') && ~isempty(ResultsFiles) && all(file_compare(ResultsFiles, Constrains))) || ...
                       (strcmpi(FileType, 'timefreq') && ~isempty(TfInfo) && file_compare(TfInfo.FileName, Constrains)) || ...
                       (ismember(FileType, {'results','link'}) && ~isempty(ResultsFiles) && all(file_compare(ResultsFiles, Constrains)))
                        hFig = hFigures(i);
                        iFig = iFigures(i);
                        break;
                    end
                end
            % Else: Use the first figure in the list (there can be more than one : for multiple views of same data)
            else
                hFig = hFigures(1);
                iFig = iFigures(1);
            end
        end
    end
       
    % No figure : create one
    isNewFig = isempty(hFig);
    if isNewFig
        % ==== CREATE FIGURE ====
        switch(FigureId.Type)
            case {'DataTimeSeries', 'ResultsTimeSeries'}
                hFig =figure_timeseries ('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimeSeries');
            case 'Topography'
                hFig = figure_3d('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTopography');
            case '3DViz'
                hFig = figure_3d('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandles3DViz');
            case 'MriViewer'
                [hFig, FigHandles] = figure_mri('CreateFigure', FigureId);
            case 'Timefreq'
                hFig = figure_timefreq('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimefreq');
            case 'Spectrum'
                hFig = figure_spectrum('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimeSeries');
            case 'Pac'
                hFig = figure_pac('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimefreq');
            case 'Connect'
                hFig = figure_connect('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimefreq');
            case 'Image'
                hFig = figure_image('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesImage');
            case 'Video'
                hFig = figure_video('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesVideo');
            otherwise
                error(['Invalid figure type : ', FigureId.Type]);
        end
        % Set graphics smoothing (Matlab >= 2014b)
        if (bst_get('MatlabVersion') >= 804)
            if bst_get('GraphicsSmoothing')
                set(hFig, 'GraphicsSmoothing', 'on');
            else
                set(hFig, 'GraphicsSmoothing', 'off');
            end
        end
       
        % ==== REGISTER FIGURE IN DATASET ====
        iFig = length(GlobalData.DataSet(iDS).Figure) + 1;
        GlobalData.DataSet(iDS).Figure(iFig)         = db_template('figure');
        GlobalData.DataSet(iDS).Figure(iFig).Id      = FigureId;
        GlobalData.DataSet(iDS).Figure(iFig).hFigure = hFig;
        GlobalData.DataSet(iDS).Figure(iFig).Handles = FigHandles;
    end   
    
    % Find selected channels
    % [selChan,errMsg] = GetChannelsForFigure(iDS, iFig);
    % Error message
    if ~isempty(errMsg)
        error(errMsg);
    end
    % Save selected channels for this figure
    GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = selChan;
        
    % Set figure name
    UpdateFigureName(hFig);
    % Tile windows
    if isDoLayout
        gui_layout('Update');
    end


%% ===== UPDATE FIGURE NAME =====
function UpdateFigureName(hFig,options)
   
    % Get figure description in GlobalData
    % [hFig, ~, ~] = GetFigure(hFig);
    
    % ==== FIGURE NAME ====
    % SubjectName/Condition/Modality
    try 
        figureName = options.patientname;
    catch
        figureName = '';    
    end
    
    figureNameModality = '';
    
    % Add prefix : figure type
    switch(get(hFig,'Tag'))
        case 'DataTimeSeries'
            % Get current montage
            TsInfo = getappdata(hFig, 'TsInfo');
            if isempty(TsInfo) || isempty(TsInfo.MontageName) || ~isempty(TsInfo.RowNames)
                strMontage = 'All';
            elseif strcmpi(TsInfo.MontageName, 'Average reference')
                strMontage = 'AvgRef';
            elseif strcmpi(TsInfo.MontageName, 'Bad channels')
                strMontage = 'Bad';
            elseif strcmpi(TsInfo.MontageName, 'ICA components[tmp]')
                strMontage = 'ICA';
            elseif strcmpi(TsInfo.MontageName, 'SSP components[tmp]')
                strMontage = 'SSP';
            else
                strMontage = TsInfo.MontageName;
            end
            figureName = [figureNameModality strMontage ': ' figureName];
        case 'ResultsTimeSeries'
            if ~isempty(figureNameModality)
                figureName = [figureNameModality(1:end-2) ': ' figureName];
            end
            % Matrix file: display the file name
            TsInfo = getappdata(hFig, 'TsInfo');
            if ~isempty(TsInfo) && ~isempty(TsInfo.FileName) && strcmpi(file_gettype(TsInfo.FileName), 'matrix')
                iMatrix = find(file_compare({sStudy.Matrix.FileName}, TsInfo.FileName), 1);
                if ~isempty(iMatrix)
                    figureName = [figureName '/' sStudy.Matrix(iMatrix).Comment];
                end
            end
            
        case 'Topography'
            figureName = [figureNameModality  'TP: ' figureName];
        case '3DViz'
            figureName = [figureNameModality  '3D: ' figureName];
        case 'MriViewer'
            figureName = [figureNameModality  'MriViewer: ' figureName];
        case 'Timefreq'
            figureName = [figureNameModality  'TF: ' figureName];
        case 'Spectrum'
            switch (FigureId.SubType)
                case 'TimeSeries'
                    figType = 'TS';
                case 'Spectrum'
                    figType = 'PSD';
                otherwise
                    figType = 'TF';
            end
            figureName = [figureNameModality figType ': ' figureName];
        case 'Pac'
            figureName = [figureNameModality 'PAC: ' figureName];
        case 'Connect'
            figureName = [figureNameModality 'Connect: ' figureName];
        case 'Image'
            % Add dependent file comment
            FileName = getappdata(hFig, 'FileName');
            if ~isempty(FileName)
                [sStudy, iStudy, iFile, DataType] = bst_get('AnyFile', FileName);
                if ~isempty(sStudy)
                    switch (DataType)
                        case {'data'}
                            % Get current montage
                            TsInfo = getappdata(hFig, 'TsInfo');
                            if isempty(TsInfo) || isempty(TsInfo.MontageName) || ~isempty(TsInfo.RowNames)
                                strMontage = 'All';
                            elseif strcmpi(TsInfo.MontageName, 'Average reference')
                                strMontage = 'AvgRef';
                            elseif strcmpi(TsInfo.MontageName, 'Bad channels')
                                strMontage = 'Bad';
                            else
                                strMontage = TsInfo.MontageName;
                            end
                            figureName = [figureNameModality strMontage ': ' figureName];
                            %figureName = ['Recordings: ' figureName];
                            imageFile = ['/' sStudy.Data(iFile).Comment];
                        case {'results', 'link'}
                            figureName = ['Sources: ' figureName];
                            imageFile = ['/' sStudy.Results(iFile).Comment];
                        case {'timefreq'}
                            figureName = ['Connect: ' figureName];
                            imageFile = ['/' sStudy.Timefreq(iFile).Comment];
                        case 'matrix'
                            figureName = ['Matrix: ' figureName];
                            imageFile = ['/' sStudy.Matrix(iFile).Comment];
                        case {'pdata', 'ptimefreq', 'presults', 'pmatrix'}
                            figureName = ['Stat: ' figureName];
                            imageFile = ['/' sStudy.Stat(iFile).Comment];
                    end
                    if ~isFileSet
                        figureName = [figureName, imageFile];
                    end
                end
            end
        case 'Video'
            FileName = getappdata(hFig, 'FileName');
            VideoFile = getappdata(hFig, 'VideoFile');
            if ~isempty(VideoFile)
                figureName = ['Video: ' VideoFile];
            elseif ~isempty(FileName)
                figureName = ['Video: ' FileName];
            else
                figureName = 'Video';
            end
        otherwise
            error(['Invalid figure type : ', FigureId.Type]);
    end
    
    % Update figure name
    set(hFig, 'Name', figureName);



%% ===== GET FIGURE =====
%Search for a registered figure in the GlobalData structure
% Usage : GetFigure(iDS, FigureId)
%         GetFigure(hFigure)
% To avoid one search criteria, just set it to []
function [hFigures, iFigures, iDataSets] = GetFigure(varargin)
    global GlobalData;
    hFigures  = [];
    iFigures  = [];
    iDataSets = [];
    if isempty(GlobalData) || isempty(GlobalData.DataSet)
        return;
    end

    % Call : GetFigure(iDS, FigureId)
    if (nargin == 2)
        iDS      = varargin{1};
        FigureId = varargin{2};
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            if (compareFigureId(FigureId, GlobalData.DataSet(iDS).Figure(iFig).Id))
                hFigures  = [hFigures,  GlobalData.DataSet(iDS).Figure(iFig).hFigure];
                iFigures  = [iFigures,  iFig];
                iDataSets = [iDataSets, iDS];
            end
        end
    % Call : GetFigure(hFigure)
    elseif (nargin == 1)
        hFig = varargin{1};
        for iDS = 1:length(GlobalData.DataSet)
            if ~isempty(GlobalData.DataSet(iDS).Figure)
                iFig = find([GlobalData.DataSet(iDS).Figure.hFigure] == hFig, 1);
                if ~isempty(iFig)
                    hFigures  = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
                    iFigures  = iFig;
                    iDataSets = iDS;
                    break
                end
            end
        end
    % Invalid call
    else
        error(['Usage : GetFigure(iDS, FigureId)' 10 ...
               '        GetFigure(DataFile, FigureId)' 10 ...
               '        GetFigure(hFigure)']);
    end

    

%% ===== GET ALL FIGURES =====
% Return handles of all the figures registred by Brainstorm
function hFigures = GetAllFigures()
    global GlobalData;
    hFigures  = [];
    % Process all DataSets
    for iDS = 1:length(GlobalData.DataSet)
        hFigures = [hFigures, GlobalData.DataSet(iDS).Figure.hFigure];
    end



%% ===== GET FIGURES WITH SURFACES ======
% Get all the Brainstorm 3DVIz figures that have at list on surface displayed in them
%  Usage : GetFigureWithSurfaces()
function [hFigs,iFigs,iDSs] = GetFigureWithSurfaces()
    hFigs = [];
    iFigs = [];
    iDSs  = [];
    % Get 3D Viz figures
    [hFigs3D, iFigs3D, iDSs3D] = GetFiguresByType('3DViz');
    % Loop to find figures with surfaces
    for i = 1:length(hFigs3D)
        if ~isempty(getappdata(hFigs3D(i), 'Surface'))
            hFigs(end+1) = hFigs3D(i);
            iFigs(end+1) = iFigs3D(i);
            iDSs(end+1)  = iDSs3D(i);
        end
    end


%% ===== GET FIGURE HANDLES =====
function [Handles,iFig,iDS] = GetFigureHandles(hFig) %#ok<DEFNU>
    global GlobalData;
    % Get figure description
    [hFig,iFig,iDS] = GetFigure(hFig);
    if ~isempty(iDS)
        % Return handles
        Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    else
        warning('Figure is not registered in Brainstorm.');
        Handles = [];
    end


%% ===== SET FIGURE HANDLES =====
function [Handles,iFig,iDS] = SetFigureHandles(hFig, Handles) %#ok<DEFNU>
    global GlobalData;
    % Get figure description
    [hFig,iFig,iDS] = GetFigure(hFig);
    if isempty(iDS)
        error('Figure is not registered in Brainstorm');
    end
    % Return handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = Handles;



%% ===== DELETE FIGURE =====
%  Usage : DeleteFigure(hFigure)
%          DeleteFigure(..., 'NoUnload') : do not unload the corresponding datasets
%          DeleteFigure(..., 'NoLayout') : do not call the layout manager
function DeleteFigure(hFigure, varargin)
    % % Parse inputs
    % NoUnload = any(strcmpi(varargin, 'NoUnload'));
    % NoLayout = any(strcmpi(varargin, 'NoLayout'));
    % isKeepAnatomy = 1;

    % FigureId = getappdata(hFigure,'FigureId');
    % % If the figure is a 3DViz figure
    %     if ishandle(hFigure) && isappdata(hFigure, 'Surface')
    %         % Signals the "Surfaces" and "Scouts" panel that a figure was closed
    %         panel_surface('UpdatePanel');
    %         % Remove scouts references
    %         panel_scout('RemoveScoutsFromFigure', hFigure);
    %         % Reset "Coordinates" panel
    %         if gui_brainstorm('isTabVisible', 'Coordinates')
    %             panel_coordinates('RemoveSelection');
    %         end
    %     end

    % % Delete graphic object
    if ishandle(hFigure)
        delete(hFigure);
    end

%% ======================================================================
%  ===== CALLBACK SHARED BY ALL FIGURES =================================
%  ======================================================================
%% ===== NAVIGATOR KEYPRESS =====
function NavigatorKeyPress( hFig, keyEvent )
    % Get figure description
    [hFig, iFig, iDS] = GetFigure(hFig);
    if isempty(hFig)
        return
    end

    % ===== PROCESS BY KEYS =====
    switch (keyEvent.Key)
        % === DATABASE NAVIGATOR ===
        case 'f1'
            if ismember('shift', keyEvent.Modifier)
                bst_navigator('DbNavigation', 'PreviousSubject', iDS);
            else
                bst_navigator('DbNavigation', 'NextSubject', iDS);
            end
        case 'f2'
            if ismember('shift', keyEvent.Modifier)
                bst_navigator('DbNavigation', 'PreviousCondition', iDS);
            else
                bst_navigator('DbNavigation', 'NextCondition', iDS);
            end
        case 'f3'
            if ismember('shift', keyEvent.Modifier)
                bst_navigator('DbNavigation', 'PreviousData', iDS);
            else
                bst_navigator('DbNavigation', 'NextData', iDS);
            end
        case 'f4'
            %             if ismember('shift', keyEvent.Modifier)
            %                 bst_navigator('DbNavigation', 'PreviousResult', iDS);
            %             else
            %                 bst_navigator('DbNavigation', 'NextResult', iDS);
            %             end
    end


%% ===== DOCK FIGURE =====
function DockFigure(hFig, isDocked)
    if isDocked
        set(hFig, 'WindowStyle', 'docked');
        ShowMatlabControls(hFig, 1);
        plotedit('off');
    else
        set(hFig, 'WindowStyle', 'normal');
        ShowMatlabControls(hFig, 0);
    end
    gui_layout('Update');


    
%% ===== SHOW MATLAB CONTROLS =====
function ShowMatlabControls(hFig, isMatlabCtrl)
    if ~isMatlabCtrl
        set(hFig, 'Toolbar', 'none', 'MenuBar', 'none');
        plotedit('off');
    else
        set(hFig, 'Toolbar', 'figure', 'MenuBar', 'figure');
        plotedit('on');
    end
    gui_layout('Update');


%% ===== SET BACKGROUND COLOR =====
function SetBackgroundColor(hFig, newColor) %#ok<*DEFNU>
    % Use previous scout color
    if (nargin < 2) || isempty(newColor)
        newColor = uisetcolor([0 0 0], 'Select scout color');
    end
    % If no color was selected: exit
    if (length(newColor) ~= 3)
        return
    end
    % Find all the dependent axes
    hAxes = findobj(hFig, 'Type', 'Axes')';
    % Set background
    set([hFig hAxes], 'Color', newColor);
    % Find opposite colors
    if (sum(newColor .^ 2) > 0.8)
        textColor = [0 0 0];
        topoColor = [0 0 0];
    else
        textColor = [.8 .8 .8];
        topoColor = [.4 .4 .4];
    end
    % Change color for buttons
    hControls = findobj(hFig, 'Type', 'uicontrol');
    if ~isempty(hControls)
        set(hControls, 'BackgroundColor', newColor);
    end
    % Change color of ears + nose
    hRefTopo = findobj(hFig, 'Tag', 'RefTopo');
    if ~isempty(hRefTopo)
        set(hRefTopo, 'Color', topoColor);
    end
    % Change color of topo circle
    hRefTopo = findobj(hFig, 'Tag', 'CircleTopo');
    if ~isempty(hRefTopo)
        set(hRefTopo, 'EdgeColor', topoColor);
    end
    % Change color of colorbar text
    hColorbar = findobj(hFig, 'Tag', 'Colorbar');
    if ~isempty(hColorbar)
        set(hColorbar, 'XColor', textColor, ...
                       'YColor', textColor);
    end



