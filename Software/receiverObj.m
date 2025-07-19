classdef receiverObj < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ReceiverPanel                   matlab.ui.container.Panel
        SpectrogramPanel                matlab.ui.container.Panel
        ReceiversettingsPanel           matlab.ui.container.Panel
        GaindBSlider                    matlab.ui.control.Slider
        GaindBSliderLabel               matlab.ui.control.Label
        GaindBReadoutSliderLabel           matlab.ui.control.Label
        CenterfrqeuencyHzEditField      matlab.ui.control.NumericEditField
        CenterfrqeuencyHzEditFieldLabel  matlab.ui.control.Label
        WarningaudiodecodingisanintensivetaskLabel  matlab.ui.control.Label
        DecodeButtonGroup               matlab.ui.container.ButtonGroup
        FMaudioButton_2                 matlab.ui.control.RadioButton
        AMaudioButton_2                 matlab.ui.control.RadioButton
        NoneButton_3                    matlab.ui.control.RadioButton
        MatchedfilterButtonGroup_2      matlab.ui.container.ButtonGroup
        GaussianButton_2                matlab.ui.control.RadioButton
        RisedcosineButton_2             matlab.ui.control.RadioButton
        NoneButton_2                    matlab.ui.control.RadioButton
        UIAxes                          matlab.ui.control.UIAxes
        RBWHzEditField                  matlab.ui.control.NumericEditField
        RBWHzEditFieldLabel             matlab.ui.control.Label
        StartStopRXSwitch               matlab.ui.control.Switch
        StartStopRXSwitchLabel          matlab.ui.control.Label
        ShowtableButton                 matlab.ui.control.Button
        MarkersSpinner                  matlab.ui.control.Spinner
        MarkersSpinnerLabel             matlab.ui.control.Label
        AttenuatoroffsetdBEditField     matlab.ui.control.NumericEditField
        AttenuatoroffsetdBLabel         matlab.ui.control.Label
    end

    % Properties used inside the rx tab
    properties (Access = private)
        appInstance; % reference to the creator
        rtlRadio; % the rtl sdr object
        rxTimer; % rx callback timer
        samplingTime; % timer required by the callback (sampling time + processing time)
        requiredPoints; % number of points required for a certain resolution
        cycleOffset=1; % processing time required by the rx callback
        powCalibration; % calibration file
        calibFactor; % computed calibration factor from calibration file
        DialogApp; % a place to store a pointer to the marker table window
        tableOpenFlag; % stores if the marker table window is open or not
        callbackHandle;
        callbackEnable=0;
        callbackHandleRaw;
        callbackEnableRaw = 0;
        acqMult=1;
    end

    properties (Access = protected)

    end
    % Spectrogram methods
    methods (Access = public)
        function pause(obj)
            stop(obj.rxTimer);
        end
        function resume(obj)
            start(obj.rxTimer);
        end
        % get carrier frequency
        function carrier=getCarrier(obj)
            carrier = obj.CenterfrqeuencyHzEditField.Value;
        end

        function setAcquisitionMultiplier(obj, multiplier)
            if multiplier >=1
                obj.acqMult=multiplier;
                RBWHzEditFieldChanged(obj);
            end
        end

        function setCarrier(obj, newCarrier)
            obj.CenterfrqeuencyHzEditField.Value=newCarrier;
            obj.CenterfrqeuencyHzEditFieldChanged;
        end

        function attachRawCallback(obj, handle)
            obj.callbackHandleRaw = handle;
            obj.callbackEnableRaw = 1;
        end

        function detachRawCallback(obj)
            obj.callbackEnableRaw = 0;
        end

        function attachCallback(obj, handle)
            obj.callbackHandle = handle;
            obj.callbackEnable=1;
        end

        function detachCallback(obj)
            obj.callbackEnable=0;
        end

        function rxRunner(obj)
            % faccio un timer di durata rbw*fs (o qualcosa del genere) e tiro
            % giù solo i campioni che mi servono, ogni volta che li ho, plotto
            %rcv = obj.rtlRadio();
            rcv = capture(obj.rtlRadio, obj.requiredPoints);
            rcv = rcv - mean(rcv);  % Remove DC component.
            if ~isempty(rcv) % if we received something
                [Pxx, f] = pwelch(rcv, [], [], obj.requiredPoints, 2.4e6, 'centered', 'power'); % find power with welch method
                Pxx_dB = 10 * log10(Pxx); %convert to db
                f=f+obj.CenterfrqeuencyHzEditField.Value; % shift f scale from bb to tuned band
                calVal = interp1(obj.powCalibration.actualFreq, obj.calibFactor, f, 'linear', 'extrap'); % compute calibration values
                Pxx_dB = Pxx_dB + calVal - obj.rtlRadio.TunerGain; % calibrate power
                pxx_dbUntouched = Pxx_dB;
                Pxx_dB = Pxx_dB + obj.AttenuatoroffsetdBEditField.Value;
                % Update UIAxes plot
                if(obj.MarkersSpinner.Value>0) % if we want markers
                    [pks, pksPos] = findpeaks(Pxx_dB, f);
                    pksMatrix = [pks pksPos];
                    pksMatrix = sortrows(pksMatrix, 'descend');
                    plot(obj.UIAxes, f, Pxx_dB, pksMatrix(1:obj.MarkersSpinner.Value,2), pksMatrix(1:obj.MarkersSpinner.Value,1),"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                    text(obj.UIAxes, pksMatrix(1:obj.MarkersSpinner.Value,2),pksMatrix(1:obj.MarkersSpinner.Value,1),num2str((1:numel(pksMatrix(1:obj.MarkersSpinner.Value,2)))'),"Color","white","HorizontalAlignment","center");
                    if(obj.tableOpenFlag==1) % if marker table is open, let's update it
                        obj.DialogApp.updateTable(pksMatrix(1:obj.MarkersSpinner.Value,2),pksMatrix(1:obj.MarkersSpinner.Value,1));
                    end
                else
                    plot(obj.UIAxes, f, Pxx_dB);
                end
                if obj.callbackEnable==1
                    feval(obj.callbackHandle, pxx_dbUntouched, f);
                end
                if obj.callbackEnableRaw==1
                    feval(obj.callbackHandleRaw, rcv);
                end
            end
        end
    end

    % Callback methods
    methods (Access = private)
        % Handle markers table open request
        function ShowtableButtonPressed(obj, event)
            obj.DialogApp = Markerstable(obj.appInstance);
            obj.tableOpenFlag=1;
        end

        % Handle start/stop processing
        function StartStopRXSwitchChanged(obj, event)
            obj.StartStopRXSwitch.Value;
            if isequal(obj.StartStopRXSwitch.Value, 'On')
                if obj.samplingTime>= 0.001
                    obj.rxTimer.period=obj.samplingTime+obj.cycleOffset;
                else
                    obj.rxTimer.period=0.001+obj.cycleOffset;
                end
                start(obj.rxTimer);
            else
                stop(obj.rxTimer);
            end      
        end

        % Handle resolution change request
        function RBWHzEditFieldChanged(obj, event)
            N=2.4e6/obj.RBWHzEditField.Value;
            obj.requiredPoints = round(N);
            obj.samplingTime = obj.requiredPoints*obj.acqMult*(1/2.4e6);
            obj.samplingTime = round(obj.samplingTime*1000)/1000;
            if isequal(obj.StartStopRXSwitch.Value, 'On')
                stop(obj.rxTimer);
                if obj.samplingTime>= 0.001
                    obj.rxTimer.period=obj.samplingTime+obj.cycleOffset;
                else
                    obj.rxTimer.period=0.001+obj.cycleOffset;
                end
                start(obj.rxTimer);
            else
                if obj.samplingTime>= 0.001
                    obj.rxTimer.period=obj.samplingTime+obj.cycleOffset;
                else
                    obj.rxTimer.period=0.001+obj.cycleOffset;
                end
            end
            obj.RBWHzEditField.Value = 2.4e6/obj.requiredPoints;
        end

        % Handle demodulation change
        function DecodeButtonGroupChanged(obj, event)
            if obj.DecodeButtonGroup.SelectedObject==obj.NoneButton_3
                obj.WarningaudiodecodingisanintensivetaskLabel.Visible ="off";
            else
                obj.WarningaudiodecodingisanintensivetaskLabel.Visible ="on";
            end
        end

        % Handle gain change
        function GaindBSliderChanged(obj, event)
            availableGains = [0 0.9000 1.4000 2.7000 3.7000 7.7000...
                8.7000 12.5000 14.4000 15.7000 16.6000 19.7000 20.7000 22.9000 25.4000...
                28 29.7000 32.8000 33.8000 36.4000 37.2000 38.6000 40.2000 42.1000 43.4000 43.9000 44.5000 48 49.6000];
            obj.GaindBSlider.Value = interp1(availableGains,availableGains, obj.GaindBSlider.Value, 'nearest');
            obj.GaindBReadoutSliderLabel.Text = sprintf("%.1f dB", obj.GaindBSlider.Value);
            obj.rtlRadio.TunerGain=obj.GaindBSlider.Value;
        end

        % Handle frequency change
        function CenterfrqeuencyHzEditFieldChanged(obj, event)
            obj.rtlRadio.CenterFrequency=obj.CenterfrqeuencyHzEditField.Value;
        end
    end

    % UI generation methods
    methods (Access = private)
        function createUIComponents(obj)
            % Create ReceiverPanel
            obj.ReceiverPanel = uipanel(obj.appInstance.BasicTab);
            obj.ReceiverPanel.Title = 'Receiver';
            obj.ReceiverPanel.Position = [0 0 971 397];

            % Create ReceiversettingsPanel
            obj.ReceiversettingsPanel = uipanel(obj.ReceiverPanel);
            obj.ReceiversettingsPanel.Title = 'Receiver settings';
            obj.ReceiversettingsPanel.Position = [0 0 283 377];

            % % Create MatchedfilterButtonGroup_2
            % obj.MatchedfilterButtonGroup_2 = uibuttongroup(obj.ReceiversettingsPanel);
            % obj.MatchedfilterButtonGroup_2.Title = 'Matched filter';
            % obj.MatchedfilterButtonGroup_2.Position = [12 142 114 106];
            % 
            % % Create NoneButton_2
            % obj.NoneButton_2 = uiradiobutton(obj.MatchedfilterButtonGroup_2);
            % obj.NoneButton_2.Text = 'None';
            % obj.NoneButton_2.Position = [11 60 58 22];
            % obj.NoneButton_2.Value = true;
            % 
            % % Create RisedcosineButton_2
            % obj.RisedcosineButton_2 = uiradiobutton(obj.MatchedfilterButtonGroup_2);
            % obj.RisedcosineButton_2.Text = 'Rised cosine';
            % obj.RisedcosineButton_2.Position = [11 38 90 22];
            % 
            % % Create GaussianButton_2
            % obj.GaussianButton_2 = uiradiobutton(obj.MatchedfilterButtonGroup_2);
            % obj.GaussianButton_2.Text = 'Gaussian';
            % obj.GaussianButton_2.Position = [11 16 72 22];

            % Create DecodeButtonGroup
            obj.DecodeButtonGroup = uibuttongroup(obj.ReceiversettingsPanel);
            obj.DecodeButtonGroup.SelectionChangedFcn = createCallbackFcn(obj, @DecodeButtonGroupChanged, true);
            obj.DecodeButtonGroup.Title = 'Decode';
            obj.DecodeButtonGroup.Position = [149 142 112 106];

            % Create NoneButton_3
            obj.NoneButton_3 = uiradiobutton(obj.DecodeButtonGroup);
            obj.NoneButton_3.Text = 'None';
            obj.NoneButton_3.Position = [11 60 58 22];
            obj.NoneButton_3.Value = true;

            % Create AMaudioButton_2
            obj.AMaudioButton_2 = uiradiobutton(obj.DecodeButtonGroup);
            obj.AMaudioButton_2.Text = 'AM audio';
            obj.AMaudioButton_2.Position = [11 38 72 22];

            % Create FMaudioButton_2
            obj.FMaudioButton_2 = uiradiobutton(obj.DecodeButtonGroup);
            obj.FMaudioButton_2.Text = 'FM audio';
            obj.FMaudioButton_2.Position = [11 16 72 22];

            % Create WarningaudiodecodingisanintensivetaskLabel
            obj.WarningaudiodecodingisanintensivetaskLabel = uilabel(obj.ReceiversettingsPanel);
            obj.WarningaudiodecodingisanintensivetaskLabel.FontWeight = 'bold';
            obj.WarningaudiodecodingisanintensivetaskLabel.FontColor = [0.6353 0.0784 0.1843];
            obj.WarningaudiodecodingisanintensivetaskLabel.Visible = 'off';
            obj.WarningaudiodecodingisanintensivetaskLabel.Position = [8 103 269 22];
            obj.WarningaudiodecodingisanintensivetaskLabel.Text = 'Warning: audio decoding is CPU intensive!';

            % Create CenterfrqeuencyHzEditFieldLabel
            obj.CenterfrqeuencyHzEditFieldLabel = uilabel(obj.ReceiversettingsPanel);
            obj.CenterfrqeuencyHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.CenterfrqeuencyHzEditFieldLabel.Position = [12 327 122 22];
            obj.CenterfrqeuencyHzEditFieldLabel.Text = 'Center frqeuency [Hz]';

            % Create CenterfrqeuencyHzEditField
            obj.CenterfrqeuencyHzEditField = uieditfield(obj.ReceiversettingsPanel, 'numeric');
            obj.CenterfrqeuencyHzEditField.Position = [149 325 100 22];
            obj.CenterfrqeuencyHzEditField.Limits = [26000000 1.6e9];
            obj.CenterfrqeuencyHzEditField.Value = 101000000;
            obj.CenterfrqeuencyHzEditField.ValueChangedFcn = createCallbackFcn(obj, @CenterfrqeuencyHzEditFieldChanged, true);

            % Create GaindBSliderLabel
            obj.GaindBSliderLabel = uilabel(obj.ReceiversettingsPanel);
            obj.GaindBSliderLabel.HorizontalAlignment = 'right';
            obj.GaindBSliderLabel.Position = [12 284 55 22];
            obj.GaindBSliderLabel.Text = 'Gain [dB]';

            % Create GaindBSlider
            obj.GaindBSlider = uislider(obj.ReceiversettingsPanel);
            obj.GaindBSlider.Limits = [0 49.6];
            obj.GaindBSlider.MajorTicks = [0 8.7 19.7 29.7 38.6 49.6];
            obj.GaindBSlider.MinorTicks = [0 0.9000 1.4000 2.7000 3.7000 7.7000...
                8.7000 12.5000 14.4000 15.7000 16.6000 19.7000 20.7000 22.9000 25.4000...
                28 29.7000 32.8000 33.8000 36.4000 37.2000 38.6000 40.2000 42.1000 43.4000 43.9000 44.5000 48 49.6000];
            obj.GaindBSlider.ValueChangedFcn = createCallbackFcn(obj, @GaindBSliderChanged, true);
            obj.GaindBSlider.Position = [88 293 150 3];

            % Create GaindBSliderLabel
            obj.GaindBReadoutSliderLabel = uilabel(obj.ReceiversettingsPanel);
            obj.GaindBReadoutSliderLabel.HorizontalAlignment = 'right';
            obj.GaindBReadoutSliderLabel.Position = [12 262 55 22];
            obj.GaindBReadoutSliderLabel.Text = sprintf("%.1f dB", obj.GaindBSlider.Value);


            % Create SpectrogramPanel
            obj.SpectrogramPanel = uipanel(obj.ReceiverPanel);
            obj.SpectrogramPanel.Title = 'Spectrogram';
            obj.SpectrogramPanel.Position = [282 0 689 377];

            % Create UIAxes
            obj.UIAxes = uiaxes(obj.SpectrogramPanel);
            xlabel(obj.UIAxes, 'Frequency [Hz]')
            ylabel(obj.UIAxes, 'Power [dBm]')
            % Set fixed axis limits
            %xlim(obj.UIAxes, [-1.2e6+obj.CenterfrqeuencyHzEditField.Value, 1.2e6+obj.CenterfrqeuencyHzEditField.Value]); % Fixed frequency range
            ylim(obj.UIAxes, [-140, 10]);    % Fixed power range
            obj.UIAxes.Position = [12 46 656 301];

            % Create RBWHzEditFieldLabel
            obj.RBWHzEditFieldLabel = uilabel(obj.SpectrogramPanel);
            obj.RBWHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.RBWHzEditFieldLabel.Position = [11 15 58 22];
            obj.RBWHzEditFieldLabel.Text = 'RBW [Hz]';

            % Create RBWHzEditField
            obj.RBWHzEditField = uieditfield(obj.SpectrogramPanel, 'numeric');
            obj.RBWHzEditField.Position = [84 15 100 22];
            obj.RBWHzEditField.Limits = [1 1171];
            obj.RBWHzEditField.Value = 20; %100
            obj.RBWHzEditField.ValueChangedFcn = createCallbackFcn(obj, @RBWHzEditFieldChanged, true);

            % Create StartStopRXSwitchLabel
            obj.StartStopRXSwitchLabel = uilabel(obj.ReceiversettingsPanel);
            obj.StartStopRXSwitchLabel.HorizontalAlignment = 'center';
            obj.StartStopRXSwitchLabel.FontWeight = 'bold';
            obj.StartStopRXSwitchLabel.Position = [165 21 82 22];
            obj.StartStopRXSwitchLabel.Text = 'Start/Stop RX';

            % Create StartStopRXSwitch
            obj.StartStopRXSwitch = uiswitch(obj.ReceiversettingsPanel, 'slider');
            obj.StartStopRXSwitch.Position = [182 58 45 20];
            obj.StartStopRXSwitch.ValueChangedFcn = createCallbackFcn(obj, @StartStopRXSwitchChanged, true);
        
            % Create MarkersSpinnerLabel
            obj.MarkersSpinnerLabel = uilabel(obj.SpectrogramPanel);
            obj.MarkersSpinnerLabel.HorizontalAlignment = 'right';
            obj.MarkersSpinnerLabel.Position = [430 16 48 22];
            obj.MarkersSpinnerLabel.Text = 'Markers';

            % Create MarkersSpinner
            obj.MarkersSpinner = uispinner(obj.SpectrogramPanel);
            obj.MarkersSpinner.Limits = [0 10];
            obj.MarkersSpinner.Position = [493 16 57 22];

            % Create ShowtableButton
            obj.ShowtableButton = uibutton(obj.SpectrogramPanel, 'push');
            obj.ShowtableButton.Position = [568 16 100 22];
            obj.ShowtableButton.Text = 'Show table';
            obj.ShowtableButton.ButtonPushedFcn = createCallbackFcn(obj, @ShowtableButtonPressed, true);

            % Create AttenuatoroffsetdBLabel
            obj.AttenuatoroffsetdBLabel = uilabel(obj.ReceiversettingsPanel);
            obj.AttenuatoroffsetdBLabel.HorizontalAlignment = 'right';
            obj.AttenuatoroffsetdBLabel.Position = [12 218 60 30];
            obj.AttenuatoroffsetdBLabel.Text = {'Attenuator'; 'offset [dB]'};

            % Create AttenuatoroffsetdBEditField
            obj.AttenuatoroffsetdBEditField = uieditfield(obj.ReceiversettingsPanel, 'numeric');
            obj.AttenuatoroffsetdBEditField.Limits = [0 200];
            obj.AttenuatoroffsetdBEditField.Position = [79 227 49 21];
            obj.AttenuatoroffsetdBEditField.Value = 0;

            % Temp disables
            set(obj.GaussianButton_2,'Enable','off');
            set(obj.RisedcosineButton_2,'Enable','off');
            set(obj.FMaudioButton_2,'Enable','off');
            set(obj.AMaudioButton_2,'Enable','off');

        end
    end

    % Object creation
    methods (Access = public)
        % object creator
        function obj=receiverObj(app)
            obj.appInstance=app;
            createUIComponents(obj);
            try
                obj.rtlRadio = comm.SDRRTLReceiver('0','CenterFrequency',obj.CenterfrqeuencyHzEditField.Value,'SampleRate',2.4e6, ...
                    'SamplesPerFrame',2048,'EnableTunerAGC',false,'OutputDataType','double');
            catch
                uialert(obj.appInstance.HackrfTXUIFigure,["RTL-SDR wasn't found during startup!", "Check connections and try again (RTL-SDR MUST be connected while using this program)."],"RTL device not found!", ...
                    'CloseFcn', @(h,e)delete(obj.appInstance), "Modal",true); % if rtl-sdr is not present, app can't be used
            end
            % Load Calibration File
            if exist('calPow.mat', 'file')
                obj.powCalibration = load('calPow.mat');
                obj.calibFactor = obj.powCalibration.sigPow-obj.powCalibration.freqPow;
            else
               % uialert(obj.appInstance.HackrfTXUIFigure,["RTL-SDR calibration wasn't found during startup!", "This program can't run without the calibration file! Try to run setup again or check the program directory."], "Calibration not found!", ...
                %    'CloseFcn', @(h,e)delete(obj.appInstance), "Modal",true); % Calibration file not present, corrupted program
            end
            RBWHzEditFieldChanged(obj); % let's update the timer time with the callback function
            obj.rxTimer = timer('ExecutionMode', 'fixedRate', 'Period', obj.samplingTime+obj.cycleOffset, ...
                'TimerFcn', @(~,~)obj.rxRunner);
            obj.tableOpenFlag=0;
        end

        function deleteUI(obj)
            delete(obj.ReceiverPanel);
            delete(obj.SpectrogramPanel);
            delete(obj.ReceiversettingsPanel);
            delete(obj.GaindBSlider);
            delete(obj.GaindBSliderLabel);
            delete(obj.GaindBReadoutSliderLabel);
            delete(obj.CenterfrqeuencyHzEditField);
            delete(obj.CenterfrqeuencyHzEditFieldLabel);
            delete(obj.WarningaudiodecodingisanintensivetaskLabel);
            delete(obj.DecodeButtonGroup);
            delete(obj.FMaudioButton_2);
            delete(obj.AMaudioButton_2);
            delete(obj.NoneButton_3);
            delete(obj.MatchedfilterButtonGroup_2);
            delete(obj.GaussianButton_2);
            delete(obj.RisedcosineButton_2);
            delete(obj.NoneButton_2);
            delete(obj.UIAxes);
            delete(obj.RBWHzEditField);
            delete(obj.RBWHzEditFieldLabel);
            delete(obj.StartStopRXSwitch);
            delete(obj.StartStopRXSwitchLabel);
            delete(obj.ShowtableButton);
            delete(obj.MarkersSpinner);
            delete(obj.MarkersSpinnerLabel);
        end
        % object deletion at program shutdown
        function delete(obj)
            if isequal(obj.StartStopRXSwitch.Value, 'On') % If we are receiving, let's correctly terminate reception
                stop(obj.rxTimer);
                obj.StartStopRXSwitch.Value = 'Off';
            end
            delete(obj.rxTimer);
            release(obj.rtlRadio);
            if obj.tableOpenFlag==1 % if markers table window is open, let's close it
                obj.DialogApp.externalClose();
                obj.tableOpenFlag=0;
            end
            deleteUI(obj);
        end
    end
end


