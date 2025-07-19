classdef onetoneTestObj< matlab.apps.AppBase
   % Properties that correspond to obj components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        TabGroup                        matlab.ui.container.TabGroup
        MeasurementsTab                 matlab.ui.container.Tab
        ResultsPanel                    matlab.ui.container.Panel
        Label_2                         matlab.ui.control.Label
        P_1dBLabel                      matlab.ui.control.Label
        Label                           matlab.ui.control.Label
        GainLabel                       matlab.ui.control.Label
        UIAxes                          matlab.ui.control.UIAxes
        SettingsPanel                   matlab.ui.container.Panel
        MeasureButton                   matlab.ui.control.Button
        CalibrateforthesesettingsButton  matlab.ui.control.Button
        AttenuatoroffsetEditField       matlab.ui.control.NumericEditField
        AttenuatoroffsetEditFieldLabel  matlab.ui.control.Label
        FinalgeneratorgainEditField     matlab.ui.control.NumericEditField
        FinalgeneratorgainEditFieldLabel  matlab.ui.control.Label
        InitialgeneratorgainEditField   matlab.ui.control.NumericEditField
        InitialgeneratorgainEditFieldLabel  matlab.ui.control.Label
        Label_3                         matlab.ui.control.Label
        IP_1dBLabel                     matlab.ui.control.Label
    end

    properties (Access = private)
        appInstance;
        calibrationValid = 0;
        powerSteps;
        powerIn;
        powerOut;
        calPos=0;
        calibratorCalled=0;
    end

    methods (Access = private)
        function calibrator(obj, psd, f)
                [pks1, pksPos1] = findpeaks(psd, 'SortStr','descend');
                obj.powerIn(obj.calPos)=pks1(1)+obj.AttenuatoroffsetEditField.Value;
                obj.calibratorCalled=1;
        end

        function meter(obj, psd, f)
                [pks1, pksPos1] = findpeaks(psd, 'SortStr','descend');
                obj.powerOut(obj.calPos)=pks1(1)+obj.AttenuatoroffsetEditField.Value;
                obj.calibratorCalled=1;
        end
    end

    % Callbacks that handle component events
    methods (Access = private)
        function invalidateCalibration(obj)
            obj.CalibrateforthesesettingsButton.BackgroundColor=[0.6353 0.0784 0.1843];; % red
            obj.calibrationValid=0;
            obj.MeasureButton.Enable="off";
        end

        % Value changed function: InitialgeneratorgainEditField
        function InitialgeneratorgainEditFieldValueChanged(obj, event)
            obj.calibrationValid=0;
            invalidateCalibration(obj);
        end

        % Value changed function: FinalgeneratorgainEditField
        function FinalgeneratorgainEditFieldValueChanged(obj, event)
            obj.calibrationValid=0;
            invalidateCalibration(obj);
        end

        % % Value changed function: AttenuatoroffsetEditField
        function AttenuatoroffsetEditFieldValueChanged(obj, event)
            obj.calibrationValid=0;
            invalidateCalibration(obj);
        end
        function allertBeforeCalibration(obj, event)
            uialert(obj.appInstance.HackrfTXUIFigure,["Disconnect the DUT!", "Connect the HackRF directly to the Nesdr, then press OK."],"CotSA - Configuration reminder", ...
                'Icon','info','CloseFcn', @(h,e)CalibrateforthesesettingsButtonPushed(obj), "Modal",true);
        end

        function allertBeforeMeasure(obj, event)
            uialert(obj.appInstance.HackrfTXUIFigure,"Connect the DUT between the HackRF and the Nesdr, then press OK.","CotSA - Configuration reminder", ...
                'Icon','info','CloseFcn', @(h,e)MeasureButtonPushed(obj), "Modal",true);
        end
        % Button pushed function: CalibrateforthesesettingsButton
        function CalibrateforthesesettingsButtonPushed(obj, event)
            obj.MeasureButton.Enable="off";
            obj.CalibrateforthesesettingsButton.Enable="off";
            obj.AttenuatoroffsetEditField.Enable="off";
            obj.InitialgeneratorgainEditField.Enable='off';
            obj.FinalgeneratorgainEditField.Enable="off";
            obj.Label.Text = '-';
            obj.Label_2.Text = '-';
            obj.Label_3.Text = '-';
            cla(obj.UIAxes);
            obj.CalibrateforthesesettingsButton.BackgroundColor=[0.9290 0.6940 0.1250]; %yellow
            receiver = obj.appInstance.getRxTabObj;
            receiver.setAcquisitionMultiplier(3);
            gainDelta=(obj.FinalgeneratorgainEditField.Value-obj.InitialgeneratorgainEditField.Value);
            if(gainDelta == 0)
                obj.powerSteps = obj.InitialgeneratorgainEditField.Value;
            else
                obj.powerSteps  = obj.InitialgeneratorgainEditField.Value:1:obj.FinalgeneratorgainEditField.Value;
                obj.powerSteps = round(obj.powerSteps);
            end
            for pw = obj.powerSteps
                tx=obj.appInstance.getTxTabObj;
                rx=obj.appInstance.getRxTabObj;
                tx.setPowerGain(pw);
                rx.detachCallback;
                pause(2);
                rx.pause;
                callback = @(psd, f) obj.calibrator(psd, f);
                rx.attachCallback(callback);
                obj.calPos = find(obj.powerSteps==pw);
                rx.resume;
                while obj.calibratorCalled==0
                end
                rx.pause;
                obj.calibratorCalled=0;
                rx.detachCallback;
                rx.resume;
            end
            receiver.setAcquisitionMultiplier(1);
            obj.calibrationValid=1;
            obj.CalibrateforthesesettingsButton.BackgroundColor=[0.4660 0.6740 0.1880]; %green
            obj.MeasureButton.Enable="on";
            obj.CalibrateforthesesettingsButton.Enable="on";
            obj.AttenuatoroffsetEditField.Enable="on";
            obj.InitialgeneratorgainEditField.Enable='on';
            obj.FinalgeneratorgainEditField.Enable="on";
        end

        % Button pushed function: MeasureButton
        function MeasureButtonPushed(obj, event)
            obj.MeasureButton.Enable="off";
            obj.CalibrateforthesesettingsButton.Enable="off";
            obj.AttenuatoroffsetEditField.Enable="off";
            obj.InitialgeneratorgainEditField.Enable='off';
            obj.FinalgeneratorgainEditField.Enable="off";
            receiver = obj.appInstance.getRxTabObj;
            receiver.setAcquisitionMultiplier(3);
            for pw = obj.powerSteps
                tx=obj.appInstance.getTxTabObj;
                rx=obj.appInstance.getRxTabObj;
                tx.setPowerGain(pw);
                rx.detachCallback;
                pause(2);
                rx.pause;
                callback = @(psd, f) obj.meter(psd, f);
                rx.attachCallback(callback);
                obj.calPos = find(obj.powerSteps==pw);
                rx.resume;
                while obj.calibratorCalled==0
                end
                rx.pause;
                obj.calibratorCalled=0;
                rx.detachCallback;
                rx.resume;
            end
            receiver.setAcquisitionMultiplier(1);
            %hold on
            plot(obj.UIAxes, obj.powerIn, obj.powerOut);
            gain = mean((obj.powerOut(1:3)-obj.powerIn(1:3)));
            obj.Label.Text=[num2str(gain, 2), 'dB'];
            PoutTeory = obj.powerIn+gain;
            P1dbRaw = find(obj.powerOut<PoutTeory-1);
            if(~isempty(P1dbRaw))
                obj.Label_2.Text=[num2str(obj.powerOut(P1dbRaw(1)), 2), 'dBm']; 
                obj.Label_3.Text=[num2str(obj.powerIn(P1dbRaw(1)), 2), 'dBm'];
                yline(obj.UIAxes,obj.powerOut(P1dbRaw(1)), '--r', 'P1dB');
                xline(obj.UIAxes,obj.powerIn(P1dbRaw(1)), '--g','IP1dB');
            end
            %hold off
            obj.MeasureButton.Enable="on";
            obj.CalibrateforthesesettingsButton.Enable="on";
            obj.AttenuatoroffsetEditField.Enable="on";
            obj.InitialgeneratorgainEditField.Enable='on';
            obj.FinalgeneratorgainEditField.Enable="on";
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(obj)

            % Create SettingsPanel
            obj.SettingsPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.SettingsPanel.Title = 'Settings';
            obj.SettingsPanel.Position = [1 1 339 715];

            % Create InitialgeneratorgainEditFieldLabel
            obj.InitialgeneratorgainEditFieldLabel = uilabel(obj.SettingsPanel);
            obj.InitialgeneratorgainEditFieldLabel.HorizontalAlignment = 'right';
            obj.InitialgeneratorgainEditFieldLabel.Position = [54 638 114 22];
            obj.InitialgeneratorgainEditFieldLabel.Text = 'Initial generator gain';

            % Create InitialgeneratorgainEditField
            obj.InitialgeneratorgainEditField = uieditfield(obj.SettingsPanel, 'numeric');
            obj.InitialgeneratorgainEditField.Limits = [0 46];
            obj.InitialgeneratorgainEditField.ValueChangedFcn = createCallbackFcn(obj, @InitialgeneratorgainEditFieldValueChanged, true);
            obj.InitialgeneratorgainEditField.Position = [183 638 100 22];

            % Create FinalgeneratorgainEditFieldLabel
            obj.FinalgeneratorgainEditFieldLabel = uilabel(obj.SettingsPanel);
            obj.FinalgeneratorgainEditFieldLabel.HorizontalAlignment = 'right';
            obj.FinalgeneratorgainEditFieldLabel.Position = [57 602 112 22];
            obj.FinalgeneratorgainEditFieldLabel.Text = 'Final generator gain';

            % Create FinalgeneratorgainEditField
            obj.FinalgeneratorgainEditField = uieditfield(obj.SettingsPanel, 'numeric');
            obj.FinalgeneratorgainEditField.Limits = [1 47];
            obj.FinalgeneratorgainEditField.ValueChangedFcn = createCallbackFcn(obj, @FinalgeneratorgainEditFieldValueChanged, true);
            obj.FinalgeneratorgainEditField.Position = [184 602 100 22];
            obj.FinalgeneratorgainEditField.Value = 47;

            % Create AttenuatoroffsetEditFieldLabel
            obj.AttenuatoroffsetEditFieldLabel = uilabel(obj.SettingsPanel);
            obj.AttenuatoroffsetEditFieldLabel.HorizontalAlignment = 'right';
            obj.AttenuatoroffsetEditFieldLabel.Position = [76 566 93 22];
            obj.AttenuatoroffsetEditFieldLabel.Text = 'Attenuator offset';

            % Create AttenuatoroffsetEditField
            obj.AttenuatoroffsetEditField = uieditfield(obj.SettingsPanel, 'numeric');
            obj.AttenuatoroffsetEditField.Limits = [0 100];
            obj.AttenuatoroffsetEditField.ValueChangedFcn = createCallbackFcn(obj, @AttenuatoroffsetEditFieldValueChanged, true);
            obj.AttenuatoroffsetEditField.Position = [184 566 100 22];

            % Create CalibrateforthesesettingsButton
            obj.CalibrateforthesesettingsButton = uibutton(obj.SettingsPanel, 'push');
            obj.CalibrateforthesesettingsButton.ButtonPushedFcn = createCallbackFcn(obj, @allertBeforeCalibration, true);
            obj.CalibrateforthesesettingsButton.Position = [102 518 158 23];
            obj.CalibrateforthesesettingsButton.BackgroundColor=[0.6353 0.0784 0.1843]; % red
            obj.CalibrateforthesesettingsButton.Text = 'Calibrate for these settings';

            % Create MeasureButton
            obj.MeasureButton = uibutton(obj.SettingsPanel, 'push');
            obj.MeasureButton.ButtonPushedFcn = createCallbackFcn(obj, @allertBeforeMeasure, true);
            obj.MeasureButton.Position = [131 469 100 23];
            obj.MeasureButton.Text = 'Measure';
            obj.MeasureButton.Enable="off";

            % Create ResultsPanel
            obj.ResultsPanel =  uipanel(obj.appInstance.MeasurementsTab);
            obj.ResultsPanel.Title = 'Results';
            obj.ResultsPanel.Position = [339 1 630 715];

            % Create UIAxes
            obj.UIAxes = uiaxes(obj.ResultsPanel);
            title(obj.UIAxes, 'Power Transfer Curve')
            xlabel(obj.UIAxes, 'Power input (dBm)')
            ylabel(obj.UIAxes, 'Power output (dBm)')
            obj.UIAxes.Position = [29 229 574 444];

            % Create GainLabel
            obj.GainLabel = uilabel(obj.ResultsPanel);
            obj.GainLabel.Interpreter = 'latex';
            obj.GainLabel.Position = [69 162 39 22];
            obj.GainLabel.Text = 'Gain:';

            % Create Label
            obj.Label = uilabel(obj.ResultsPanel);
            obj.Label.Position = [113 162 59 22];
            obj.Label.Text = '-';

            % Create P_1dBLabel
            obj.P_1dBLabel = uilabel(obj.ResultsPanel);
            obj.P_1dBLabel.Interpreter = 'latex';
            obj.P_1dBLabel.Position = [70 129 36 22];
            obj.P_1dBLabel.Text = '$P_{1dB}$:';

            % Create Label_2
            obj.Label_2 = uilabel(obj.ResultsPanel);
            obj.Label_2.Position = [114 129 58 22];
            obj.Label_2.Text = '-';

                        % Create IP_1dBLabel
            obj.IP_1dBLabel = uilabel(obj.ResultsPanel);
            obj.IP_1dBLabel.Interpreter = 'latex';
            obj.IP_1dBLabel.Position = [63 107 43 22];
            obj.IP_1dBLabel.Text = '$IP_{1dB}$:';

            % Create Label_3
            obj.Label_3 = uilabel(obj.ResultsPanel);
            obj.Label_3.Position = [114 97 58 22];
            obj.Label_3.Text = '-';
        end
    end

    % obj creation and deletion
    methods (Access = public)

        % Construct obj
        function obj = onetoneTestObj(app)
            obj.appInstance=app;
            % Create UIFigure and components
            createComponents(obj)
            
        end

        function deleteUI(obj)
            delete(obj.SettingsPanel);
            delete(obj.ResultsPanel);
        end
        % Code that executes before obj deletion
        function delete(obj)
            % Delete UIFigure when obj is deleted
        end
    end
end


 