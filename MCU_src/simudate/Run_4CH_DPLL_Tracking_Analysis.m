%% 四通道DPLL追踪关系分析
% 直接修改本文件头部参数后运行，不需要命令行参数。

close all;
clear;
clc;

scriptDirectory = string(fileparts(mfilename('fullpath')));

%% 输入文件与通道
config.dataDirectory = ...
    "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260809";
config.pciFileName = "dat5_62M5_4CH.pci";
config.sampleRateHz = 62.5e6;
config.channelCount = 4;
config.headerBytes = 1024;
config.processingEndRawSample = inf; % 从第1点处理到此原始点；Inf表示文件末尾
config.pulseChannel = 1;
config.adaptiveClockChannel = 2;
config.phaseResidualChannel = 3;
config.referenceChannel = 4;

%% 物理比例与DAC标定
config.referenceCyclesPerPulse = 113;
config.capturedClockMultiplier = 500;
config.reportClockMultiplier = 2000;
config.phaseRadiansPerVolt = pi / 16;
config.phasePredictionSign = -1;

%% CH1双峰定位
config.nominalReferenceHz = 23.7e3;
config.samplingPeakMinimumVolts = 0.035;
config.doublePeakEventMinimumVolts = 0.008;
config.doublePeakEventMergeSeconds = 25e-6;
config.doublePeakPairToleranceSeconds = 80e-6;
config.samplingTemplateMinimumCorrelation = 0.50;
config.samplingTemplateRefineHalfSamples = 64;
config.samplingTemplateHalfSamples = 200;
config.interactionBeforeRangeSeconds = [0.20e-3, 0.65e-3];

%% CH4参考与CH2时钟的IQ相位观测
config.referenceObservationRateHz = 4000;
config.referenceIqWindowSeconds = 0.5e-3;
config.clockObservationRateHz = 10000;
config.clockIqWindowSeconds = 50e-6;
config.frequencyApertureSeconds = 0.5e-3;

%% PCI固定时间轴连续性诊断
config.pulseSpacingOutlierSamples = 1000;
config.carrierContinuityMadMultiplier = 20;
config.clockCrossingMinimumDeviationSamples = 0.25;
config.referenceCrossingMinimumDeviationSamples = 10;

%% 图像显示范围（原始62.5 MHz样点；算法始终从文件头处理完整记录）
config.displayStartRawSample = 1;
config.displayEndRawSample = inf;

% 四级CIC，R=40，M=2的线性相位群延迟：4*(40*2-1)/2@125 MHz。
config.cicGroupDelaySeconds = 158 / 125e6;

%% CH3相位残差端点读取
config.phaseAverageHalfSamples = 64;
config.phaseDelayScanHalfSeconds = 200e-6;
config.phaseDelayScanStepSamples = 32;

%% 代码与输出位置
config.simudateDirectory = ...
    "E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/MCU_src/simudate";
config.frontendMexDirectory = ...
    "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260723";
config.outputParentDirectory = fullfile(scriptDirectory, ...
    "results_4ch_tracking");
config.showFigures = true;

result = analyze_4ch_dpll_tracking(config);
disp(result.summary);
