%% PCI四通道指定原始样点范围快速预览
% 只修改下面的文件名、起始点和终止点后直接运行。

close all;
clear;
clc;

%% =========================== 用户配置区 ===========================
dataDirectory = ...
    "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260809";

% 文件名留空时，自动选择数据目录中最新的 *.pci。
% 更换数据时只需修改下面这一行。
pciFileName = "dat2_62M5_4CH.pci";

% PCI存储格式与读取范围。
sampleRateHz = 62.5e6;
recordedChannelCount = 4;
headerBytes = 1024;
previewStartSample = 22000000; % 每通道原始起始点，从1开始
previewEndSample = 24000000;   % 原始终止点；Inf表示一直读到文件末尾
checkFileSizeStable = true;   % 数据仍在拷贝时拒绝读取
fileSizeRecheckSeconds = 1;

% 通道角色。修改这几个索引即可改变通道映射，后续代码不写死通道号。
pulseChannel = 1;             % 脉冲信号真实采样
adaptiveClockChannel = 2;     % DPLL的500倍自适应时钟输出
phaseResidualChannel = 3;     % DAC1输出的DPLL相位残差
referenceChannel = 4;         % FPGA ADC端实际输入参考的高阻分支
channelLabels = [ ...
    "CH1 脉冲信号真实采样", ...
    "CH2 DPLL自适应时钟（500倍频）", ...
    "CH3 DPLL相位残差（DAC1）", ...
    "CH4 FPGA ADC输入参考高阻分支"];
plotChannels = 1:recordedChannelCount;

% 四路统一为 +/-1 V量程、14 bit、交流耦合。
adcBits = 14;
adcZeroCode = 8192;
adcCountsPerVolt = 8192;
stripFirstSampleChannelFlag = true;
clipMarginCodes = 4;          % 距0或满码小于等于4码计为贴近削顶
maximumClipFraction = 1e-4;
minimumAcRmsVolts = [1e-3, 20e-3, 1e-5, 20e-3];

% DAC1相位残差标定。必须与FPGA DAC1的format/gain一致。
phaseRadiansPerVolt = pi / 16;
phasePeakWarningMrad = 180;

% 频率与倍频关系检查，均可在此调整，不在程序中写死。
expectedReferenceHz = 23e3;
referenceSearchBandHz = [15e3, 35e3];
adaptiveClockMultiplier = 500;
expectedAdaptiveClockHz = adaptiveClockMultiplier * expectedReferenceHz;
adaptiveClockSearchBandHz = [8e6, 15e6];
expectedFrequencyToleranceFraction = 0.20;
multiplierToleranceFraction = 0.02;
frequencyFftMaxSamples = 2^20;
minimumClockToneRoleSeparationDb = 20; % 防止把相位残差中的时钟串扰认成时钟本身

% 脉冲活动快速检查只用于判断“有没有采到脉冲”，不作精确峰位计算。
enablePulseActivityCheck = true;
pulseEnvelopeSmoothSamples = 25;
pulseThresholdMadFactor = 6;
pulseThresholdPeakFraction = 0.30;
pulseRegionMergeGapSeconds = 0.5e-3;
referenceCyclesPerPulse = 113;
pulsePeriodToleranceFraction = 0.20;

% 四通道必须使用完全相同的时间窗，才能逐时刻交叉对照。
% NaN表示从起点画到本次读取段末尾。
plotStartOffsetSeconds = 0;
commonPlotSpanSeconds = NaN;
maximumPlotPointsPerChannel = 200000;
showSpectrumFigure = true;

% 默认只在命令窗和图窗中显示；如需留档可改为true。
saveSummaryMat = false;
summaryMatSuffix = "_quick_check.mat";
%% ========================= 用户配置区结束 =========================

