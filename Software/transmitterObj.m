classdef transmitterObj < matlab.apps.AppBase
    % Properties that correspond to app components
    properties (Access = public)
        SigGenPanel                     matlab.ui.container.Panel
        WaveformcontrolsPanel           matlab.ui.container.Panel
        MatchedfilterButtonGroup        matlab.ui.container.ButtonGroup
        GaussianButton                  matlab.ui.control.RadioButton
        RaisedcosineButton               matlab.ui.control.RadioButton
        betaEditField                   matlab.ui.control.NumericEditField
        betaLabel                       matlab.ui.control.Label
        NoneButton                      matlab.ui.control.RadioButton
        CarrierHzEditField              matlab.ui.control.NumericEditField
        CarrierHzEditFieldLabel         matlab.ui.control.Label
        DeltaftwotonesHzEditField       matlab.ui.control.NumericEditField
        DeltaftwotonesHzEditFieldLabel  matlab.ui.control.Label
        SignalButtonGroup               matlab.ui.container.ButtonGroup
        QPSKButton                      matlab.ui.control.RadioButton
        QAMButton                       matlab.ui.control.RadioButton
        SingletoneButton                matlab.ui.control.RadioButton
        AMaudioButton                   matlab.ui.control.RadioButton
        FMaudioButton                   matlab.ui.control.RadioButton
        NoiseButton                     matlab.ui.control.RadioButton
        TonepluscarrierButton           matlab.ui.control.RadioButton
        TwotonesButton                  matlab.ui.control.RadioButton
        HackRFcontrolsPanel             matlab.ui.container.Panel
        TransmitSwitchLabel             matlab.ui.control.Label
        PowerTXSlider                   matlab.ui.control.Slider
        PowerSliderLabel                matlab.ui.control.Label
        TransmitSwitch                  matlab.ui.control.Switch
        AmpCheckBox                     matlab.ui.control.CheckBox
        BasebandfilterDropDown          matlab.ui.control.DropDown
        BasebandfilterDropDownLabel     matlab.ui.control.Label
        SamplerateDropDown              matlab.ui.control.DropDown
        SamplerateDropDownLabel         matlab.ui.control.Label
        AliasingLabel                   matlab.ui.control.Label
        GreenPanel                      matlab.ui.container.Panel
        YellowPanel                     matlab.ui.container.Panel
        RedPanel                        matlab.ui.container.Panel
        colorPanel                      matlab.ui.container.Panel
        QGainEditField                  matlab.ui.control.NumericEditField
        QGainEditFieldLabel             matlab.ui.control.Label
        IGainEditField                  matlab.ui.control.NumericEditField
        IGainEditFieldLabel             matlab.ui.control.Label
    end

    % Properties used inside the tx tab
    properties (Access = private)
        appInstance; % reference to the creator
        hackrfTx; % Hackrf hardware object
        waveform; % waveform choice
        waveReady=0; % stores if the waveform has been already generated or not
        txEnabled; % stores if we are in tx mode or not
        circularIndex; %index where tx routine stopped
        hackrfLibBufferSize=21000000; % the size of the hackrf buffer + some margin
        Ibuffer; % buffer for i data to tx
        Qbuffer; % buffer for q data to tx
        IQbuffer; % buffer for combined iq data to tx
        dpdWorker;
    end

    % HackRF TX callback
    methods (Access = public)
        function IQdata = txCallback(obj, ~, samples)
            switch obj.waveform
                case 0 % Single tone
                    obj.Ibuffer = ones(samples, 1).*(obj.IGainEditField.Value/100);
                    obj.Qbuffer = ones(samples, 1).*(obj.QGainEditField.Value/100);
                    IQdata = obj.Ibuffer + 1i*obj.Qbuffer;
                case 1 % AM

                case 2 % FM

                case 3 % Noise
                    noiseVec = wgn(samples,1,-3,'complex');
                    obj.Ibuffer=clip(real(noiseVec), -1, 1).*(obj.IGainEditField.Value/100);
                    obj.Qbuffer=clip(imag(noiseVec), -1, 1).*(obj.QGainEditField.Value/100);
                    obj.IQbuffer=obj.Ibuffer+1i*obj.Qbuffer;
                    IQdata = complex(obj.IQbuffer(1:samples));
                case {4, 7} % Two tones or single tone plus carrier - we use a circular buffer
                    if(length(obj.Ibuffer)-obj.circularIndex<samples) % if we are near the end of the circular buffer, we need to wrap
                        obj.IQbuffer = obj.Ibuffer(obj.circularIndex:end).*(obj.IGainEditField.Value/100) + 1i*obj.Qbuffer(obj.circularIndex:end).*(obj.QGainEditField.Value/100);
                        remaining= samples-(length(obj.Ibuffer)-obj.circularIndex);
                        obj.IQbuffer = [obj.IQbuffer, (obj.Ibuffer(1:remaining).*(obj.IGainEditField.Value/100)+1i*obj.Qbuffer(1:remaining).*(obj.QGainEditField.Value/100))];
                        obj.circularIndex = remaining+1;
                    else % if we are far enough from the end of the buffer
                        obj.IQbuffer = obj.Ibuffer(obj.circularIndex:obj.circularIndex+samples).*(obj.IGainEditField.Value/100)+1i*obj.Qbuffer(obj.circularIndex:obj.circularIndex+samples).*(obj.QGainEditField.Value/100);
                        obj.circularIndex = obj.circularIndex+samples+1;
                    end
                       IQdata = complex(obj.IQbuffer(1:samples));
                case {5, 6} % QAM
                    if(length(obj.Ibuffer)-obj.circularIndex<samples) % if we are near the end of the circular buffer, we need to wrap
                        obj.IQbuffer = obj.Ibuffer(obj.circularIndex:end).*(obj.IGainEditField.Value/100) + 1i*obj.Qbuffer(obj.circularIndex:end).*(obj.QGainEditField.Value/100);
                        remaining= samples-(length(obj.Ibuffer)-obj.circularIndex);
                        obj.IQbuffer = [obj.IQbuffer, (obj.Ibuffer(1:remaining).*(obj.IGainEditField.Value/100)+1i*obj.Qbuffer(1:remaining).*(obj.QGainEditField.Value/100))];
                        obj.circularIndex = remaining+1;
                    else % if we are far enough from the end of the buffer
                        obj.IQbuffer = obj.Ibuffer(obj.circularIndex:obj.circularIndex+samples).*(obj.IGainEditField.Value/100)+1i*obj.Qbuffer(obj.circularIndex:obj.circularIndex+samples).*(obj.QGainEditField.Value/100);
                        obj.circularIndex = obj.circularIndex+samples+1;
                    end
                    IQdata = complex(obj.IQbuffer(1:samples));
                otherwise
                    IQdata = zeros(samples,1);
            end
        end
    end

    % Tab handling - the main app asks to release hw resources shared among
    % tabs
    methods (Access = public)
        function pauseObj(obj)
            obj.hackrfTx.close;
            obj.TransmitSwitch.Value='Off';
            obj.txEnabled = obj.TransmitSwitch.Value;
            set(obj.CarrierHzEditField,'Enable','on');
            if(obj.waveform==4||obj.waveform==7)
                set(obj.DeltaftwotonesHzEditField,'Enable','on');
            end
            set(obj.SignalButtonGroup,'Enable','on');
        end

        function setPowerGain(obj, gain)
            value = round(gain);
            % move the slider
            obj.PowerTXSlider.Value=value;
            % change gain
            obj.hackrfTx.txvgaGain=value;
        end

        function gain = getPowerGain(obj)
            gain = obj.hackrfTx.txvgaGain;
        end

        function mode = getMeasurementMode(obj)
            mode=obj.waveform;
        end

        % get carrier frequency
        function carrier = getCarrier(obj)
            carrier = obj.CarrierHzEditField.Value;
        end

        % get tone frequency in two tone/tone plus carrier mode
        function tone = getFirstTone(obj)
            if obj.waveform == 4
            tone = obj.CarrierHzEditField.Value + obj.DeltaftwotonesHzEditField.Value;
            else
                tone = obj.CarrierHzEditField.Value - (obj.DeltaftwotonesHzEditField.Value/2);
            end
            
        end

        function tone = getSecondTone(obj)
            tone = obj.CarrierHzEditField.Value + (obj.DeltaftwotonesHzEditField.Value/2);
        end

        % handle markers table window deletion 
        function setTableClosed(obj)
            obj.tableOpenFlag=0;
        end
    end

    % UI interaction and Transmitter functions
    methods (Access = private)

        % function to handle tx buffer preparation
        function waveGen(obj) % here we define new waveforms
            clear obj.Ibuffer;
            clear obj.Qbuffer;
            clear obj.IQbuffer;
            switch obj.waveform
                case 0 % Constant single tone Handled at runtime
                case 1 % AM
                case 2 % FM
                case 3 % Noise - generated at runtime for true noise (not cyclic signal)
                    % noiseVec = wgn(obj.hackrfTx.SampleRate*4,1,-3,'complex');
                    % obj.Ibuffer=clip(real(noiseVec), -1, 1);
                    % obj.Qbuffer=clip(imag(noiseVec), -1, 1);
                    % obj.IQbuffer=obj.Ibuffer+j*obj.Qbuffer;
                case 4 % Single tone plus carrier
                    %genera cicli interi: (floor(samplebuffer*sample_x_cycle))*sample_x_cycle= total samples to generate
                    samplesPerCycle = obj.hackrfTx.SampleRate/obj.DeltaftwotonesHzEditField.Value;
                    samplesToGen=(floor(obj.hackrfLibBufferSize/samplesPerCycle))*samplesPerCycle;
                    maxTime = samplesToGen/obj.hackrfTx.SampleRate;
                    timeline = 0:1/obj.hackrfTx.SampleRate:maxTime;
                    obj.Ibuffer = sinpi(2*timeline*obj.DeltaftwotonesHzEditField.Value).*0.5+0.5;
                    %obj.Qbuffer = -cospi(2*timeline*obj.DeltaftwotonesHzEditField.Value).*0.5+0.5;
                    %obj.Ibuffer = obj.Ibuffer.*0.5+0.5;
                    obj.Qbuffer = hilbert(obj.Ibuffer);
                    %  Clean everything up with a fir ( improves harmonics)
                    lp = designfilt('lowpassfir', ...
                        'PassbandFrequency', obj.DeltaftwotonesHzEditField.Value + 100e3, ...
                        'StopbandFrequency', obj.DeltaftwotonesHzEditField.Value + 200e3, ...
                        'PassbandRipple', 0.1, ...         % dB ripple  
                        'StopbandAttenuation', 150, ...     % dB attenuation
                        'SampleRate', obj.hackrfTx.SampleRate);
                    
                    % Filter only the real part first to preserve phase relationships
                    obj.Ibuffer = filter(lp, real(obj.Qbuffer));
                    obj.Qbuffer = filter(lp, imag(obj.Qbuffer));

                case 5 % QAM
                    Fs = obj.hackrfTx.SampleRate;                  % Output sample rate [Hz]
                    symbolRate = 1e5;        % Symbol rate [Hz]
                    sps = Fs / symbolRate;     % Samples per symbol
                    M = 16;                    % 16-QAM
                    k = log2(M);               % Bits per symbol
                    filterSpan = 10;           % Filter span in symbols
                    % 
                    % % Message to binary
                    % % msg = 'la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
                    % % msgBytes = uint8(msg);                     % Convert chars to bytes
                    % % msgBits = de2bi(msgBytes, 8, 'left-msb');  % Convert to bitsù
                    % % 
                    % % msgBits = msgBits.'; msgBits = msgBits(:);% Column vector of bits
                    % 
                    % msgBits = prbs(7, 21000000/sps*k);
                    % % Pad bits to match QAM symbol size
                    % padBits = mod(-length(msgBits), k);
                    % msgBits = [msgBits; zeros(padBits, 1)];
                    % 
                    % % 16-QAM Modulation
                    % symIdx = bi2de(reshape(msgBits, k, []).', 'left-msb');
                    % modSignal = qammod(symIdx, M); %, 'UnitAveragePower', true);

                    rng(1996)                    % Set seed for repeatable results
                    barker = comm.BarkerCode(... % For preamble
                        Length=13,SamplesPerFrame=13);
                    msgLen = 1200000;
                    numFrames = 10000;
                    frameLen = msgLen/numFrames;

                    preamble = (1+barker())/2;  % Length 13, unipolar
                    data = zeros(msgLen, 1);
                    for idx = 1 : numFrames
                        payload = randi([0 M-1],frameLen-barker.Length,1);
                        data((idx-1)*frameLen + (1:frameLen)) = [preamble; payload];
                    end
                    modSignal = qammod(data, M, 'gray');

                    switch obj.MatchedfilterButtonGroup.SelectedObject
                        case obj.RaisedcosineButton
                            rctFilt = comm.RaisedCosineTransmitFilter(...
                                RolloffFactor=obj.betaEditField.Value, ...
                                FilterSpanInSymbols=filterSpan, ...
                                OutputSamplesPerSymbol=sps);
                            txSignal = rctFilt(modSignal);
                        case obj.GaussianButton
                            filt = gaussdesign(0.3,3,sps); % CHECK THIS VALUES AS ARE RANDOM

                        case obj.NoneButton
                            txSignal = repelem(modSignal, sps);
                    end

                    txSignal = (txSignal / max(abs(txSignal)));
                    txSignal = txSignal.';
                    obj.Ibuffer = real(txSignal);
                    obj.Qbuffer = imag(txSignal);
                    fprintf("Generated QAM. SPS: %d, srate: %d, rolloff: %d, fs: %d\n", sps, symbolRate, obj.betaEditField.Value, Fs);
                    
                case 6 % QPSK
                                        Fs = obj.hackrfTx.SampleRate;                  % Output sample rate [Hz]
                    symbolRate = 1e5;        % Symbol rate [Hz]
                    sps = Fs / symbolRate;     % Samples per symbol
                    M = 4;                    % QPSK
                    k = log2(M);               % Bits per symbol
                    filterSpan = 10;           % Filter span in symbols

                    % Message to binary
                    % msg = 'la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~la risposta è 42! "#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
                    % msgBytes = uint8(msg);                     % Convert chars to bytes
                    % msgBits = de2bi(msgBytes, 8, 'left-msb');  % Convert to bits
                    % 
                    % msgBits = msgBits.'; msgBits = msgBits(:);% Column vector of bits

                    msgBits = prbs(7, 21000000/sps*k);
                    % Pad bits to match QAM symbol size
                    padBits = mod(-length(msgBits), k);
                    msgBits = [msgBits; zeros(padBits, 1)];

                    % QPSK Modulation
                    symIdx = bi2de(reshape(msgBits, k, []).', 'left-msb');
                    modSignal = pskmod(symIdx, M); %, 'UnitAveragePower', true);
                    
                    switch obj.MatchedfilterButtonGroup.SelectedObject
                        case obj.RaisedcosineButton
                            rctFilt = comm.RaisedCosineTransmitFilter(...
                                RolloffFactor=obj.betaEditField.Value, ...
                                FilterSpanInSymbols=filterSpan, ...
                                OutputSamplesPerSymbol=sps);
                            txSignal = rctFilt(modSignal);
                        case obj.GaussianButton
                            % TODO
                        case obj.NoneButton
                            txSignal = repelem(modSignal, sps);
                    end
                    txSignal = (txSignal / max(abs(txSignal)));
                    txSignal = txSignal.';
                    obj.Ibuffer = real(txSignal);
                    obj.Qbuffer = imag(txSignal);
                    fprintf("Generated QPSK. SPS: %d, srate: %d, rolloff: %d, fs: %d\n", sps, symbolRate, obj.betaEditField.Value, Fs);

                case 7 % Two tones
                    samplesPerCycle = obj.hackrfTx.SampleRate/(obj.DeltaftwotonesHzEditField.Value/2);
                    samplesToGen=(floor(obj.hackrfLibBufferSize/samplesPerCycle))*samplesPerCycle;
                    maxTime = samplesToGen/obj.hackrfTx.SampleRate;
                    timeline=0:1/obj.hackrfTx.SampleRate:maxTime;
                    obj.Ibuffer= sinpi(timeline*obj.DeltaftwotonesHzEditField.Value);
                    %obj.Qbuffer= sinpi(timeline*obj.DeltaftwotonesHzEditField.Value);
                    % FIR Bandpass filter to clean up any harmonics
                    bp = designfilt('bandpassfir', ...
                        'StopbandFrequency1', obj.DeltaftwotonesHzEditField.Value/2-30e3, ...
                        'PassbandFrequency1', obj.DeltaftwotonesHzEditField.Value/2-10e3, ...
                        'PassbandFrequency2', obj.DeltaftwotonesHzEditField.Value/2+10e3, ...
                        'StopbandFrequency2', obj.DeltaftwotonesHzEditField.Value/2+30e3, ...
                        'StopbandAttenuation1', 150, ...
                        'StopbandAttenuation2', 150, ...
                        'SampleRate', obj.hackrfTx.SampleRate);
                   obj.Ibuffer = filter(bp, obj.Ibuffer);
                   obj.Qbuffer = obj.Ibuffer;

            end

            obj.circularIndex=1;
            obj.waveReady=1;
        end


        % Selection changed function: SignalButtonGroup
        function SignalButtonGroupSelectionChanged(obj, event)
            switch obj.SignalButtonGroup.SelectedObject
                case obj.SingletoneButton
                    obj.waveform = 0;
                    obj.waveReady = 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','off');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'off');
                case obj.AMaudioButton
                    obj.waveform = 1;
                    obj.waveReady= 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','off');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'off');
                case obj.FMaudioButton
                    obj.waveform = 2;
                    obj.waveReady= 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','off');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'off');
                case obj.NoiseButton
                    obj.waveform = 3;
                    obj.waveReady= 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','off');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'off');
                case obj.TonepluscarrierButton
                    obj.waveform = 4;
                    obj.waveReady= 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','on');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'off');
                case obj.QAMButton
                    obj.waveform = 5;
                    obj.waveReady= 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','off');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'on');
                case obj.QPSKButton
                    obj.waveform = 6;
                    obj.waveReady= 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','off');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'on');
                case obj.TwotonesButton
                    obj.waveform = 7;
                    obj.waveReady= 0;
                    set(obj.DeltaftwotonesHzEditField,'Enable','on');
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'off');
            end
        end

        % Value changed function: CarrierHzEditField
        function CarrierHzEditFieldValueChanged(obj, event)
            obj.hackrfTx.Frequency = obj.CarrierHzEditField.Value; %set new carrier frequency
        end

        % Value changed function: PowerTXSlider
        function PowerTXSliderValueChanged(obj, event)
            % discretize slider
            value = obj.PowerTXSlider.Value;
            % determine which discrete option the current value is closest to.
            value = round(value);
            % move the slider to that option
            obj.PowerTXSlider.Value=value;
            % use the slider for the actual pourpouse:
            obj.hackrfTx.txvgaGain=value;
        end

        % Value changed function: Baseband lowpass filter dropdown
        function BasebandfilterDropDownValueChanged(obj, event)
            switch obj.BasebandfilterDropDown.Value
                case '1.75MHz'
                    obj.hackrfTx.Bandwidth= 1.75e6;
                case '2.5MHz'
                    obj.hackrfTx.Bandwidth= 2.5e6;
                case '3.5MHz'
                    obj.hackrfTx.Bandwidth= 3.5e6;
                case '5MHz'
                    obj.hackrfTx.Bandwidth= 5e6;
                case '5.5MHz'
                    obj.hackrfTx.Bandwidth= 5.5e6;
                case '6MHz'
                    obj.hackrfTx.Bandwidth= 6e6;
                case '7MHz'
                    obj.hackrfTx.Bandwidth= 7e6;
                case '8MHz'
                    obj.hackrfTx.Bandwidth= 8e6;
                case '9MHz'
                    obj.hackrfTx.Bandwidth= 9e6;
                case '10MHz'
                    obj.hackrfTx.Bandwidth= 10e6;
                case '12MHz'
                    obj.hackrfTx.Bandwidth= 12e6;
                case '14MHz'
                    obj.hackrfTx.Bandwidth= 14e6;
                case '15MHz'
                    obj.hackrfTx.Bandwidth= 15e6;
                case '20MHz'
                    obj.hackrfTx.Bandwidth= 20e6;
                case '24MHz'
                    obj.hackrfTx.Bandwidth= 24e6;
                case '28MHz'
                    obj.hackrfTx.Bandwidth= 28e6;
            end
            if(obj.hackrfTx.Bandwidth>obj.hackrfTx.SampleRate)
                obj.AliasingLabel.Visible='on';
            else
                obj.AliasingLabel.Visible='off';
            end
        end

        % Value changed function: Sample rate dropdown
        function SamplerateDropDownValueChanged(obj, event)
            switch obj.SamplerateDropDown.Value
                case '4MHz'
                    obj.hackrfTx.SampleRate= 4e6;
                case '8MHz'
                    obj.hackrfTx.SampleRate= 8e6;
                case '10MHz'
                    obj.hackrfTx.SampleRate= 10e6;
                case '12.5MHz'
                    obj.hackrfTx.SampleRate= 12.5e6;
                case '16MHz'
                    obj.hackrfTx.SampleRate= 16e6;
                case '20MHz'
                    obj.hackrfTx.SampleRate= 20e6;
            end
            obj.waveReady=0;
            BasebandfilterDropDownValueChanged(obj);
        end

        % Value changed function: TransmitSwitch
        function TransmitSwitchValueChanged(obj, event)
            obj.txEnabled = obj.TransmitSwitch.Value;
            if isequal(obj.txEnabled, 'On')
                set(obj.CarrierHzEditField,'Enable','off');
                set(obj.DeltaftwotonesHzEditField,'Enable','off');
                set(obj.SignalButtonGroup,'Enable','off');
                set(obj.MatchedfilterButtonGroup, 'Enable', 'off');
                set(obj.SamplerateDropDown, 'Enable', 'off');

                if obj.waveReady==0
                    obj.waveGen();
                end
                obj.hackrfTx.txStart;
            else
                obj.hackrfTx.txStop;
                set(obj.CarrierHzEditField,'Enable','on');
                if(obj.waveform==4 || obj.waveform==7) % Two tones
                    set(obj.DeltaftwotonesHzEditField,'Enable','on');
                end
                if(obj.waveform==5 || obj.waveform==6) % QAM, QPSK
                    set(obj.MatchedfilterButtonGroup, 'Enable', 'on');
                end
                set(obj.SignalButtonGroup,'Enable','on');
                set(obj.SamplerateDropDown, 'Enable', 'on');
            end
        end

        % Value changed function: DeltaftwotonesHzEditField
        function DeltaftwotonesHzEditFieldValueChanged(obj, event)
            obj.waveReady= 0; %if we change spacing of two tones, we have to generate again the waveform
        end

        % Value changed function: AmpCheckBox
        function AmpCheckBoxValueChanged(obj, event)
            if(obj.AmpCheckBox.Value) % Set or reset amp on hackrf
                obj.hackrfTx.AmpEnable = 1;
            else
                obj.hackrfTx.AmpEnable = 0;
            end
        end
    end

    % UI generation methods
    methods (Access = private)
        function createUIComponents(obj)
            % Create SigGenPanel
            obj.SigGenPanel = uipanel(obj.appInstance.BasicTab);
            obj.SigGenPanel.Title = 'SigGen';
            obj.SigGenPanel.Position = [0 396 971 319];

            % Create HackRFcontrolsPanel
            obj.HackRFcontrolsPanel = uipanel(obj.SigGenPanel);
            obj.HackRFcontrolsPanel.Title = 'HackRF controls';
            obj.HackRFcontrolsPanel.Position = [480 0 491 299];

            % Create Aliasing warning label
            obj.AliasingLabel = uilabel(obj.HackRFcontrolsPanel);
            obj.AliasingLabel.HorizontalAlignment = 'center';
            obj.AliasingLabel.FontWeight = 'bold';
            obj.AliasingLabel.FontColor = [0.6353 0.0784 0.1843];
            obj.AliasingLabel.Position = [8 138 469 22];
            obj.AliasingLabel.Text = 'Warning: baseband filter should be narrower than your sampling rate!';
            obj.AliasingLabel.Visible = 'off';

            % Create AmpCheckBox
            obj.AmpCheckBox = uicheckbox(obj.HackRFcontrolsPanel);
            obj.AmpCheckBox.ValueChangedFcn = createCallbackFcn(obj, @AmpCheckBoxValueChanged, true);
            obj.AmpCheckBox.Text = 'Amp (+11dB)';
            obj.AmpCheckBox.Position = [226 78 92 22];

            % Create TransmitSwitch
            obj.TransmitSwitch = uiswitch(obj.HackRFcontrolsPanel, 'slider');
            obj.TransmitSwitch.ValueChangedFcn = createCallbackFcn(obj, @TransmitSwitchValueChanged, true);
            obj.TransmitSwitch.Position = [380 79 45 20];

            % Create TransmitSwitchLabel
            obj.TransmitSwitchLabel = uilabel(obj.HackRFcontrolsPanel);
            obj.TransmitSwitchLabel.HorizontalAlignment = 'center';
            obj.TransmitSwitchLabel.FontWeight = 'bold';
            obj.TransmitSwitchLabel.Position = [358 57 90 22];
            obj.TransmitSwitchLabel.Text = 'RF Output';

            % Create PowerSliderLabel
            obj.PowerSliderLabel = uilabel(obj.HackRFcontrolsPanel);
            obj.PowerSliderLabel.HorizontalAlignment = 'right';
            %obj.PowerSliderLabel.Position = [14 238 44 22];
            obj.PowerSliderLabel.Position = [14 230 44 30];
            obj.PowerSliderLabel.Text = {'IF Gain'; '[dB]'};

            % ---- Colored Zones Behind Slider ----
            obj.colorPanel = uipanel(obj.HackRFcontrolsPanel, 'Position', [79, 247, 385, 10], 'BorderType', 'none', 'BackgroundColor', 'white');

            % Define proportions based on limits
            greenWidth = (30) / 47 * 385;  % Green (0-30)
            yellowWidth = (39 - 30) / 47 * 385; % Yellow (30-39)
            redWidth = (47 - 39) / 47 * 385; % Red (39-47)

            % Create colored panels
            obj.GreenPanel = uipanel(obj.colorPanel, 'Position', [0, 0, greenWidth, 10], 'BackgroundColor', [0 0.8 0], 'BorderType', 'none');  % Green (0-30)
            obj.YellowPanel = uipanel(obj.colorPanel, 'Position', [greenWidth, 0, yellowWidth, 10], 'BackgroundColor', [1 1 0], 'BorderType', 'none'); % Yellow (30-39)
            obj.RedPanel = uipanel(obj.colorPanel, 'Position', [greenWidth + yellowWidth, 0, redWidth, 10], 'BackgroundColor', [1 0 0], 'BorderType', 'none'); % Red (39-47)

            % Slider
            obj.PowerTXSlider = uislider(obj.HackRFcontrolsPanel, 'Position', [79, 252, 385, 3], 'Limits', [0 47]);
            obj.PowerTXSlider.MinorTicks = 1:47;
            obj.PowerTXSlider.ValueChangedFcn = createCallbackFcn(obj, @PowerTXSliderValueChanged, true);
            %--------------------------------------

            % Create SamplerateDropDownLabel
            obj.SamplerateDropDownLabel = uilabel(obj.HackRFcontrolsPanel);
            obj.SamplerateDropDownLabel.HorizontalAlignment = 'right';
            obj.SamplerateDropDownLabel.Position = [272 177 70 22];
            obj.SamplerateDropDownLabel.Text = 'Sample rate';

            % Create SamplerateDropDown
            obj.SamplerateDropDown = uidropdown(obj.HackRFcontrolsPanel);
            obj.SamplerateDropDown.Items = {'4MHz', '8MHz', '10MHz', '12.5MHz', '16MHz', '20MHz'};
            obj.SamplerateDropDown.Position = [357 174 91 28];
            obj.SamplerateDropDown.Value = '4MHz';
            obj.SamplerateDropDown.ValueChangedFcn = createCallbackFcn(obj, @SamplerateDropDownValueChanged, true);

            % Create BasebandfilterDropDownLabel
            obj.BasebandfilterDropDownLabel = uilabel(obj.HackRFcontrolsPanel);
            obj.BasebandfilterDropDownLabel.HorizontalAlignment = 'right';
            obj.BasebandfilterDropDownLabel.Position = [14 177 85 22];
            obj.BasebandfilterDropDownLabel.Text = 'Baseband filter';

            % Create BasebandfilterDropDown
            obj.BasebandfilterDropDown = uidropdown(obj.HackRFcontrolsPanel);
            obj.BasebandfilterDropDown.Items = {'1.75MHz', '2.5MHz', '3.5MHz', '5MHz', '5.5MHz', '6MHz', '7MHz', '8MHz', '9MHz', '10MHz', '12MHz', '14MHz', '15MHz', '20MHz', '24MHz', '28MHz'};
            obj.BasebandfilterDropDown.Position = [114 177 100 22];
            obj.BasebandfilterDropDown.Value = '1.75MHz';
            obj.BasebandfilterDropDown.ValueChangedFcn = createCallbackFcn(obj, @BasebandfilterDropDownValueChanged, true);

            % Create WaveformcontrolsPanel
            obj.WaveformcontrolsPanel = uipanel(obj.SigGenPanel);
            obj.WaveformcontrolsPanel.Title = 'Waveform controls';
            obj.WaveformcontrolsPanel.Position =  [0 0 481 299];

            % Create SignalButtonGroup
            obj.SignalButtonGroup = uibuttongroup(obj.WaveformcontrolsPanel);
            obj.SignalButtonGroup.SelectionChangedFcn = createCallbackFcn(obj, @SignalButtonGroupSelectionChanged, true);
            obj.SignalButtonGroup.Title = 'Signal';
            obj.SignalButtonGroup.Position = [31 42 160 221];

            % Create TwotonesButton
            obj.TwotonesButton = uiradiobutton(obj.SignalButtonGroup);
            obj.TwotonesButton.Text = 'Two tones';
            obj.TwotonesButton.Position = [11 175 80 22];

            % Create TonepluscarrierButton
            obj.TonepluscarrierButton = uiradiobutton(obj.SignalButtonGroup);
            obj.TonepluscarrierButton.Text = 'Tone plus carrier';
            obj.TonepluscarrierButton.Position = [11 153 110 22];
            obj.TonepluscarrierButton.Value = true;

            % Create NoiseButton
            obj.NoiseButton = uiradiobutton(obj.SignalButtonGroup);
            obj.NoiseButton.Text = 'Noise';
            obj.NoiseButton.Position = [11 109 65 22];

            % Create FMaudioButton
            obj.FMaudioButton = uiradiobutton(obj.SignalButtonGroup);
            obj.FMaudioButton.Text = 'FM audio';
            obj.FMaudioButton.Position = [11 87 72 22];

            % Create AMaudioButton
            obj.AMaudioButton = uiradiobutton(obj.SignalButtonGroup);
            obj.AMaudioButton.Text = 'AM audio';
            obj.AMaudioButton.Position = [11 64 72 22];

            % Create SingletoneButton
            obj.SingletoneButton = uiradiobutton(obj.SignalButtonGroup);
            obj.SingletoneButton.Text = 'Single tone';
            obj.SingletoneButton.Position = [11 131 82 22];

            % Create QAMButton
            obj.QAMButton = uiradiobutton(obj.SignalButtonGroup);
            obj.QAMButton.Text = '16-QAM';
            obj.QAMButton.Position = [11 41 66 22];

            % Create QPSKButton
            obj.QPSKButton = uiradiobutton(obj.SignalButtonGroup);
            obj.QPSKButton.Text = 'QPSK';
            obj.QPSKButton.Position = [11 18 55 22];

            % Create IGainEditFieldLabel
            obj.IGainEditFieldLabel = uilabel(obj.WaveformcontrolsPanel);
            obj.IGainEditFieldLabel.HorizontalAlignment = 'right';
            obj.IGainEditFieldLabel.Interpreter = 'latex';
            obj.IGainEditFieldLabel.Position = [221 162 66 22];
            obj.IGainEditFieldLabel.Text = 'I Gain [\%]';

            % Create IGainEditField
            obj.IGainEditField = uieditfield(obj.WaveformcontrolsPanel, 'numeric');
            obj.IGainEditField.Limits = [0 100];
            obj.IGainEditField.Position = [291 162 34 22];
            obj.IGainEditField.Value = 100;

            % Create QGainEditFieldLabel
            obj.QGainEditFieldLabel = uilabel(obj.WaveformcontrolsPanel);
            obj.QGainEditFieldLabel.HorizontalAlignment = 'right';
            obj.QGainEditFieldLabel.Interpreter = 'latex';
            obj.QGainEditFieldLabel.Position = [329 162 72 22];
            obj.QGainEditFieldLabel.Text = 'Q Gain [\%]';

            % Create QGainEditField
            obj.QGainEditField = uieditfield(obj.WaveformcontrolsPanel, 'numeric');
            obj.QGainEditField.Limits = [0 100];
            obj.QGainEditField.Position = [406 160 37 22];
            obj.QGainEditField.Value = 100;

            % Create DeltaftwotonesHzEditFieldLabel
            obj.DeltaftwotonesHzEditFieldLabel = uilabel(obj.WaveformcontrolsPanel);
            obj.DeltaftwotonesHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.DeltaftwotonesHzEditFieldLabel.Interpreter = 'latex';
            obj.DeltaftwotonesHzEditFieldLabel.Position = [219 195 110 22];
            obj.DeltaftwotonesHzEditFieldLabel.Text = '\Delta f two tones [Hz]';

            % Create DeltaftwotonesHzEditField
            obj.DeltaftwotonesHzEditField = uieditfield(obj.WaveformcontrolsPanel, 'numeric');
            obj.DeltaftwotonesHzEditField.Limits = [1 2000000];
            obj.DeltaftwotonesHzEditField.ValueChangedFcn = createCallbackFcn(obj, @DeltaftwotonesHzEditFieldValueChanged, true);
            obj.DeltaftwotonesHzEditField.Position = [341 195 102 22];
            obj.DeltaftwotonesHzEditField.Value = 1e6;

            % Create CarrierHzEditFieldLabel
            obj.CarrierHzEditFieldLabel = uilabel(obj.WaveformcontrolsPanel);
            obj.CarrierHzEditFieldLabel.HorizontalAlignment = 'right';
            obj.CarrierHzEditFieldLabel.Interpreter = 'latex';
            obj.CarrierHzEditFieldLabel.Position = [252 227 77 22];
            obj.CarrierHzEditFieldLabel.Text = 'Carrier [Hz]';

            % Create CarrierHzEditField
            obj.CarrierHzEditField = uieditfield(obj.WaveformcontrolsPanel, 'numeric');
            obj.CarrierHzEditField.Limits = [26000000 1.6e9];
