classdef QAMtest < matlab.apps.AppBase

    % Properties that correspond to obj components
    properties (Access = public)
        MetricsPanel               matlab.ui.container.Panel
        BERLabel                   matlab.ui.control.Label
        EVMLabel                   matlab.ui.control.Label
        BERresultsLabel            matlab.ui.control.Label
        EVMresultsLabel            matlab.ui.control.Label
        DecodingpathPanel          matlab.ui.container.Panel
        BitratebitsEditField       matlab.ui.control.NumericEditField
        BitratebitsEditFieldLabel  matlab.ui.control.Label
        BitspersymbolSpinner       matlab.ui.control.Spinner
        BitspersymbolSpinnerLabel  matlab.ui.control.Label
        Image5                     matlab.ui.control.Image
        Image2_4                   matlab.ui.control.Image
        Image2_3                   matlab.ui.control.Image
        Image2_2                   matlab.ui.control.Image
        Image2                     matlab.ui.control.Image
        DropDown4                  matlab.ui.control.DropDown
        DropDown3                  matlab.ui.control.DropDown
        DropDown2                  matlab.ui.control.DropDown
        DropDown                   matlab.ui.control.DropDown
        dBLabel                    matlab.ui.control.Label
        MHzLabel_2                 matlab.ui.control.Label
        MHzLabel                   matlab.ui.control.Label
        Image                      matlab.ui.control.Image
        ConstellationPanel         matlab.ui.container.Panel
        UIAxes                     matlab.ui.control.UIAxes
        EyediagramsPanel           matlab.ui.container.Panel
        UIAxesEyeQ                 matlab.ui.control.UIAxes
        UIAxesEyeI                 matlab.ui.control.UIAxes
        Panel_4                    matlab.ui.container.Panel
        Panel_3                    matlab.ui.container.Panel
        Panel_2                    matlab.ui.container.Panel
        Panel                      matlab.ui.container.Panel
    end

    properties (Access = private)
        appInstance
        processor1;
        processor2;
        processor3;
        processor4;
        refConst;
        % Parameters
        Fs = 2.4e6; % RTL samplerate
        Rs = 100e3; % QAM symbolrate (from tx)
        sps;
        span = 10;                 % Filter span in symbols
        numTraces = 20;
        oversampleFactor=4;
        agc;
    end

    methods (Access = public)
        function dataProcessor(obj, samples)
            %agcout=obj.agc(samples);
            out1 = obj.processor1.processor(samples);
            out2 = obj.processor2.processor(out1);
            out3 = obj.processor3.processor(out2);
            out4 = obj.processor4.processor(out3);

            % Normalize power to unit average
            

            % Demodulate and remodulate for EVM
            demod = qamdemod(out4, 16, "gray");
            remod = qammod(demod, 16, 'gray', 'UnitAveragePower', true);
            out4 = out4 / sqrt(mean(abs(out4).^2));
            
            % Compute EVM
            evmVec = out4 - remod;
            evmRMS = sqrt(mean(abs(evmVec).^2));
            evmPercent = 100 * evmRMS;
            obj.EVMresultsLabel.Text = [num2str(round(evmPercent,2)),'%'];

                        % Extract I and Q
            I = real(out4);
            Q = imag(out4);

            out4 = out4.*4;
            % --- Plotting ---
            %cla(obj.UIAxes);
            scatter(obj.UIAxes, real(out4), imag(out4), 10, 'b', 'filled'); hold(obj.UIAxes, 'on');
            scatter(obj.UIAxes, real(obj.refConst), imag(obj.refConst), 80, 'ro', 'LineWidth', 1.5);
            hold(obj.UIAxes, 'off');

            % Trim to full trace windows
            numSamples = floor(length(I)/obj.sps) * obj.sps;
            I = I(1:numSamples);
            Q = Q(1:numSamples);

            % Reshape into traces
            eyeMatrixI = reshape(I, obj.sps, []);
            eyeMatrixQ = reshape(Q, obj.sps, []);

            % Limit number of traces to plot
            eyeMatrixI = eyeMatrixI(:, 1:min(obj.numTraces, size(eyeMatrixI,2)));
            eyeMatrixQ = eyeMatrixQ(:, 1:min(obj.numTraces, size(eyeMatrixQ,2)));
            % Time vectors
            t_old = 0:obj.sps-1;
            t_new = linspace(0, obj.sps-1, obj.sps * obj.oversampleFactor);

            % --- I Eye ---
            cla(obj.UIAxesEyeI);
            hold(obj.UIAxesEyeI, 'on');
            for k = 1:size(eyeMatrixI, 2)
                y_interp = sinc_interp_vector(obj, eyeMatrixI(:, k), t_old, t_new);
                plot(obj.UIAxesEyeI, t_new / obj.sps, y_interp, 'b');
            end
            hold(obj.UIAxesEyeI, 'off');
   
            % --- Q Eye ---
            cla(obj.UIAxesEyeQ);
            hold(obj.UIAxesEyeQ, 'on');
            for k = 1:size(eyeMatrixQ, 2)
                y_interp = sinc_interp_vector(obj, eyeMatrixQ(:, k), t_old, t_new);
                plot(obj.UIAxesEyeQ, t_new / obj.sps, y_interp, 'r');
            end
            hold(obj.UIAxesEyeQ, 'off');
        end
    end
    % Component initialization
    methods (Access = private)
        function y_interp = sinc_interp_vector(obj, y, t_old, t_new)
            % y: vector of original samples (column)
            % t_old: original time indices (row)
            % t_new: new time indices (row)
            y_interp = zeros(size(t_new));
            for i = 1:length(t_new)
                sinc_weights = sinc(t_new(i) - t_old);
                y_interp(i) = sum(y(:).' .* sinc_weights);
            end
        end

        % Callbacks
        function processor1Changed(obj, event)
            obj.processor1.delete;
            obj.processor1=FilterObj(obj.DropDown.Value, obj.Panel);
        end

        function processor2Changed(obj, event)
            obj.processor2.delete;
            obj.processor2=FilterObj(obj.DropDown2.Value, obj.Panel_2);
        end

        function processor3Changed(obj, event)
            obj.processor3.delete;
            obj.processor3=FilterObj(obj.DropDown3.Value, obj.Panel_3);
        end

        function processor4Changed(obj, event)
            obj.processor4.delete;
            obj.processor4=FilterObj(obj.DropDown4.Value, obj.Panel_4);
        end
        % Create UIFigure and components
        function createComponents(obj)
            pathToMLobj = fileparts(mfilename('fullpath'));

            % Create EyediagramsPanel
            obj.EyediagramsPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.EyediagramsPanel.Title = 'Eye diagrams';
            obj.EyediagramsPanel.Position = [1 386 617 330];

            % Create UIAxesEyeI
            obj.UIAxesEyeI = uiaxes(obj.EyediagramsPanel);
            title(obj.UIAxesEyeI, 'I diagram')
            xlabel(obj.UIAxesEyeI, 'S')
            ylabel(obj.UIAxesEyeI, 'dB')
            obj.UIAxesEyeI.Position = [0 1 616 169];

            % Create UIAxesEyeQ
            obj.UIAxesEyeQ = uiaxes(obj.EyediagramsPanel);
            title(obj.UIAxesEyeQ, 'Q diagram')
            xlabel(obj.UIAxesEyeQ, 'S')
            ylabel(obj.UIAxesEyeQ, 'dB')
            obj.UIAxesEyeQ.Position = [1 169 616 139];

            % Create ConstellationPanel
            obj.ConstellationPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.ConstellationPanel.Title = 'Constellation';
            obj.ConstellationPanel.Position = [617 386 353 330];

            % Create UIAxes
            obj.UIAxes = uiaxes(obj.ConstellationPanel);
            xlabel(obj.UIAxes, 'In-Phase')
            ylabel(obj.UIAxes, 'Quadrature')
            obj.UIAxes.XGrid = 'on';
            obj.UIAxes.YGrid = 'on';
            obj.UIAxes.Position = [0 1 353 307];
            axis(obj.UIAxes, 'square');
            xlim(obj.UIAxes, [-5 5]);
            ylim(obj.UIAxes, [-5 5]);
            xticks(obj.UIAxes, -5:1:5);
            yticks(obj.UIAxes, -5:1:5);
            

            % Create DecodingpathPanel
            obj.DecodingpathPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.DecodingpathPanel.Title = 'Decoding path';
            obj.DecodingpathPanel.Position = [1 1 969 293];

            % Create Image
            obj.Image = uiimage(obj.DecodingpathPanel);
            obj.Image.Position = [1 127 422 144];
            obj.Image.ImageSource = fullfile(pathToMLobj, 'assets', 'inputgraph.svg');

            % Create MHzLabel
            obj.MHzLabel = uilabel(obj.DecodingpathPanel);
            obj.MHzLabel.HorizontalAlignment = 'center';
            obj.MHzLabel.Position = [227 184 46 22];
            obj.MHzLabel.Text = '2.4MHz';

            % Create MHzLabel_2
            obj.MHzLabel_2 = uilabel(obj.DecodingpathPanel);
            obj.MHzLabel_2.HorizontalAlignment = 'center';
            obj.MHzLabel_2.Position = [144 122 50 22];
            obj.MHzLabel_2.Text = '100MHz';

            % Create dBLabel
            obj.dBLabel = uilabel(obj.DecodingpathPanel);
            obj.dBLabel.HorizontalAlignment = 'center';
            obj.dBLabel.Position = [73 183 34 22];
            obj.dBLabel.Text = '0dB';

            % Create DropDown
            obj.DropDown = uidropdown(obj.DecodingpathPanel);
            obj.DropDown.Items = {'None', 'DC block', 'Low pass', 'Shaping filter', 'Coarse Carrier Est.', 'Fine Carrier Est.', 'Retimer'};
            obj.DropDown.Position = [449 222 100 22];
            obj.DropDown.Value = 'Shaping filter';
            obj.DropDown.ValueChangedFcn = createCallbackFcn(obj, @processor1Changed, true);

            % Create DropDown2
            obj.DropDown2 = uidropdown(obj.DecodingpathPanel);
            obj.DropDown2.Items = {'None', 'DC block', 'Low pass', 'Shaping filter', 'Coarse Carrier Est.', 'Fine Carrier Est.', 'Retimer'};
            obj.DropDown2.Position = [582 223 100 22];
            obj.DropDown2.Value = 'Coarse Carrier Est.';
            obj.DropDown2.ValueChangedFcn = createCallbackFcn(obj, @processor2Changed, true);

            % Create DropDown3
            obj.DropDown3 = uidropdown(obj.DecodingpathPanel);
            obj.DropDown3.Items = {'None', 'DC block', 'Low pass', 'Shaping filter', 'Coarse Carrier Est.', 'Fine Carrier Est.', 'Retimer'};
            obj.DropDown3.Position = [715 223 100 22];
            obj.DropDown3.Value = 'Retimer';
            obj.DropDown3.ValueChangedFcn = createCallbackFcn(obj, @processor3Changed, true);

            % Create DropDown4
            obj.DropDown4 = uidropdown(obj.DecodingpathPanel);
            obj.DropDown4.Items = {'None', 'DC block', 'Low pass', 'Shaping filter', 'Coarse Carrier Est.', 'Fine Carrier Est.', 'Retimer'};
            obj.DropDown4.Position = [846 223 100 22];
            obj.DropDown4.Value = 'Fine Carrier Est.';
            obj.DropDown4.ValueChangedFcn = createCallbackFcn(obj, @processor4Changed, true);

            % Create Image2
            obj.Image2 = uiimage(obj.DecodingpathPanel);
            obj.Image2.Position = [415 223 38 22];
            obj.Image2.ImageSource = fullfile(pathToMLobj, 'assets', 'arrow.svg');

            % Create Image2_2
            obj.Image2_2 = uiimage(obj.DecodingpathPanel);
            obj.Image2_2.Position = [549 223 38 22];
            obj.Image2_2.ImageSource = fullfile(pathToMLobj, 'assets', 'arrow.svg');

            % Create Image2_3
            obj.Image2_3 = uiimage(obj.DecodingpathPanel);
            obj.Image2_3.Position = [682 223 38 22];
            obj.Image2_3.ImageSource = fullfile(pathToMLobj, 'assets', 'arrow.svg');

            % Create Image2_4
            obj.Image2_4 = uiimage(obj.DecodingpathPanel);
            obj.Image2_4.Position = [814 223 38 22];
            obj.Image2_4.ImageSource = fullfile(pathToMLobj, 'assets', 'arrow.svg');

            % Create Image5
            obj.Image5 = uiimage(obj.DecodingpathPanel);
            obj.Image5.Position = [884 245 23 31];
            obj.Image5.ImageSource = fullfile(pathToMLobj, 'assets', 'arrowL.svg');

            % % Create BitspersymbolSpinnerLabel
            % obj.BitspersymbolSpinnerLabel = uilabel(obj.DecodingpathPanel);
            % obj.BitspersymbolSpinnerLabel.HorizontalAlignment = 'right';
            % obj.BitspersymbolSpinnerLabel.Position = [45 76 87 22];
            % obj.BitspersymbolSpinnerLabel.Text = 'Bits per symbol';
            % 
            % % Create BitspersymbolSpinner
            % obj.BitspersymbolSpinner = uispinner(obj.DecodingpathPanel);
            % obj.BitspersymbolSpinner.Limits = [1 100];
            % obj.BitspersymbolSpinner.Position = [176 76 56 22];
            % obj.BitspersymbolSpinner.Value = 40;
            % 
            % % Create BitratebitsEditFieldLabel
            % obj.BitratebitsEditFieldLabel = uilabel(obj.DecodingpathPanel);
            % obj.BitratebitsEditFieldLabel.HorizontalAlignment = 'right';
            % obj.BitratebitsEditFieldLabel.Position = [45 46 72 22];
            % obj.BitratebitsEditFieldLabel.Text = 'Bitrate [bit/s]';
            % 
            % % Create BitratebitsEditField
            % obj.BitratebitsEditField = uieditfield(obj.DecodingpathPanel, 'numeric');
            % obj.BitratebitsEditField.Position = [132 46 100 22];
            % obj.BitratebitsEditField.Value = 100000;

            % Create MetricsPanel
            obj.MetricsPanel = uipanel(obj.appInstance.MeasurementsTab);
            obj.MetricsPanel.Title = 'Metrics';
            obj.MetricsPanel.Position = [1 293 969 94];

            % Create EVMLabel
            obj.EVMLabel = uilabel(obj.MetricsPanel);
            obj.EVMLabel.Position = [45 43 34 22];
            obj.EVMLabel.Text = 'EVM:';

            % Create BERLabel
            obj.BERLabel = uilabel(obj.MetricsPanel);
            obj.BERLabel.Position = [45 12 33 22];
            obj.BERLabel.Text = 'BER:';
            % Create Panel
            obj.Panel = uipanel(obj.DecodingpathPanel);
            obj.Panel.Position = [436 19 129 187];

            % Create EVMresultsLabel
            obj.EVMresultsLabel = uilabel(obj.MetricsPanel);
            obj.EVMresultsLabel.Position = [84 43 66 22];
            obj.EVMresultsLabel.Text = '-';

            % Create BERresultsLabel
            obj.BERresultsLabel = uilabel(obj.MetricsPanel);
            obj.BERresultsLabel.Position = [85 12 65 22];
            obj.BERresultsLabel.Text = '-';

            % Create Panel_2
            obj.Panel_2 = uipanel(obj.DecodingpathPanel);
            obj.Panel_2.Position = [566 19 129 187];

            % Create Panel_3
            obj.Panel_3 = uipanel(obj.DecodingpathPanel);
            obj.Panel_3.Position = [696 19 129 187];

            % Create Panel_4
            obj.Panel_4 = uipanel(obj.DecodingpathPanel);
            obj.Panel_4.Position = [826 19 129 187];
        end
    end

    % obj creation and deletion
    methods (Access = public)

        % Construct obj
        function obj = QAMtest(appInstance)
            obj.appInstance=appInstance;
            % Create UIFigure and components
            createComponents(obj);
            obj.processor1 = FilterObj(obj.DropDown.Value, obj.Panel);
            obj.processor2 = FilterObj(obj.DropDown2.Value, obj.Panel_2);
            obj.processor3 = FilterObj(obj.DropDown3.Value, obj.Panel_3);
            obj.processor4 = FilterObj(obj.DropDown4.Value, obj.Panel_4);
            obj.refConst = qammod(0:15, 16, 'gray', 'UnitAveragePower', true)*4;  
            obj.sps = obj.Fs / obj.Rs;             % Must be integer
            obj.agc=comm.AGC("DesiredOutputPower",2,"AveragingLength",50,"MaximumGain",20);
        end

        function deleteUI(obj)
        end
        % Code that executes before obj deletion
        function delete(obj)

        end
    end
end