%% 配置合法性
validateattributes(sampleRateHz, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(recordedChannelCount, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
validateattributes(previewStartSample, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
validateattributes(previewEndSample, {'numeric'}, ...
    {'scalar', 'positive'});
roleChannels = [pulseChannel, phaseResidualChannel, ...
    adaptiveClockChannel, referenceChannel];
if any(roleChannels < 1 | roleChannels > recordedChannelCount) || ...
        numel(unique(roleChannels)) ~= numel(roleChannels)
    error('PCIQuickCheck:InvalidChannelMap', ...
        '四个角色通道必须是范围内互不重复的整数。');
end
if numel(channelLabels) ~= recordedChannelCount || ...
        numel(minimumAcRmsVolts) ~= recordedChannelCount
    error('PCIQuickCheck:ConfigurationLength', ...
        'channelLabels/minimumAcRmsVolts必须与通道数等长。');
end
if any(plotChannels < 1 | plotChannels > recordedChannelCount)
    error('PCIQuickCheck:InvalidPlotChannel', 'plotChannels包含无效通道号。');
end
validateattributes(plotStartOffsetSeconds, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
if ~(isnumeric(commonPlotSpanSeconds) && isscalar(commonPlotSpanSeconds) && ...
        (isnan(commonPlotSpanSeconds) || ...
        (isfinite(commonPlotSpanSeconds) && commonPlotSpanSeconds > 0)))
    error('PCIQuickCheck:InvalidPlotSpan', ...
        'commonPlotSpanSeconds必须是正数或NaN。');
end

%% 定位PCI文件
if ~isfolder(dataDirectory)
    error('PCIQuickCheck:DataDirectoryNotFound', ...
        '数据目录不存在：%s', dataDirectory);
end
if strlength(pciFileName) == 0
    candidates = dir(fullfile(dataDirectory, '*.pci'));
    if isempty(candidates)
        error('PCIQuickCheck:NoPciFile', ...
            '目录中还没有PCI文件：%s', dataDirectory);
    end
    [~, newestIndex] = max([candidates.datenum]);
    pciPath = string(fullfile(candidates(newestIndex).folder, ...
        candidates(newestIndex).name));
    fprintf('文件名留空，自动选择最新PCI：%s\n', pciPath);
else
    pciPath = string(fullfile(dataDirectory, pciFileName));
end
if ~isfile(pciPath)
    error('PCIQuickCheck:PciNotFound', 'PCI文件不存在：%s', pciPath);
end

fileInfo = dir(pciPath);
if checkFileSizeStable
    firstBytes = fileInfo.bytes;
    pause(fileSizeRecheckSeconds);
    fileInfo = dir(pciPath);
    if fileInfo.bytes ~= firstBytes
        error('PCIQuickCheck:FileStillCopying', ...
            'PCI文件大小仍在变化（%d -> %d bytes），请等待拷贝完成。', ...
            firstBytes, fileInfo.bytes);
    end
end

dataBytes = double(fileInfo.bytes) - headerBytes;
bytesPerFrame = 2 * recordedChannelCount;
if dataBytes <= 0 || mod(dataBytes, bytesPerFrame) ~= 0
    error('PCIQuickCheck:InvalidPciLength', ...
        '数据区字节数与%d通道uint16交替格式不匹配。', recordedChannelCount);
end
totalSamplesPerChannel = dataBytes / bytesPerFrame;
if previewStartSample > totalSamplesPerChannel
    error('PCIQuickCheck:PreviewStartOutsideFile', ...
        '预览起点%d超出每通道总点数%d。', ...
        previewStartSample, totalSamplesPerChannel);
end
actualPreviewEndSample = min(previewEndSample, totalSamplesPerChannel);
actualRequestedCount = actualPreviewEndSample - previewStartSample + 1;

fprintf('\n=== PCI四通道快速检查 ===\n');
fprintf('文件：%s\n', pciPath);
fprintf('大小：%.3f GiB；通道数：%d；采样率：%.6f MHz\n', ...
    fileInfo.bytes / 2^30, recordedChannelCount, sampleRateHz / 1e6);
fprintf('每通道总点数：%d；总时长：%.6f s\n', ...
    totalSamplesPerChannel, totalSamplesPerChannel / sampleRateHz);
fprintf('读取范围：%d .. %d（%.3f ms）\n', ...
    previewStartSample, actualPreviewEndSample, ...
    1e3 * actualRequestedCount / sampleRateHz);

%% 分块中只读开头小段
fileId = fopen(pciPath, 'r', 'l');
if fileId < 0
    error('PCIQuickCheck:PciOpenFailed', '无法打开PCI文件：%s', pciPath);
end
fileCleanup = onCleanup(@() fclose(fileId));
byteOffset = headerBytes + 2 * ...
    ((previewStartSample - 1) * recordedChannelCount);
if fseek(fileId, byteOffset, 'bof') ~= 0
    error('PCIQuickCheck:PciSeekFailed', '无法定位到预览起点。');
end
rawCode = fread(fileId, [recordedChannelCount, actualRequestedCount], ...
    'uint16=>uint16');
clear fileCleanup
actualReadCount = size(rawCode, 2);
if actualReadCount ~= actualRequestedCount
    error('PCIQuickCheck:ShortRead', '实际只读到%d/%d帧。', ...
        actualReadCount, actualRequestedCount);
end

channelFlagPresent = false(recordedChannelCount, 1);
if stripFirstSampleChannelFlag && previewStartSample == 1
    channelFlagPresent = rawCode(:, 1) >= 32768;
    rawCode(channelFlagPresent, 1) = ...
        rawCode(channelFlagPresent, 1) - uint16(32768);
end

maximumCode = 2^adcBits - 1;
invalidCode = rawCode > maximumCode;
voltage = (double(rawCode) - adcZeroCode) / adcCountsPerVolt;
voltage(invalidCode) = NaN;

%% 逐通道幅度、偏置和削顶检查
rawMinimum = nan(recordedChannelCount, 1);
rawMaximum = nan(recordedChannelCount, 1);
dcOffsetMv = nan(recordedChannelCount, 1);
acRmsMv = nan(recordedChannelCount, 1);
peakToPeakV = nan(recordedChannelCount, 1);
clipFraction = nan(recordedChannelCount, 1);
invalidCount = zeros(recordedChannelCount, 1);
channelStatus = strings(recordedChannelCount, 1);
for channel = 1:recordedChannelCount
    codes = double(rawCode(channel, :));
    invalidCount(channel) = nnz(invalidCode(channel, :));
    codes(invalidCode(channel, :)) = NaN;
    volts = voltage(channel, :);
    rawMinimum(channel) = min(codes, [], 'omitnan');
    rawMaximum(channel) = max(codes, [], 'omitnan');
    dcOffsetMv(channel) = 1e3 * mean(volts, 'omitnan');
    centeredVolts = volts - mean(volts, 'omitnan');
    acRmsMv(channel) = 1e3 * sqrt(mean(centeredVolts.^2, 'omitnan'));
    peakToPeakV(channel) = max(volts, [], 'omitnan') - ...
        min(volts, [], 'omitnan');
    nearRail = codes <= clipMarginCodes | ...
        codes >= maximumCode - clipMarginCodes;
    clipFraction(channel) = mean(nearRail, 'omitnan');
    if invalidCount(channel) > 0
        channelStatus(channel) = "FAIL_CODE";
    elseif clipFraction(channel) > maximumClipFraction
        channelStatus(channel) = "WARN_CLIP";
    elseif acRmsMv(channel) < 1e3 * minimumAcRmsVolts(channel)
        channelStatus(channel) = "WARN_LOW";
    else
        channelStatus(channel) = "PASS";
    end
end

channelNumber = (1:recordedChannelCount).';
amplitudeTable = table(channelNumber, channelLabels(:), rawMinimum, ...
    rawMaximum, dcOffsetMv, acRmsMv, peakToPeakV, ...
    100 * clipFraction, invalidCount, channelStatus, ...
    'VariableNames', {'channel', 'label', 'raw_min', 'raw_max', ...
    'dc_offset_mV', 'ac_rms_mV', 'peak_to_peak_V', ...
    'near_rail_percent', 'invalid_code_count', 'status'});
disp(amplitudeTable);

%% 参考和自适应时钟主频率
referenceTone = estimate_tone_in_band(voltage(referenceChannel, :), ...
    sampleRateHz, referenceSearchBandHz, frequencyFftMaxSamples);
clockTone = estimate_tone_in_band(voltage(adaptiveClockChannel, :), ...
    sampleRateHz, adaptiveClockSearchBandHz, frequencyFftMaxSamples);
phaseClockBandTone = estimate_tone_in_band(voltage(phaseResidualChannel, :), ...
    sampleRateHz, adaptiveClockSearchBandHz, frequencyFftMaxSamples);
measuredMultiplier = clockTone.frequency_hz / referenceTone.frequency_hz;
referenceFrequencyError = (referenceTone.frequency_hz - ...
    expectedReferenceHz) / expectedReferenceHz;
clockFrequencyError = (clockTone.frequency_hz - ...
    expectedAdaptiveClockHz) / expectedAdaptiveClockHz;
multiplierError = (measuredMultiplier - adaptiveClockMultiplier) / ...
    adaptiveClockMultiplier;
clockToneRoleSeparationDb = 20 * log10(max(clockTone.peak_magnitude, eps) / ...
    max(phaseClockBandTone.peak_magnitude, eps));

fprintf('\n=== 频率与倍频关系 ===\n');
fprintf('参考 CH%d：%.6f Hz，带内峰值/噪声中位数 %.2f dB\n', ...
    referenceChannel, referenceTone.frequency_hz, referenceTone.snr_db);
fprintf('自适应时钟 CH%d：%.6f Hz，带内峰值/噪声中位数 %.2f dB\n', ...
    adaptiveClockChannel, clockTone.frequency_hz, clockTone.snr_db);
fprintf('实测倍频比：%.9f（目标 %.9f，相对误差 %.4f%%）\n', ...
    measuredMultiplier, adaptiveClockMultiplier, 100 * multiplierError);
fprintf(['通道身份交叉核验：CH%d时钟主峰比CH%d相位通道的同频串扰' ...
    '高 %.3f dB（要求 >= %.3f dB）\n'], ...
    adaptiveClockChannel, phaseResidualChannel, ...
    clockToneRoleSeparationDb, minimumClockToneRoleSeparationDb);

%% 相位残差换算
phaseResidualMrad = 1e3 * phaseRadiansPerVolt * ...
    voltage(phaseResidualChannel, :);
phaseResidualMeanMrad = mean(phaseResidualMrad, 'omitnan');
phaseResidualStdMrad = std(phaseResidualMrad, 0, 'omitnan');
phaseResidualPeakAbsMrad = max(abs(phaseResidualMrad), [], 'omitnan');
fprintf('\n=== DPLL相位残差 CH%d ===\n', phaseResidualChannel);
fprintf('均值 %.6f mrad；标准差 %.6f mrad；最大绝对值 %.6f mrad\n', ...
    phaseResidualMeanMrad, phaseResidualStdMrad, phaseResidualPeakAbsMrad);
if phaseResidualPeakAbsMrad >= phasePeakWarningMrad
    warning('PCIQuickCheck:LargePhaseResidual', ...
        '相位残差峰值已达%.3f mrad，请检查DAC/ADC量程或失锁。', ...
        phaseResidualPeakAbsMrad);
end

%% 脉冲活动区域快速检查
pulseActivity = struct('event_count', 0, 'locations', zeros(0, 1), ...
    'threshold_volts', NaN, 'median_spacing_s', NaN);
if any(enablePulseActivityCheck(:))
    pulseActivity = detect_pulse_activity(voltage(pulseChannel, :), ...
        sampleRateHz, pulseEnvelopeSmoothSamples, ...
        pulseThresholdMadFactor, pulseThresholdPeakFraction, ...
        pulseRegionMergeGapSeconds);
    fprintf('\n=== 脉冲活动 CH%d（非精确峰位）===\n', pulseChannel);
    fprintf('超阈值活动区域：%d；包络阈值：%.6f V\n', ...
        pulseActivity.event_count, pulseActivity.threshold_volts);
    if isfinite(pulseActivity.median_spacing_s)
        fprintf('活动区域中位间距：%.6f ms（可能同时包含采样峰与干扰结构）\n', ...
            1e3 * pulseActivity.median_spacing_s);
    end
end
pulseExpectedPeriodS = referenceCyclesPerPulse / ...
    referenceTone.frequency_hz;
if enablePulseActivityCheck && isfinite(pulseActivity.median_spacing_s)
    pulsePeriodRelativeError = (pulseActivity.median_spacing_s - ...
        pulseExpectedPeriodS) / pulseExpectedPeriodS;
    fprintf('根据%d个参考周期推导的脉冲周期：%.6f ms；相对误差 %.3f%%\n', ...
        referenceCyclesPerPulse, 1e3 * pulseExpectedPeriodS, ...
        100 * pulsePeriodRelativeError);
else
    pulsePeriodRelativeError = NaN;
end

%% 总体判定
codePassed = all(invalidCount == 0);
clipPassed = all(clipFraction <= maximumClipFraction);
amplitudePassed = all(acRmsMv >= 1e3 * minimumAcRmsVolts(:));
referencePassed = abs(referenceFrequencyError) <= ...
    expectedFrequencyToleranceFraction;
clockPassed = abs(clockFrequencyError) <= ...
    expectedFrequencyToleranceFraction;
multiplierPassed = abs(multiplierError) <= multiplierToleranceFraction;
clockRolePassed = clockToneRoleSeparationDb >= ...
    minimumClockToneRoleSeparationDb;
phaseRangePassed = phaseResidualPeakAbsMrad < phasePeakWarningMrad;
pulsePassed = ~enablePulseActivityCheck || ...
    (pulseActivity.event_count >= 2 && ...
    isfinite(pulsePeriodRelativeError) && ...
    abs(pulsePeriodRelativeError) <= pulsePeriodToleranceFraction);

if ~codePassed || ~referencePassed || ~clockPassed || ...
        ~multiplierPassed || ~clockRolePassed
    overallStatus = "FAIL";
elseif ~clipPassed || ~amplitudePassed || ~phaseRangePassed || ~pulsePassed
    overallStatus = "WARNING";
else
    overallStatus = "PASS";
end
fprintf('\n=== 总体判定：%s ===\n', overallStatus);
fprintf(['14位码合法=%d，无削顶=%d，幅度有效=%d，参考频率=%d，' ...
    '时钟频率=%d，倍频比=%d，通道身份=%d，相位范围=%d，脉冲周期=%d\n'], ...
    codePassed, clipPassed, amplitudePassed, referencePassed, ...
    clockPassed, multiplierPassed, clockRolePassed, phaseRangePassed, ...
    pulsePassed);
if overallStatus ~= "PASS"
    fprintf('请优先根据上表status、频率和倍频比检查接线/量程/通道映射。\n');
end

%% 时域预览
plotFirstIndex = 1 + round(plotStartOffsetSeconds * sampleRateHz);
if plotFirstIndex > actualReadCount
    error('PCIQuickCheck:PlotStartOutsidePreview', ...
        '绘图起点超出本次读取的%d个点。', actualReadCount);
end
if isnan(commonPlotSpanSeconds)
    plotLastIndex = actualReadCount;
else
    plotPointCount = max(2, round(commonPlotSpanSeconds * sampleRateHz));
    plotLastIndex = min(actualReadCount, plotFirstIndex + plotPointCount - 1);
end
plotStride = max(1, ceil((plotLastIndex - plotFirstIndex + 1) / ...
    maximumPlotPointsPerChannel));
plotIndices = (plotFirstIndex:plotStride:plotLastIndex).';
if plotIndices(end) ~= plotLastIndex
    plotIndices(end + 1) = plotLastIndex;
end
absoluteSample = previewStartSample - 1 + double(plotIndices);
commonTimeMs = 1e3 * (absoluteSample - 1) / sampleRateHz;

figure('Color', 'w', 'Name', 'PCI四通道时域快速预览');
layout = tiledlayout(numel(plotChannels), 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('%s：四通道共用 %.6f–%.6f ms 时间窗（%s）', ...
    fileInfo.name, commonTimeMs(1), commonTimeMs(end), overallStatus), ...
    'Interpreter', 'none');
timeAxes = gobjects(numel(plotChannels), 1);
for plotIndex = 1:numel(plotChannels)
    channel = plotChannels(plotIndex);
    ax = nexttile(layout);
    timeAxes(plotIndex) = ax;
    if channel == phaseResidualChannel
        plot(ax, commonTimeMs, phaseResidualMrad(plotIndices), '-', ...
            'LineWidth', 0.8);
        ylabel(ax, '相位残差 (mrad)');
    else
        plot(ax, commonTimeMs, voltage(channel, plotIndices), '-', ...
            'LineWidth', 0.8);
        ylabel(ax, '电压 (V)');
    end
    title(ax, sprintf('%s；AC RMS %.3f mV；峰峰值 %.3f V', ...
        channelLabels(channel), acRmsMv(channel), peakToPeakV(channel)), ...
        'Interpreter', 'none');
    xlabel(ax, '固定62.5 MHz时间轴 (ms)');
    grid(ax, 'on');
end
linkaxes(timeAxes, 'x');
xlim(timeAxes, [commonTimeMs(1), commonTimeMs(end)]);

%% 参考与自适应时钟带内频谱
if showSpectrumFigure
    figure('Color', 'w', 'Name', '参考与自适应时钟频谱检查');
    spectrumLayout = tiledlayout(2, 1, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    title(spectrumLayout, sprintf('实测倍频比 %.6f，目标 %.6f', ...
        measuredMultiplier, adaptiveClockMultiplier));

    ax = nexttile(spectrumLayout);
    plot(ax, referenceTone.plot_frequency_hz / 1e3, ...
        referenceTone.plot_magnitude_db, 'LineWidth', 0.9);
    xline(ax, referenceTone.frequency_hz / 1e3, '--r', ...
        sprintf('%.3f kHz', referenceTone.frequency_hz / 1e3));
    xlabel(ax, '频率 (kHz)'); ylabel(ax, '归一化幅度 (dB)');
    title(ax, channelLabels(referenceChannel), 'Interpreter', 'none');
    grid(ax, 'on');

    ax = nexttile(spectrumLayout);
    plot(ax, clockTone.plot_frequency_hz / 1e6, ...
        clockTone.plot_magnitude_db, 'LineWidth', 0.9);
    xline(ax, clockTone.frequency_hz / 1e6, '--r', ...
        sprintf('%.6f MHz', clockTone.frequency_hz / 1e6));
    xlabel(ax, '频率 (MHz)'); ylabel(ax, '归一化幅度 (dB)');
    title(ax, channelLabels(adaptiveClockChannel), 'Interpreter', 'none');
    grid(ax, 'on');
end

%% 在工作区中保留结构化结果
pciQuickCheck = struct();
pciQuickCheck.schema_version = 1;
pciQuickCheck.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
pciQuickCheck.pci_path = char(pciPath);
pciQuickCheck.sample_rate_hz = sampleRateHz;
pciQuickCheck.channel_count = recordedChannelCount;
pciQuickCheck.channel_labels = channelLabels;
pciQuickCheck.total_samples_per_channel = totalSamplesPerChannel;
pciQuickCheck.preview_start_sample = previewStartSample;
pciQuickCheck.preview_sample_count = actualReadCount;
pciQuickCheck.channel_flag_present = channelFlagPresent;
pciQuickCheck.amplitude_table = amplitudeTable;
pciQuickCheck.reference_tone = referenceTone;
pciQuickCheck.adaptive_clock_tone = clockTone;
pciQuickCheck.phase_clock_band_tone = phaseClockBandTone;
pciQuickCheck.measured_multiplier = measuredMultiplier;
pciQuickCheck.clock_tone_role_separation_db = clockToneRoleSeparationDb;
pciQuickCheck.phase_residual_mean_mrad = phaseResidualMeanMrad;
pciQuickCheck.phase_residual_std_mrad = phaseResidualStdMrad;
pciQuickCheck.phase_residual_peak_abs_mrad = phaseResidualPeakAbsMrad;
pciQuickCheck.pulse_activity = pulseActivity;
pciQuickCheck.pulse_expected_period_s = pulseExpectedPeriodS;
pciQuickCheck.pulse_period_relative_error = pulsePeriodRelativeError;
pciQuickCheck.overall_status = char(overallStatus);
pciQuickCheck.checks = struct('code_passed', codePassed, ...
    'clip_passed', clipPassed, 'amplitude_passed', amplitudePassed, ...
    'reference_frequency_passed', referencePassed, ...
    'adaptive_clock_frequency_passed', clockPassed, ...
    'multiplier_passed', multiplierPassed, ...
    'clock_channel_role_passed', clockRolePassed, ...
    'phase_range_passed', phaseRangePassed, ...
    'pulse_activity_passed', pulsePassed);

if any(saveSummaryMat(:))
    [pciDirectory, pciBaseName] = fileparts(pciPath);
    summaryPath = fullfile(pciDirectory, pciBaseName + summaryMatSuffix);
    if isfile(summaryPath)
        error('PCIQuickCheck:SummaryExists', ...
            '拒绝覆盖已有快速检查MAT：%s', summaryPath);
    end
    save(summaryPath, 'pciQuickCheck', '-v7.3');
    fprintf('快速检查MAT：%s\n', summaryPath);
end

%% 本脚本的局部函数
function tone = estimate_tone_in_band(signal, sampleRateHz, bandHz, maxSamples)
signal = double(signal(:));
signal = signal(isfinite(signal));
sampleCount = min(numel(signal), round(maxSamples));
if sampleCount < 64
    error('PCIQuickCheck:TooFewToneSamples', '频率分析有效点数少于64。');
end
signal = signal(1:sampleCount);
signal = signal - mean(signal);
windowIndex = (0:sampleCount - 1).';
window = 0.5 - 0.5 * cos(2 * pi * windowIndex / (sampleCount - 1));
nfft = 2^nextpow2(sampleCount);
spectrum = abs(fft(signal .* window, nfft));
spectrum = spectrum(1:nfft / 2 + 1);
frequency = (0:nfft / 2).' * sampleRateHz / nfft;
inside = frequency >= bandHz(1) & frequency <= bandHz(2);
indices = find(inside);
if numel(indices) < 3
    error('PCIQuickCheck:ToneBandTooNarrow', '频率搜索带内FFT点数不足。');
end
[peakMagnitude, relativeIndex] = max(spectrum(indices));
peakIndex = indices(relativeIndex);
fractionalBin = 0;
if peakIndex > 1 && peakIndex < numel(spectrum)
    localLog = log(max(spectrum(peakIndex + (-1:1)), realmin));
    denominator = localLog(1) - 2 * localLog(2) + localLog(3);
    if abs(denominator) > eps
        fractionalBin = 0.5 * (localLog(1) - localLog(3)) / denominator;
        fractionalBin = max(-0.5, min(0.5, fractionalBin));
    end
end
estimatedFrequency = (peakIndex - 1 + fractionalBin) * ...
    sampleRateHz / nfft;
noiseMask = inside;
noiseMask(max(1, peakIndex - 3):min(numel(noiseMask), peakIndex + 3)) = false;
noiseFloor = median(spectrum(noiseMask));
if isempty(noiseFloor) || ~isfinite(noiseFloor), noiseFloor = eps; end

plotMagnitude = spectrum(inside);
plotMagnitudeDb = 20 * log10(max(plotMagnitude, realmin) / ...
    max(max(plotMagnitude), realmin));
tone = struct();
tone.frequency_hz = estimatedFrequency;
tone.snr_db = 20 * log10(max(peakMagnitude, eps) / max(noiseFloor, eps));
tone.peak_magnitude = peakMagnitude;
tone.search_band_hz = bandHz;
tone.sample_count = sampleCount;
tone.nfft = nfft;
tone.plot_frequency_hz = frequency(inside);
tone.plot_magnitude_db = plotMagnitudeDb;
end

function activity = detect_pulse_activity(signal, sampleRateHz, ...
    smoothSamples, thresholdFactor, thresholdPeakFraction, mergeGapSeconds)
signal = double(signal(:));
centered = signal - median(signal, 'omitnan');
envelope = movmean(abs(centered), max(1, round(smoothSamples)), ...
    'omitnan');
baseline = median(envelope, 'omitnan');
sigma = 1.4826 * median(abs(envelope - baseline), 'omitnan');
if ~isfinite(sigma) || sigma <= 0, sigma = std(envelope, 'omitnan'); end
if ~isfinite(sigma) || sigma <= 0, sigma = eps; end
threshold = max(baseline + thresholdFactor * sigma, ...
    thresholdPeakFraction * max(envelope, [], 'omitnan'));
above = find(envelope >= threshold);
locations = zeros(0, 1);
if ~isempty(above)
    mergeGap = max(1, round(mergeGapSeconds * sampleRateHz));
    edges = [0; find(diff(above) > mergeGap); numel(above)];
    locations = zeros(numel(edges) - 1, 1);
    for index = 1:numel(locations)
        region = above(edges(index) + 1:edges(index + 1));
        [~, maximumIndex] = max(envelope(region));
        locations(index) = region(maximumIndex);
    end
end
spacing = diff(locations) / sampleRateHz;
activity = struct();
activity.event_count = numel(locations);
activity.locations = locations;
activity.threshold_volts = threshold;
if isempty(spacing)
    activity.median_spacing_s = NaN;
else
    activity.median_spacing_s = median(spacing);
end
end