%-------------------------------------------------------------------------------------------------------------------            
            %obj.CarrierHzEditField.Limits = [26000000 3000000000];
            obj.CarrierHzEditField.ValueChangedFcn = createCallbackFcn(obj, @CarrierHzEditFieldValueChanged, true);
            obj.CarrierHzEditField.Position = [341 227 102 22];
            obj.CarrierHzEditField.Value = 100000000;

            % Create MatchedfilterButtonGroup
            obj.MatchedfilterButtonGroup = uibuttongroup(obj.WaveformcontrolsPanel);
            obj.MatchedfilterButtonGroup.Title = 'Matched filter';
            obj.MatchedfilterButtonGroup.Position = [221 42 222 106];

            % Create NoneButton
            obj.NoneButton = uiradiobutton(obj.MatchedfilterButtonGroup);
            obj.NoneButton.Text = 'None';
            obj.NoneButton.Position = [11 60 58 22];
            
            % Create RaisedcosineButton
            obj.RaisedcosineButton = uiradiobutton(obj.MatchedfilterButtonGroup);
            obj.RaisedcosineButton.Text = 'Root raised cosine';
            obj.RaisedcosineButton.Position = [11 38 121 22];
            obj.RaisedcosineButton.Value = true;

            % Create betaLabel
            obj.betaLabel = uilabel(obj.MatchedfilterButtonGroup);
            obj.betaLabel.HorizontalAlignment = 'right';
            obj.betaLabel.Interpreter = 'latex';
            obj.betaLabel.Position = [130 38 25 22];
            obj.betaLabel.Text = '\beta:';

            % Create betaEditField
            obj.betaEditField = uieditfield(obj.MatchedfilterButtonGroup, 'numeric');
            obj.betaEditField.Limits = [0 1];
            obj.betaEditField.Position = [169 38 47 22];
            obj.betaEditField.Value = 0.35;

            % Create GaussianButton
            obj.GaussianButton = uiradiobutton(obj.MatchedfilterButtonGroup);
            obj.GaussianButton.Text = 'Gaussian';
            obj.GaussianButton.Position = [11 16 72 22];

            set(obj.FMaudioButton,'Enable','off');
            set(obj.AMaudioButton,'Enable','off');
            set(obj.GaussianButton, 'Enable', 'off');

        end
    end

    % Object creation
    methods (Access = public)
        function obj=transmitterObj(app)
            obj.appInstance=app;
            createUIComponents(obj); % create graphical components (UI)
            try
                obj.hackrfTx = hackrf; % try to connect to an hackrf
                obj.hackrfTx.Frequency = obj.CarrierHzEditField.Value; % set carrier frequency
                SamplerateDropDownValueChanged(obj); % set bandwidth and sample rate as in UI
                obj.hackrfTx.txvgaGain = obj.PowerTXSlider.Value;
                obj.hackrfTx.AmpEnable = obj.AmpCheckBox.Value;
                obj.hackrfTx.TransmitFcn = @obj.txCallback;
            catch
               % uialert(obj.appInstance.HackrfTXUIFigure,["HackRF wasn't found during startup!", "Check connections and try again (HackRF MUST be connected while using this program)."],"HackRF not found!", ...
                %    'CloseFcn', @(h,e)delete(obj.appInstance), "Modal",true); % if hackrf is not present, app can't be used
            end
            SignalButtonGroupSelectionChanged(obj); % prepare waveform according to gui
        end

        function deleteUI(obj)
            delete(obj.SigGenPanel);
            delete(obj.WaveformcontrolsPanel);
            delete(obj.MatchedfilterButtonGroup);
            delete(obj.GaussianButton);
            delete(obj.RaisedcosineButton);
            delete(obj.betaEditField);
            delete(obj.betaLabel);
            delete(obj.NoneButton);
            delete(obj.CarrierHzEditField);
            delete(obj.CarrierHzEditFieldLabel);
            delete(obj.DeltaftwotonesHzEditField);
            delete(obj.DeltaftwotonesHzEditFieldLabel);
            delete(obj.SignalButtonGroup);
            delete(obj.QPSKButton);
            delete(obj.QAMButton);
            delete(obj.SingletoneButton);
            delete(obj.AMaudioButton);
            delete(obj.FMaudioButton);
            delete(obj.NoiseButton);
            delete(obj.TonepluscarrierButton);
            delete(obj.TwotonesButton);
            delete(obj.HackRFcontrolsPanel);
            delete(obj.TransmitSwitchLabel);
            delete(obj.PowerTXSlider);
            delete(obj.PowerSliderLabel);
            delete(obj.TransmitSwitch);
            delete(obj.AmpCheckBox);
            delete(obj.BasebandfilterDropDown);
            delete(obj.BasebandfilterDropDownLabel);
            delete(obj.SamplerateDropDown);
            delete(obj.SamplerateDropDownLabel);
            delete(obj.AliasingLabel);
            delete(obj.GreenPanel);
            delete(obj.YellowPanel);
            delete(obj.RedPanel);
            delete(obj.colorPanel);
            delete(obj.QGainEditField);
            delete(obj.QGainEditFieldLabel);
            delete(obj.IGainEditField);
            delete(obj.IGainEditFieldLabel);
        end

        function delete(obj)
            %display('Someone is killing tx!');
            delete(obj.hackrfTx);% Gives warnings in some edge cases if left
            deleteUI(obj);
        end
    end
end
