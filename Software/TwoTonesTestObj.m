classdef TwoTonesTestObj < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        PowersweepresultsPanel          matlab.ui.container.Panel
        UITable                         matlab.ui.control.Table
        ResultsPanel                    matlab.ui.container.Panel
        OthersettingsPanel              matlab.ui.container.Panel
        CalibrateforthissettingsButton  matlab.ui.control.Button
        PowerstepsEditField             matlab.ui.control.NumericEditField
        PowerstepsEditFieldLabel        matlab.ui.control.Label
        HigheststimuluspowerEditField   matlab.ui.control.NumericEditField
        HigheststimuluspowerEditFieldLabel  matlab.ui.control.Label
        LoweststimuluspowerEditField    matlab.ui.control.NumericEditField
        LoweststimuluspowerEditFieldLabel  matlab.ui.control.Label
        SaveresultstomatfileButton      matlab.ui.control.Button
        AveragingEditField              matlab.ui.control.NumericEditField
        AveragingEditFieldLabel         matlab.ui.control.Label
        InputattenuatordBEditField      matlab.ui.control.NumericEditField
        InputattenuatordBEditFieldLabel  matlab.ui.control.Label
        IP3Res                          matlab.ui.control.Label
        IntPow                          matlab.ui.control.Label
        SecondPow                          matlab.ui.control.Label
        FirstPow                          matlab.ui.control.Label
        IntFreq                          matlab.ui.control.Label
        SecondFreq                          matlab.ui.control.Label
        FirstFreq                           matlab.ui.control.Label
        CalculatedIP3Label              matlab.ui.control.Label
        IntermodulationproductpowerLabel  matlab.ui.control.Label
        SecondtonepowerLabel            matlab.ui.control.Label
        FirsttonepowerLabel             matlab.ui.control.Label
        IntermodulationproductfrequencyLabel  matlab.ui.control.Label
        SecondtonefrequencyLabel        matlab.ui.control.Label
        FirsttonefrequencyLabel         matlab.ui.control.Label
        SpectrumliveviewPanel           matlab.ui.container.Panel
        UIAxes                          matlab.ui.control.UIAxes
        PeakssearchparametersPanel      matlab.ui.container.Panel
        SearchModeSwitch                          matlab.ui.control.Switch
        IntermodulationsearchwindowsizeHzEditField  matlab.ui.control.NumericEditField
        IntermodulationsearchwindowsizeHzEditFieldLabel  matlab.ui.control.Label
        SecondtonesearchwindowsizeHzEditField  matlab.ui.control.NumericEditField
        SecondtonesearchwindowsizeHzEditFieldLabel  matlab.ui.control.Label
        FirsttonesearchwindowsizeHzEditField  matlab.ui.control.NumericEditField
        FirsttonesearchwindowsizeHzEditFieldLabel  matlab.ui.control.Label
        RunStopButton                   matlab.ui.control.Button
    end

    properties (Access = private)
        appInstance;
        carrierFreq;
        toneFreq;
        centerFreq;
        span;
        calibrated = 0;
        calPow; % Power gain calibration
        calTone1F;
        calTone1P;
        calTone2F;
        calTone2P;
        calIntF;
        calIntP;
        calPos;
        calibratorCalled=0;
        measTone1F;
        measTone1P;
        measTone2F;
        measTone2P;
        measIntF;
        measIntP;
        measPos;
        measCalled=0;
    end

    % getters and setters
    methods (Access = public)
        function setCarrierFreq(obj, freq)
            obj.carrierFreq = freq;
        end
        function setToneFreq(obj, freq)
            obj.toneFreq = freq;
        end
        function setCenterFreq(obj, freq)
            obj.centerFreq = freq;
        end
        function setSpan(obj, freq)
            obj.span = freq;
        end
    end

    methods (Access = public)
        function meter(obj, psd, f)
                        psd = psd + obj.InputattenuatordBEditField.Value;
            if isequal(obj.SearchModeSwitch.Value,'Search window') 
                firstWinSize = obj.FirsttonesearchwindowsizeHzEditField.Value;
                secondWinSize = obj.SecondtonesearchwindowsizeHzEditField.Value;
                intWinSize = obj.IntermodulationsearchwindowsizeHzEditField.Value;
                intToneCenter = 2*obj.toneFreq-obj.carrierFreq;
                range1 = [obj.carrierFreq-firstWinSize/2, obj.carrierFreq+firstWinSize/2];
                range2 = [obj.toneFreq-secondWinSize/2, obj.toneFreq+secondWinSize/2];
                rangeint = [intToneCenter-intWinSize/2, intToneCenter+intWinSize/2];
                plot(obj.UIAxes, f, psd);
                xline(obj.UIAxes, range1,'--', 'Color', '#D95319');
                xline(obj.UIAxes, range2,'--', 'Color', '#7E2F8E')
                xline(obj.UIAxes, rangeint,'--', 'Color', '#A2142F');
                r1min = find(f>=range1(1), 1, "first");
                r1max = find(f<=range1(2), 1, "last");
                r2min = find(f>=range2(1), 1, "first");
                r2max = find(f<=range2(2), 1, "last");
                rintmin = find(f>=rangeint(1), 1, "first");
                rintmax = find(f<=rangeint(2), 1, "last");
                [pks1, pksPos1] = findpeaks(psd(r1min:r1max), f(r1min:r1max), 'SortStr','descend');
                [pks2, pksPos2] = findpeaks(psd(r2min:r2max), f(r2min:r2max), 'SortStr','descend');
                [pksint, pksPosint] = findpeaks(psd(rintmin:rintmax), f(rintmin:rintmax), 'SortStr','descend');
                pks1 = pks1(1);
                pksPos1 = pksPos1(1);
                pks2 = pks2(1);
                pksPos2 = pksPos2(1);
                pksint = pksint(1);
                pksPosint = pksPosint(1);
                hold(obj.UIAxes, "on");
                plot(obj.UIAxes, pksPos1, pks1,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                plot(obj.UIAxes, pksPos2, pks2,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                plot(obj.UIAxes, pksPosint, pksint,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319" );
                text(obj.UIAxes, pksPos1, pks1+5,"Tone 1","HorizontalAlignment","center");
                text(obj.UIAxes, pksPos2, pks2+5,"Tone 2","HorizontalAlignment","center");
                text(obj.UIAxes, pksPosint, pksint+5,"Inter.","HorizontalAlignment","center");
                hold(obj.UIAxes, "off");
                obj.FirstFreq.Text = [num2str(pksPos1),'Hz'];
                obj.SecondFreq.Text = [num2str(pksPos2),'Hz'];
                obj.IntFreq.Text = [num2str(pksPosint),'Hz'];
                obj.FirstPow.Text = [num2str(round(pks1,2)),'dBm'];
                obj.SecondPow.Text = [num2str(round(pks2,2)),'dBm'];
                obj.IntPow.Text = [num2str(round(pksint,2)),'dBm'];
                obj.IP3Res.Text = [num2str(round((pks1+2*pks2-pksint)/2), 2),'dBm'];
                obj.measTone1F(obj.measPos)=pksPos1;
                obj.measTone1P(obj.measPos)=pks1;
                obj.measTone2F(obj.measPos)=pksPos2;
                obj.measTone2P(obj.measPos)=pks2;
                obj.measIntF(obj.measPos)=pksPosint;
                obj.measIntP(obj.measPos)=pksint;
            else
                plot(obj.UIAxes, f, psd);
                % [pks, pksPos] = findpeaks(Pxx_dB, f);
                % pksMatrix = [pks pksPos];
                % pksMatrix = sortrows(pksMatrix, 'descend');
                % plot(obj.UIAxes, f, Pxx_dB, pksMatrix(1:obj.MarkersSpinner.Value,2), pksMatrix(1:obj.MarkersSpinner.Value,1),"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                % text(obj.UIAxes, pksMatrix(1:obj.MarkersSpinner.Value,2),pksMatrix(1:obj.MarkersSpinner.Value,1),num2str((1:numel(pksMatrix(1:obj.MarkersSpinner.Value,2)))'),"Color","white","HorizontalAlignment","center");
            end
            obj.measCalled=1;
        end
        function calibrator(obj, psd, f)
            %psd = psd + obj.InputattenuatordBEditField.Value;
            if isequal(obj.SearchModeSwitch.Value,'Search window') 
                firstWinSize = obj.FirsttonesearchwindowsizeHzEditField.Value;
                secondWinSize = obj.SecondtonesearchwindowsizeHzEditField.Value;
                intWinSize = obj.IntermodulationsearchwindowsizeHzEditField.Value;
                intToneCenter = 2*obj.toneFreq-obj.carrierFreq;
                range1 = [obj.carrierFreq-firstWinSize/2, obj.carrierFreq+firstWinSize/2];
                range2 = [obj.toneFreq-secondWinSize/2, obj.toneFreq+secondWinSize/2];
                rangeint = [intToneCenter-intWinSize/2, intToneCenter+intWinSize/2];
                plot(obj.UIAxes, f, psd);
                xline(obj.UIAxes, range1,'--', 'Color', '#D95319');
                xline(obj.UIAxes, range2,'--', 'Color', '#7E2F8E')
                xline(obj.UIAxes, rangeint,'--', 'Color', '#A2142F');
                r1min = find(f>=range1(1), 1, "first");
                r1max = find(f<=range1(2), 1, "last");
                r2min = find(f>=range2(1), 1, "first");
                r2max = find(f<=range2(2), 1, "last");
                rintmin = find(f>=rangeint(1), 1, "first");
                rintmax = find(f<=rangeint(2), 1, "last");
                [pks1, pksPos1] = findpeaks(psd(r1min:r1max), f(r1min:r1max), 'SortStr','descend');
                [pks2, pksPos2] = findpeaks(psd(r2min:r2max), f(r2min:r2max), 'SortStr','descend');
                [pksint, pksPosint] = findpeaks(psd(rintmin:rintmax), f(rintmin:rintmax), 'SortStr','descend');
                pks1 = pks1(1);
                pksPos1 = pksPos1(1);
                pks2 = pks2(1);
                pksPos2 = pksPos2(1);
                pksint = pksint(1);
                pksPosint = pksPosint(1);
                hold(obj.UIAxes, "on");
                plot(obj.UIAxes, pksPos1, pks1,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                plot(obj.UIAxes, pksPos2, pks2,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                plot(obj.UIAxes, pksPosint, pksint,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319" );
                text(obj.UIAxes, pksPos1, pks1+5,"Tone 1","HorizontalAlignment","center");
                text(obj.UIAxes, pksPos2, pks2+5,"Tone 2","HorizontalAlignment","center");
                text(obj.UIAxes, pksPosint, pksint+5,"Inter.","HorizontalAlignment","center");
                hold(obj.UIAxes, "off");
                obj.FirstFreq.Text = [num2str(pksPos1),'Hz'];
                obj.SecondFreq.Text = [num2str(pksPos2),'Hz'];
                obj.IntFreq.Text = [num2str(pksPosint),'Hz'];
                obj.FirstPow.Text = [num2str(round(pks1,2)),'dBm'];
                obj.SecondPow.Text = [num2str(round(pks2,2)),'dBm'];
                obj.IntPow.Text = [num2str(round(pksint,2)),'dBm'];
                obj.IP3Res.Text = [num2str(round((pks1+2*pks2-pksint)/2), 2),'dBm'];
                obj.calTone1F(obj.calPos)=pksPos1;
                obj.calTone1P(obj.calPos)=pks1;
                obj.calTone2F(obj.calPos)=pksPos2;
                obj.calTone2P(obj.calPos)=pks2;
                obj.calIntF(obj.calPos)=pksPosint;
                obj.calIntP(obj.calPos)=pksint;
            else
                plot(obj.UIAxes, f, psd);
                % [pks, pksPos] = findpeaks(Pxx_dB, f);
                % pksMatrix = [pks pksPos];
                % pksMatrix = sortrows(pksMatrix, 'descend');
                % plot(obj.UIAxes, f, Pxx_dB, pksMatrix(1:obj.MarkersSpinner.Value,2), pksMatrix(1:obj.MarkersSpinner.Value,1),"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                % text(obj.UIAxes, pksMatrix(1:obj.MarkersSpinner.Value,2),pksMatrix(1:obj.MarkersSpinner.Value,1),num2str((1:numel(pksMatrix(1:obj.MarkersSpinner.Value,2)))'),"Color","white","HorizontalAlignment","center");
            end
            obj.calibratorCalled=1;
        end
        function dataProcessor(obj, psd, f)
            psd = psd + obj.InputattenuatordBEditField.Value;
            
            if isequal(obj.SearchModeSwitch.Value,'Search window') 
                firstWinSize = obj.FirsttonesearchwindowsizeHzEditField.Value;
                secondWinSize = obj.SecondtonesearchwindowsizeHzEditField.Value;
                intWinSize = obj.IntermodulationsearchwindowsizeHzEditField.Value;
                intToneCenter = 2*obj.toneFreq-obj.carrierFreq;
                range1 = [obj.carrierFreq-firstWinSize/2, obj.carrierFreq+firstWinSize/2];
                range2 = [obj.toneFreq-secondWinSize/2, obj.toneFreq+secondWinSize/2];
                rangeint = [intToneCenter-intWinSize/2, intToneCenter+intWinSize/2];
                plot(obj.UIAxes, f, psd);
                xline(obj.UIAxes, range1,'--', 'Color', '#D95319');
                xline(obj.UIAxes, range2,'--', 'Color', '#7E2F8E')
                xline(obj.UIAxes, rangeint,'--', 'Color', '#A2142F');
                r1min = find(f>=range1(1), 1, "first");
                r1max = find(f<=range1(2), 1, "last");
                r2min = find(f>=range2(1), 1, "first");
                r2max = find(f<=range2(2), 1, "last");
                rintmin = find(f>=rangeint(1), 1, "first");
                rintmax = find(f<=rangeint(2), 1, "last");
                [pks1, pksPos1] = findpeaks(psd(r1min:r1max), f(r1min:r1max), 'SortStr','descend');
                [pks2, pksPos2] = findpeaks(psd(r2min:r2max), f(r2min:r2max), 'SortStr','descend');
                [pksint, pksPosint] = findpeaks(psd(rintmin:rintmax), f(rintmin:rintmax), 'SortStr','descend');
                pks1 = pks1(1);
                pksPos1 = pksPos1(1);
                pks2 = pks2(1);
                pksPos2 = pksPos2(1);
                pksint = pksint(1);
                pksPosint = pksPosint(1);
                hold(obj.UIAxes, "on");
                plot(obj.UIAxes, pksPos1, pks1,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                plot(obj.UIAxes, pksPos2, pks2,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                plot(obj.UIAxes, pksPosint, pksint,"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319" );
                text(obj.UIAxes, pksPos1, pks1+5,"Tone 1","HorizontalAlignment","center");
                text(obj.UIAxes, pksPos2, pks2+5,"Tone 2","HorizontalAlignment","center");
                text(obj.UIAxes, pksPosint, pksint+5,"Inter.","HorizontalAlignment","center");
                hold(obj.UIAxes, "off");
                obj.FirstFreq.Text = [num2str(pksPos1),'Hz'];
                obj.SecondFreq.Text = [num2str(pksPos2),'Hz'];
                obj.IntFreq.Text = [num2str(pksPosint),'Hz'];
                obj.FirstPow.Text = [num2str(round(pks1,2)),'dBm'];
                obj.SecondPow.Text = [num2str(round(pks2,2)),'dBm'];
                obj.IntPow.Text = [num2str(round(pksint,2)),'dBm'];
                obj.IP3Res.Text = [num2str(round((pks1+2*pks2-pksint)/2), 2),'dBm'];
            else
                plot(obj.UIAxes, f, psd);
                % [pks, pksPos] = findpeaks(Pxx_dB, f);
                % pksMatrix = [pks pksPos];
                % pksMatrix = sortrows(pksMatrix, 'descend');
                % plot(obj.UIAxes, f, Pxx_dB, pksMatrix(1:obj.MarkersSpinner.Value,2), pksMatrix(1:obj.MarkersSpinner.Value,1),"v","MarkerSize", 10, "MarkerFaceColor", "#D95319", "MarkerEdgeColor","#D95319");
                % text(obj.UIAxes, pksMatrix(1:obj.MarkersSpinner.Value,2),pksMatrix(1:obj.MarkersSpinner.Value,1),num2str((1:numel(pksMatrix(1:obj.MarkersSpinner.Value,2)))'),"Color","white","HorizontalAlignment","center");
            end
        end
    end

    methods (Access = private)
        % Component callbacks
        function LoweststimuluspowerEditFieldChanged(obj, event)
            if(obj.LoweststimuluspowerEditField.Value>obj.HigheststimuluspowerEditField)
                obj.LoweststimuluspowerEditField.Value=event.PreviousValue;
            end
            InvalidateCalibration(obj);
        end
        function HigheststimuluspowerEditFieldChanged(obj, event)
            if(obj.HigheststimuluspowerEditField.Value>obj.LoweststimuluspowerEditField)
                obj.HigheststimuluspowerEditField.Value=event.PreviousValue;
            end
            InvalidateCalibration(obj);
        end
        function InvalidateCalibration(obj, event)
            obj.calibrated = 0;
            obj.CalibrateforthissettingsButton.BackgroundColor = [0.6353 0.0784 0.1843];
        end
        function calibratePressedCallback(obj, event)
            obj.CalibrateforthissettingsButton.BackgroundColor = [0.9290 0.6940 0.1250];
            obj.CalibrateforthissettingsButton.Enable = "off";
            obj.LoweststimuluspowerEditField.Enable = "off";
            obj.HigheststimuluspowerEditField.Enable = "off";
            obj.AveragingEditField.Enable = "off";
            obj.PowerstepsEditField.Enable = "off";
            obj.InputattenuatordBEditField.Enable = "off";
            obj.RunStopButton.Enable = "off";
            gainDelta=(obj.HigheststimuluspowerEditField.Value-obj.LoweststimuluspowerEditField.Value)/obj.PowerstepsEditField.Value;
            if(gainDelta == 0)
                obj.calPow = obj.LoweststimuluspowerEditField.Value;
            else
                obj.calPow  = obj.LoweststimuluspowerEditField.Value:gainDelta:obj.HigheststimuluspowerEditField.Value;
                obj.calPow = round(obj.calPow);
            end
            for pw = obj.calPow
                tx=obj.appInstance.getTxTabObj;
                rx=obj.appInstance.getRxTabObj;
                tx.setPowerGain(pw);
                rx.detachCallback;
                pause(2);
                rx.pause;
                callback = @(psd, f) obj.calibrator(psd, f);
                rx.attachCallback(callback);
                obj.calPos = find(obj.calPow==pw);
                rx.resume;
                while obj.calibratorCalled==0
                end
                rx.pause;
                obj.calibratorCalled=0;
                callback = @(psd, f) obj.dataProcessor(psd, f);
                rx.attachCallback(callback);
                rx.resume;
            end
            obj.calibrated =1;
            obj.CalibrateforthissettingsButton.BackgroundColor = [0.4660 0.6740 0.1880];
            obj.CalibrateforthissettingsButton.Enable = "on";
            obj.LoweststimuluspowerEditField.Enable = "on";
            obj.HigheststimuluspowerEditField.Enable = "on";
            obj.AveragingEditField.Enable = "on";
            obj.PowerstepsEditField.Enable = "on";
            obj.RunStopButton.Enable = "on";
            obj.InputattenuatordBEditField.Enable = "on";
        end
        function startMeasurementCallback(obj, event)
            obj.CalibrateforthissettingsButton.Enable = "off";
            obj.LoweststimuluspowerEditField.Enable = "off";
            obj.HigheststimuluspowerEditField.Enable = "off";
            obj.AveragingEditField.Enable = "off";
            obj.PowerstepsEditField.Enable = "off";
            obj.InputattenuatordBEditField.Enable = "off";
            obj.RunStopButton.Enable = "off";
            if (isempty(obj.calPow)|| obj.calibrated==0)
                gainDelta=(obj.HigheststimuluspowerEditField.Value-obj.LoweststimuluspowerEditField.Value)/obj.PowerstepsEditField.Value;
                if(gainDelta == 0)
                    obj.calPow = obj.LoweststimuluspowerEditField.Value;
                else
                    obj.calPow  = obj.LoweststimuluspowerEditField.Value:gainDelta:obj.HigheststimuluspowerEditField.Value;
                    obj.calPow = round(obj.calPow);
                end
            end
            for pw = obj.calPow
                tx=obj.appInstance.getTxTabObj;
                rx=obj.appInstance.getRxTabObj;
                tx.setPowerGain(pw);
                rx.detachCallback;
                pause(2);
                rx.pause;
                callback = @(psd, f) obj.meter(psd, f);
                rx.attachCallback(callback);
                obj.measPos = find(obj.calPow==pw);
                rx.resume;
                while obj.measCalled==0
                end
                rx.pause;
                obj.measCalled=0;
                callback = @(psd, f) obj.dataProcessor(psd, f);
                rx.attachCallback(callback);
                rx.resume;
            end
            if(obj.calibrated==1)
            gain=obj.measTone1P-obj.calTone1P;
            ip3 = round((obj.measTone1P+2*obj.measTone2P-(obj.measIntP-(obj.calIntP.*gain)))/2);
            else
            ip3 = round((obj.measTone1P+2*obj.measTone2P)/2);
            end
            tableData = [num2cell(obj.calPow(:)), ...
                num2cell(obj.measTone1P(:)), ...
                num2cell(obj.measTone2P(:)), ...
                num2cell(obj.measIntP(:)), ...
                num2cell(ip3(:))];

            % Assign the data to the table
            obj.UITable.Data = tableData;
            obj.CalibrateforthissettingsButton.Enable = "on";
            obj.LoweststimuluspowerEditField.Enable = "on";
            obj.HigheststimuluspowerEditField.Enable = "on";
            obj.AveragingEditField.Enable = "on";
            obj.PowerstepsEditField.Enable = "on";
            obj.InputattenuatordBEditField.Enable = "on";
            obj.RunStopButton.Enable = "on";
        end
    end
    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(obj)

            % Create PeakssearchparametersPanel
            obj.PeakssearchparametersPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.PeakssearchparametersPanel.Title = 'Peaks search parameters';
            obj.PeakssearchparametersPanel.Position = [2 538 383 178];

            % Create FirsttonesearchwindowsizeHzEditFieldLabel
            obj.FirsttonesearchwindowsizeHzEditFieldLabel = uilabel(obj.PeakssearchparametersPanel);
            obj.FirsttonesearchwindowsizeHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.FirsttonesearchwindowsizeHzEditFieldLabel.Position = [37 124 187 22];
            obj.FirsttonesearchwindowsizeHzEditFieldLabel.Text = 'First tone search window size [Hz]';

            % Create FirsttonesearchwindowsizeHzEditField
            obj.FirsttonesearchwindowsizeHzEditField = uieditfield(obj.PeakssearchparametersPanel, 'numeric');
            obj.FirsttonesearchwindowsizeHzEditField.Limits = [1 1000000];
            obj.FirsttonesearchwindowsizeHzEditField.Position = [239 124 100 22];
            obj.FirsttonesearchwindowsizeHzEditField.Value = 10e4;
            obj.FirsttonesearchwindowsizeHzEditField.BackgroundColor="#D95319";

            % Create SecondtonesearchwindowsizeHzEditFieldLabel
            obj.SecondtonesearchwindowsizeHzEditFieldLabel = uilabel(obj.PeakssearchparametersPanel);
            obj.SecondtonesearchwindowsizeHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.SecondtonesearchwindowsizeHzEditFieldLabel.Position = [21 90 205 22];
            obj.SecondtonesearchwindowsizeHzEditFieldLabel.Text = 'Second tone search window size [Hz]';

            % Create SecondtonesearchwindowsizeHzEditField
            obj.SecondtonesearchwindowsizeHzEditField = uieditfield(obj.PeakssearchparametersPanel, 'numeric');
            obj.SecondtonesearchwindowsizeHzEditField.Limits = [1 1000000];
            obj.SecondtonesearchwindowsizeHzEditField.Position = [240 90 100 22];
            obj.SecondtonesearchwindowsizeHzEditField.Value = 10e4;
            obj.SecondtonesearchwindowsizeHzEditField.BackgroundColor="#7E2F8E";

            % Create IntermodulationsearchwindowsizeHzEditFieldLabel
            obj.IntermodulationsearchwindowsizeHzEditFieldLabel = uilabel(obj.PeakssearchparametersPanel);
            obj.IntermodulationsearchwindowsizeHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.IntermodulationsearchwindowsizeHzEditFieldLabel.Position = [5 57 221 22];
            obj.IntermodulationsearchwindowsizeHzEditFieldLabel.Text = 'Intermodulation search window size [Hz]';

            % Create IntermodulationsearchwindowsizeHzEditField
            obj.IntermodulationsearchwindowsizeHzEditField = uieditfield(obj.PeakssearchparametersPanel, 'numeric');
            obj.IntermodulationsearchwindowsizeHzEditField.Limits = [1 1000000];
            obj.IntermodulationsearchwindowsizeHzEditField.Position = [240 57 100 22];
            obj.IntermodulationsearchwindowsizeHzEditField.Value = 10e4;
            obj.IntermodulationsearchwindowsizeHzEditField.BackgroundColor="#A2142F";

            % Create Switch
            obj.SearchModeSwitch = uiswitch(obj.PeakssearchparametersPanel, 'slider');
            obj.SearchModeSwitch.Items = {'Search window', 'Absolute max peaks'};
            obj.SearchModeSwitch.Position = [166 19 45 20];
            obj.SearchModeSwitch.Value = 'Search window';

            % Create SpectrumliveviewPanel
            obj.SpectrumliveviewPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.SpectrumliveviewPanel.Title = 'Spectrum live view';
            obj.SpectrumliveviewPanel.Position = [385 310 584 406];

            % Create UIAxes
            obj.UIAxes = uiaxes(obj.SpectrumliveviewPanel);
            xlabel(obj.UIAxes, 'Frequency [Hz]')
            ylabel(obj.UIAxes, 'Power [dBm]')
            ylim(obj.UIAxes, [-140, 10]);    % Fixed power range
            obj.UIAxes.Position = [17 16 551 358];

            % Create ResultsPanel
            obj.ResultsPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.ResultsPanel.Title = 'Live results';
            obj.ResultsPanel.Position = [2 310 383 229];

            % Create FirsttonefrequencyLabel
            obj.FirsttonefrequencyLabel = uilabel(obj.ResultsPanel);
            obj.FirsttonefrequencyLabel.Position = [98 163 114 22];
            obj.FirsttonefrequencyLabel.Text = 'First tone frequency:';

            % Create SecondtonefrequencyLabel
            obj.SecondtonefrequencyLabel = uilabel(obj.ResultsPanel);
            obj.SecondtonefrequencyLabel.Position = [80 142 132 22];
            obj.SecondtonefrequencyLabel.Text = 'Second tone frequency:';

            % Create IntermodulationproductfrequencyLabel
            obj.IntermodulationproductfrequencyLabel = uilabel(obj.ResultsPanel);
            obj.IntermodulationproductfrequencyLabel.Position = [21 121 191 22];
            obj.IntermodulationproductfrequencyLabel.Text = 'Intermodulation product frequency:';

            % Create FirsttonepowerLabel
            obj.FirsttonepowerLabel = uilabel(obj.ResultsPanel);
            obj.FirsttonepowerLabel.Position = [117 100 94 22];
            obj.FirsttonepowerLabel.Text = 'First tone power:';

            % Create SecondtonepowerLabel
            obj.SecondtonepowerLabel = uilabel(obj.ResultsPanel);
            obj.SecondtonepowerLabel.Position = [99 79 112 22];
            obj.SecondtonepowerLabel.Text = 'Second tone power:';

            % Create IntermodulationproductpowerLabel
            obj.IntermodulationproductpowerLabel = uilabel(obj.ResultsPanel);
            obj.IntermodulationproductpowerLabel.Position = [40 58 170 22];
            obj.IntermodulationproductpowerLabel.Text = 'Intermodulation product power:';

            % Create CalculatedIP3Label
            obj.CalculatedIP3Label = uilabel(obj.ResultsPanel);
            obj.CalculatedIP3Label.FontWeight = 'bold';
            obj.CalculatedIP3Label.Position = [119 36 91 22];
            obj.CalculatedIP3Label.Text = 'Calculated IP3:';

            % Create Label
            obj.FirstFreq = uilabel(obj.ResultsPanel);
            obj.FirstFreq.Position = [230 163 80 22];
            obj.FirstFreq.Text = '-';

            % Create Label2
            obj.SecondFreq = uilabel(obj.ResultsPanel);
            obj.SecondFreq.Position = [230 142 80 22];
            obj.SecondFreq.Text = '-';

            % Create Label3
            obj.IntFreq = uilabel(obj.ResultsPanel);
            obj.IntFreq.Position = [230 121 80 22];
            obj.IntFreq.Text = '-';

            % Create Label4
            obj.FirstPow = uilabel(obj.ResultsPanel);
            obj.FirstPow.Position = [229 100 80 22];
            obj.FirstPow.Text = '-';

            % Create Label5
            obj.SecondPow = uilabel(obj.ResultsPanel);
            obj.SecondPow.Position = [229 79 80 22];
            obj.SecondPow.Text = '-';

            % Create Label6
            obj.IntPow = uilabel(obj.ResultsPanel);
            obj.IntPow.Position = [229 57 80 22];
            obj.IntPow.Text = '-';

            % Create Label7
            obj.IP3Res = uilabel(obj.ResultsPanel);
            obj.IP3Res.FontWeight = 'bold';
            obj.IP3Res.Position = [229 36 80 22];
            obj.IP3Res.Text = '-';

            % Create OthersettingsPanel
            obj.OthersettingsPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.OthersettingsPanel.Title = 'Other settings';
            obj.OthersettingsPanel.Position = [0 1 476 310];

            % Create InputattenuatordBEditFieldLabel
            obj.InputattenuatordBEditFieldLabel = uilabel(obj.OthersettingsPanel);
            obj.InputattenuatordBEditFieldLabel.HorizontalAlignment = 'right';
            obj.InputattenuatordBEditFieldLabel.Position = [144 239 114 22];
            obj.InputattenuatordBEditFieldLabel.Text = 'Input attenuator [dB]';

            % Create InputattenuatordBEditField
            obj.InputattenuatordBEditField = uieditfield(obj.OthersettingsPanel, 'numeric');
            obj.InputattenuatordBEditField.Limits = [0 1000];
            obj.InputattenuatordBEditField.Position = [273 239 100 22];
            obj.InputattenuatordBEditField.Value = 0;
            obj.InputattenuatordBEditField.ValueChangedFcn = createCallbackFcn(obj, @InvalidateCalibration, true);

            % Create AveragingEditFieldLabel
            obj.AveragingEditFieldLabel = uilabel(obj.OthersettingsPanel);
            obj.AveragingEditFieldLabel.HorizontalAlignment = 'right';
            obj.AveragingEditFieldLabel.Position = [199 207 59 22];
            obj.AveragingEditFieldLabel.Text = 'Averaging';

            % Create AveragingEditField
            obj.AveragingEditField = uieditfield(obj.OthersettingsPanel, 'numeric');
            obj.AveragingEditField.Limits = [1 20];
            obj.AveragingEditField.Position = [273 207 100 22];
            obj.AveragingEditField.Value = 1;
            obj.AveragingEditField.ValueChangedFcn = createCallbackFcn(obj, @InvalidateCalibration, true);

            % Create SaveresultstomatfileButton
            obj.SaveresultstomatfileButton = uibutton(obj.OthersettingsPanel, 'push');
            obj.SaveresultstomatfileButton.Position = [229 65 147 23];
            obj.SaveresultstomatfileButton.Text = 'Save results to .mat file';

            % Create LoweststimuluspowerEditFieldLabel
            obj.LoweststimuluspowerEditFieldLabel = uilabel(obj.OthersettingsPanel);
            obj.LoweststimuluspowerEditFieldLabel.HorizontalAlignment = 'right';
            obj.LoweststimuluspowerEditFieldLabel.Position = [82 176 177 22];
            obj.LoweststimuluspowerEditFieldLabel.Text = 'Lowest stimulus power gain [dB]';

            % Create LoweststimuluspowerEditField
            obj.LoweststimuluspowerEditField = uieditfield(obj.OthersettingsPanel, 'numeric');
            obj.LoweststimuluspowerEditField.Position = [274 176 100 22];
            obj.LoweststimuluspowerEditField.Limits = [0 47];
            obj.LoweststimuluspowerEditField.ValueChangedFcn = createCallbackFcn(obj, @LoweststimuluspowerEditFieldChanged, true);

            % Create HigheststimuluspowerEditFieldLabel
            obj.HigheststimuluspowerEditFieldLabel = uilabel(obj.OthersettingsPanel);
            obj.HigheststimuluspowerEditFieldLabel.HorizontalAlignment = 'right';
            obj.HigheststimuluspowerEditFieldLabel.Position = [79 141 180 22];
            obj.HigheststimuluspowerEditFieldLabel.Text = 'Highest stimulus power gain [dB]';

            % Create HigheststimuluspowerEditField
            obj.HigheststimuluspowerEditField = uieditfield(obj.OthersettingsPanel, 'numeric');
            obj.HigheststimuluspowerEditField.Position = [274 141 100 22];
            obj.HigheststimuluspowerEditField.Limits = [0 47];
            obj.HigheststimuluspowerEditField.ValueChangedFcn = createCallbackFcn(obj, @HigheststimuluspowerEditFieldChanged, true);

            % Create PowerstepsEditFieldLabel
            obj.PowerstepsEditFieldLabel = uilabel(obj.OthersettingsPanel);
            obj.PowerstepsEditFieldLabel.HorizontalAlignment = 'right';
            obj.PowerstepsEditFieldLabel.Position = [162 106 97 22];
            obj.PowerstepsEditFieldLabel.Text = 'Power gain steps';

            % Create PowerstepsEditField
            obj.PowerstepsEditField = uieditfield(obj.OthersettingsPanel, 'numeric');
            obj.PowerstepsEditField.Position = [274 106 100 22];
            obj.PowerstepsEditField.Value = 1;
            obj.PowerstepsEditField.Limits = [1 10];
            obj.PowerstepsEditField.ValueChangedFcn = createCallbackFcn(obj, @InvalidateCalibration, true);

            % Create CalibrateforthissettingsButton
            obj.CalibrateforthissettingsButton = uibutton(obj.OthersettingsPanel, 'push');
            obj.CalibrateforthissettingsButton.BackgroundColor = [0.6353 0.0784 0.1843];
            obj.CalibrateforthissettingsButton.FontColor = [0.902 0.902 0.902];
            obj.CalibrateforthissettingsButton.Position = [229 31 147 22];
            obj.CalibrateforthissettingsButton.Text = 'Calibrate for this settings';
            obj.CalibrateforthissettingsButton.ButtonPushedFcn = createCallbackFcn(obj, @calibratePressedCallback, true);

            % Create PowersweepresultsPanel
            obj.PowersweepresultsPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.PowersweepresultsPanel.Title = 'Power sweep results';
            obj.PowersweepresultsPanel.Position = [475 1 494 310];

            % Create RunStopButton
            obj.RunStopButton = uibutton(obj.OthersettingsPanel, 'push');
            obj.RunStopButton.Position = [95 31 100 57];
            obj.RunStopButton.Text = 'Start measure';
            obj.RunStopButton.ButtonPushedFcn = createCallbackFcn(obj, @startMeasurementCallback, true);

            % Create UITable
            obj.UITable = uitable(obj.PowersweepresultsPanel);
            obj.UITable.ColumnName = {'Stimulus gain'; 'Tone1 pow'; 'Tone2 pow'; 'Intermod pow'; 'IP3'};
            obj.UITable.RowName = {};
            obj.UITable.Position = [0 0 494 287];

        end
    end

    % Object creation and deletion
    methods (Access = public)

        % Constructor
        function obj = TwoTonesTestObj(app)
            obj.appInstance=app;
            % Create UIFigure and components
            createComponents(obj);
        end

        function deleteUI(obj)
            delete(obj.PowersweepresultsPanel);
            delete(obj.UITable);
            delete(obj.ResultsPanel);
            delete(obj.OthersettingsPanel);
            delete(obj.CalibrateforthissettingsButton);
            delete(obj.PowerstepsEditField);
            delete(obj.PowerstepsEditFieldLabel);
            delete(obj.HigheststimuluspowerEditField);
            delete(obj.HigheststimuluspowerEditFieldLabel);
            delete(obj.LoweststimuluspowerEditField);
            delete(obj.LoweststimuluspowerEditFieldLabel);
            delete(obj.SaveresultstomatfileButton);
            delete(obj.AveragingEditField);
            delete(obj.AveragingEditFieldLabel);
            delete(obj.InputattenuatordBEditField);
            delete(obj.InputattenuatordBEditFieldLabel);
            delete(obj.IP3Res);
            delete(obj.IntPow);
            delete(obj.SecondPow);
            delete(obj.FirstPow);
            delete(obj.IntFreq);
            delete(obj.SecondFreq);
            delete(obj.FirstFreq);
            delete(obj.CalculatedIP3Label);
            delete(obj.IntermodulationproductpowerLabel);
            delete(obj.SecondtonepowerLabel);
            delete(obj.FirsttonepowerLabel);
            delete(obj.IntermodulationproductfrequencyLabel);
            delete(obj.SecondtonefrequencyLabel);
            delete(obj.FirsttonefrequencyLabel);
            delete(obj.SpectrumliveviewPanel);
            delete(obj.UIAxes);
            delete(obj.PeakssearchparametersPanel);
            delete(obj.SearchModeSwitch);
            delete(obj.IntermodulationsearchwindowsizeHzEditField);
            delete(obj.IntermodulationsearchwindowsizeHzEditFieldLabel);
            delete(obj.SecondtonesearchwindowsizeHzEditField);
            delete(obj.SecondtonesearchwindowsizeHzEditFieldLabel);
            delete(obj.FirsttonesearchwindowsizeHzEditField);
            delete(obj.FirsttonesearchwindowsizeHzEditFieldLabel);
        end

        function delete(obj)
            deleteUI(obj);
        end
    end
end