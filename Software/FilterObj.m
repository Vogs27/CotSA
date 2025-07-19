classdef FilterObj < matlab.apps.AppBase
    properties (Access = public)
        StopbandHzEditField        matlab.ui.control.NumericEditField
        StopbandHzEditFieldLabel   matlab.ui.control.Label
        PassbandHzEditField        matlab.ui.control.NumericEditField
        PassbandHzEditFieldLabel   matlab.ui.control.Label
        RolloffEditField           matlab.ui.control.NumericEditField
        RolloffEditFieldLabel      matlab.ui.control.Label
        RisedcosineCheckBox        matlab.ui.control.CheckBox
    end

    properties (Access = private)
        tool;
        panel;
        objtype = 0;
        sampleRate;
        symbolrate;
    end
    
    methods (Access=public)
        function delete(obj)
            obj.deleteUI;
        end
        function obj = FilterObj(type, panel, varargin)
            obj.panel=panel;
            p = inputParser;
            switch type
                case 'DC block'
                   obj.objtype = 1;
                   obj.tool = dsp.DCBlocker();
                case 'Low pass'
                    obj.objtype = 2;
                    obj.drawLP;
                    addParameter(p,'sampleRate',2.4e6);
                    parse(p, varargin{:});
                    obj.sampleRate=p.Results.sampleRate;
                    obj.tool=dsp.LowpassFilter('SampleRate',p.Results.sampleRate, 'PassbandFrequency',obj.PassbandHzEditField.Value, ...
                           'StopbandFrequency', obj.StopbandHzEditField.Value);
                case 'Shaping filter'
                    obj.objtype = 3;
                    obj.drawCmdRised;
                    addParameter(p, 'sampleRate', 2.4e6);
                    addParameter(p, 'symbolRate', 100000);
                    parse(p, varargin{:});
                    obj.sampleRate = p.Results.sampleRate;
                    obj.symbolrate = p.Results.symbolRate;
                    sps=p.Results.sampleRate/p.Results.symbolRate;
                    if (obj.RisedcosineCheckBox.Value == 1)
                        obj.tool = comm.RaisedCosineReceiveFilter("Shape","Square root","RolloffFactor",obj.RolloffEditField.Value,"InputSamplesPerSymbol", sps, "FilterSpanInSymbols",10);%,"DecimationFactor",24);
                    else
                        obj.tool = comm.RaisedCosineReceiveFilter("Shape","Normal","RolloffFactor",obj.RolloffEditField.Value,"InputSamplesPerSymbol", sps, "FilterSpanInSymbols",10);%,"DecimationFactor",24);
                    end
    
                case 'Coarse Carrier Est.'
                    obj.objtype = 4;
                    addParameter(p, 'Modulation', 'QAM');
                    addParameter(p, 'sampleRate', 2.4e6);
                    addParameter(p, 'symbolRate', 100000);
                    parse(p, varargin{:});
                    obj.sampleRate = p.Results.sampleRate;
                    obj.symbolrate = p.Results.symbolRate;
                    sps=p.Results.sampleRate/p.Results.symbolRate;
                    obj.tool = comm.CoarseFrequencyCompensator("Modulation", p.Results.Modulation, "SampleRate", p.Results.sampleRate, FrequencyResolution=10);%"SamplesPerSymbol", sps);

                case 'Fine Carrier Est.'
                    obj.objtype = 5;
                    addParameter(p, 'Modulation', 'QAM');
                    addParameter(p, 'sampleRate', 2.4e6);
                    addParameter(p, 'symbolRate', 100000);
                    parse(p, varargin{:});
                    obj.sampleRate = p.Results.sampleRate;
                    obj.symbolrate = p.Results.symbolRate;
                    sps=p.Results.sampleRate/p.Results.symbolRate;
                    %obj.tool = comm.CarrierSynchronizer("Modulation", p.Results.Modulation, "SamplesPerSymbol", sps);
                    obj.tool = comm.CarrierSynchronizer( ...
                        DampingFactor=1, ...
                        NormalizedLoopBandwidth=0.01, ...
                        SamplesPerSymbol=sps, ...
                        Modulation='QAM');
                case 'Retimer'
                    obj.objtype = 6;
                    addParameter(p, 'Modulation', 'PAM/PSK/QAM');
                    addParameter(p, 'sampleRate', 2.4e6);
                    addParameter(p, 'symbolRate', 100000);
                    parse(p, varargin{:});
                    obj.sampleRate = p.Results.sampleRate;
                    obj.symbolrate = p.Results.symbolRate;
                    sps=p.Results.sampleRate/p.Results.symbolRate;
                    obj.tool = comm.SymbolSynchronizer("Modulation",p.Results.Modulation, "TimingErrorDetector","Gardner (non-data-aided)" ,"SamplesPerSymbol", sps, 'DampingFactor', 1,'DetectorGain',5.4,'NormalizedLoopBandwidth',0.01);
                    %{'None', 'DC block', 'Low pass', 'Shaping filter', 'Coarse Carrier Est.', 'Fine Carrier Est.', 'Retimer'};
            end
        end
        
        function outData = processor(obj, inData)
            if(obj.objtype == 0)
                outData = inData;
            else
                outData = obj.tool(inData);
            end
        end
    end
    methods(Access=private) % callbacks
        function rollOffChanged(obj, event) % shaping filter
            obj.tool.delete;
            sps=obj.sampleRate/obj.symbolrate;
            if (obj.RisedcosineCheckBox.Value == 1)
                obj.tool = comm.RaisedCosineReceiveFilter("Shape","Square root","RolloffFactor",obj.RolloffEditField.Value,"InputSamplesPerSymbol",sps);%,"FilterSpanInSymbols",10,"DecimationFactor",24);
            else
                obj.tool = comm.RaisedCosineReceiveFilter("Shape","Normal","RolloffFactor",obj.RolloffEditField.Value,"InputSamplesPerSymbol",sps);%,"FilterSpanInSymbols",10,"DecimationFactor",24);
            end
        end
        function rrcChanged(obj, event) % shaping filter
            obj.tool.delete;
                        sps=obj.sampleRate/obj.symbolrate;
            if (obj.RisedcosineCheckBox.Value == 1)
                obj.tool = comm.RaisedCosineReceiveFilter("Shape","Square root","RolloffFactor",obj.RolloffEditField.Value,"InputSamplesPerSymbol",sps);%,"FilterSpanInSymbols",10,"DecimationFactor",24);
            else
                obj.tool = comm.RaisedCosineReceiveFilter("Shape","Normal","RolloffFactor",obj.RolloffEditField.Value,"InputSamplesPerSymbol",sps);%,"FilterSpanInSymbols",10,"DecimationFactor",24);
            end
        end
        function StopbandHzEditFieldChanged(obj, event)
            obj.tool.delete;                   
            obj.tool=dsp.LowpassFilter('SampleRate',obj.sampleRate, 'PassbandFrequency',obj.PassbandHzEditField.Value, ...
                'StopbandFrequency', obj.StopbandHzEditField.Value);
        end
        function StartbandHzEditFieldChanged(obj, event)
            obj.tool.delete;
            obj.tool=dsp.LowpassFilter('SampleRate',obj.sampleRate, 'PassbandFrequency',obj.PassbandHzEditField.Value, ...
                'StopbandFrequency', obj.StopbandHzEditField.Value);
        end
    end
    methods(Access=private) % GUI & init
        function deleteUI(obj)
            switch obj.objtype
                case 1 % DC block
                case 2 % Low pass
                    obj.StopbandHzEditField.delete;
                    obj.StopbandHzEditFieldLabel.delete;
                    obj.PassbandHzEditField.delete;
                    obj.PassbandHzEditFieldLabel.delete;
                case 3 % Shaping filter
                    obj.RisedcosineCheckBox.delete;
                    obj.RolloffEditField.delete;
                    obj.RolloffEditFieldLabel.delete;
                case 4 % Coarse carrier est
                case 5 % Fine carrier est
                case 6 % Retimer
            end
        end
        function drawCmdRised(obj)
            % Create RisedcosineCheckBox
            obj.RisedcosineCheckBox = uicheckbox(obj.panel);
            obj.RisedcosineCheckBox.Text = 'Rised cosine';
            obj.RisedcosineCheckBox.Position = [21 153 91 22];
            obj.RisedcosineCheckBox.Value=1;
            obj.RisedcosineCheckBox.ValueChangedFcn = createCallbackFcn(obj, @rrcChanged, true);
             % Create RolloffEditFieldLabel
            obj.RolloffEditFieldLabel = uilabel(obj.panel);
            obj.RolloffEditFieldLabel.HorizontalAlignment = 'right';
            obj.RolloffEditFieldLabel.Position = [18 117 39 22];
            obj.RolloffEditFieldLabel.Text = 'Rolloff';

            % Create RolloffEditField
            obj.RolloffEditField = uieditfield(obj.panel, 'numeric');
            obj.RolloffEditField.Limits = [0 1];
            obj.RolloffEditField.Position = [74 117 43 22];
            obj.RolloffEditField.Value = 0.35;
            obj.RolloffEditField.ValueChangedFcn = createCallbackFcn(obj, @rollOffChanged, true);
        end
        function drawLP(obj)
             % Create PassbandHzEditFieldLabel
            obj.PassbandHzEditFieldLabel = uilabel(obj.panel);
            obj.PassbandHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.PassbandHzEditFieldLabel.Position = [6 150 58 30];
            obj.PassbandHzEditFieldLabel.Text = {'Passband'; '[Hz]'};

            % Create PassbandHzEditField
            obj.PassbandHzEditField = uieditfield(obj.panel, 'numeric');
            obj.PassbandHzEditField.Position = [81 154 43 22];
            obj.PassbandHzEditField.Limits = [0 2400000];
            obj.PassbandHzEditField.Value = 150000;
            obj.PassbandHzEditField.ValueChangedFcn = createCallbackFcn(obj, @StartbandHzEditFieldChanged, true);

            % Create StopbandHzEditFieldLabel
            obj.StopbandHzEditFieldLabel = uilabel(obj.panel);
            obj.StopbandHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.StopbandHzEditFieldLabel.Position = [8 113 56 30];
            obj.StopbandHzEditFieldLabel.Text = {'Stopband'; '[Hz]'};

            % Create StopbandHzEditField
            obj.StopbandHzEditField = uieditfield(obj.panel, 'numeric');
            obj.StopbandHzEditField.Position = [81 117 43 22];
            obj.StopbandHzEditField.Limits = [0 2400000];
            obj.StopbandHzEditField.Value = 180000;
            obj.StopbandHzEditField.ValueChangedFcn = createCallbackFcn(obj, @StopbandHzEditFieldChanged, true);

        end
    end
end

