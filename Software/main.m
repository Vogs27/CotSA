classdef main < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        HackrfTXUIFigure                matlab.ui.Figure
        TabGroup                        matlab.ui.container.TabGroup
        BasicTab                        matlab.ui.container.Tab
        MeasurementsTab                 matlab.ui.container.Tab
    end

    properties (Access = private)
        TxTabObj
        RxTabObj
        MeasTabObj
        prevMeasMode=-1;
    end

    % Getters and setters
    methods (Access = public)
        function receiver = getRxTabObj(app)
            receiver = app.RxTabObj;
        end

        function transmitter = getTxTabObj(app)
            transmitter = app.TxTabObj;
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.TxTabObj=transmitterObj(app);
            app.RxTabObj=receiverObj(app);
          % app.MeasTabObj=TwoTonesTestObj(app);
        end

        % Close request function: HackrfTXUIFigure
        function HackrfTXUIFigureCloseRequest(app, event)
            delete(app.TxTabObj);
            delete(app.RxTabObj);
            delete(app); % close app
        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            selectedTab = app.TabGroup.SelectedTab;
            prevTab = event.OldValue;
            switch selectedTab
                case app.BasicTab % Basic tab was selected
                    % switch app.TxTabObj.getMeasurementMode
                    %     case {4, 7}
                    %         app.MeasTabObj=TwoTonesTestObj(app);
                    % end
                case app.MeasurementsTab % Measure tab was selected
                    if (app.prevMeasMode ~= app.TxTabObj.getMeasurementMode)
                        if(app.prevMeasMode~= -1)
                            app.MeasTabObj.deleteUI;
                            app.RxTabObj.detachCallback;
                            app.RxTabObj.detachRawCallback;
                        end
                        switch app.TxTabObj.getMeasurementMode
                            case {0}
                                app.RxTabObj.setCarrier(app.TxTabObj.getCarrier);
                                app.MeasTabObj=onetoneTestObj(app);
                            case {4}
                                app.RxTabObj.setCarrier(app.TxTabObj.getFirstTone);
                                app.MeasTabObj=TwoTonesTestObj(app);
                                app.MeasTabObj.setCarrierFreq(app.TxTabObj.getCarrier);
                                app.MeasTabObj.setToneFreq(app.TxTabObj.getFirstTone);
                                %app.MeasTabObj.setCenterFreq(app.RxTabObj.getCarrier);
                                app.MeasTabObj.setSpan(2.4e6);
                                callback = @(psd, f) app.MeasTabObj.dataProcessor(psd, f);
                                app.RxTabObj.attachCallback(callback);
                            case {7}
                                app.RxTabObj.setCarrier(app.TxTabObj.getSecondTone);
                                app.MeasTabObj=TwoTonesTestObj(app);
                                app.MeasTabObj.setCarrierFreq(app.TxTabObj.getFirstTone);
                                app.MeasTabObj.setToneFreq(app.TxTabObj.getSecondTone);
                                %app.MeasTabObj.setCenterFreq(app.RxTabObj.getCarrier);
                                app.MeasTabObj.setSpan(2.4e6);
                                callback = @(psd, f) app.MeasTabObj.dataProcessor(psd, f);
                                app.RxTabObj.attachCallback(callback);
                            case {5}
                                app.MeasTabObj=QAMtest(app);
                                callback = @(samples) app.MeasTabObj.dataProcessor(samples);
                                app.RxTabObj.attachRawCallback(callback);
                        end
                        app.prevMeasMode = app.TxTabObj.getMeasurementMode;
                    end
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create HackrfTXUIFigure and hide until all components are created
            app.HackrfTXUIFigure = uifigure('Visible', 'off');
            app.HackrfTXUIFigure.Position = [10 60 970 743];
            app.HackrfTXUIFigure.Name = 'CotsSA v.0.3';
            app.HackrfTXUIFigure.Icon = fullfile(pathToMLAPP, 'icon.png');
            app.HackrfTXUIFigure.Resize = 'off';
            app.HackrfTXUIFigure.CloseRequestFcn = createCallbackFcn(app, @HackrfTXUIFigureCloseRequest, true);

            % Create TabGroup
            app.TabGroup = uitabgroup(app.HackrfTXUIFigure);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Position = [1 4 971 740];

            % Create SignalgeneratorTab
            app.BasicTab = uitab(app.TabGroup);
            app.BasicTab.Title = 'Basic';

            % Create MeasurementsTab
            app.MeasurementsTab = uitab(app.TabGroup);
            app.MeasurementsTab.Title = 'Measurements';

            % Show the figure after all components are created
            app.HackrfTXUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = main

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.HackrfTXUIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.HackrfTXUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            delete(app.TxTabObj);
            delete(app.RxTabObj);
            % Delete UIFigure when app is deleted
            delete(app.HackrfTXUIFigure)
        end
    end
end