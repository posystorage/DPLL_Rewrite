%% 使用独立双峰提取结果重建四通道DPLL评估
% CH1峰位完全来自正负双峰配对；CH2/CH4只用于端点误差和采集连续性标记。

close all;
clear;
clc;

dataDirectory = "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260809";
pciFileName = "dat5_62M5_4CH.pci";
resultDirectory = "E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/" + ...
    "MCU_src/simudate/results_4ch_tracking/dat5_62M5_4CH_20260809_230252";

sampleRateHz = 62.5e6;
channelCount = 4;
pulseChannel = 1;
headerBytes = 1024;
referenceCyclesPerPulse = 113;
capturedClockMultiplier = 500;
reportClockMultiplier = 2000;

pciPath = fullfile(dataDirectory, pciFileName);
old = load(fullfile(resultDirectory, ...
    'four_channel_tracking_analysis.mat'), 'result');
peakAudit = load(fullfile(resultDirectory, ...
    'double_peak_extraction_audit.mat'), 'audit');
clockAudit = load(fullfile(resultDirectory, ...
    'ch2_continuity_audit.mat'), 'continuityAudit');
referenceAudit = load(fullfile(resultDirectory, ...
    'ch4_cic_continuity_audit.mat'), 'continuityAudit');

samplingLocation = peakAudit.audit.pairs.sampling_location_raw;
[samplingLocation, samplingCorrelation] = refine_template_locations( ...
    pciPath, samplingLocation, old.result.peaks.samplingTemplate, 64, ...
    pulseChannel, channelCount, headerBytes);
peakTime = (samplingLocation - 1) / sampleRateHz;

referencePhase = interp1(old.result.referenceCic.time_s, ...
    old.result.referenceCic.phase_cycles, peakTime, 'pchip');
clockPhase = interp1(old.result.adaptiveClock.time_s, ...
    old.result.adaptiveClock.phase_cycles, peakTime, 'pchip');

interval = (1:numel(samplingLocation) - 1).';
startTime = peakTime(1:end - 1);
endTime = peakTime(2:end);
midTime = 0.5 * (startTime + endTime);
pulseSpacing = diff(samplingLocation);
referenceCycles = diff(referencePhase);
clockCycles500 = diff(clockPhase);

scale = reportClockMultiplier / capturedClockMultiplier;
finalError2000 = scale * (clockCycles500 - ...
    capturedClockMultiplier * referenceCyclesPerPulse);
referenceEvent2000 = reportClockMultiplier * ...
    (referenceCycles - referenceCyclesPerPulse);
pllTracking2000 = scale * (clockCycles500 - ...
    capturedClockMultiplier * referenceCycles);
closure2000 = finalError2000 - referenceEvent2000 - pllTracking2000;

spacingMedian = median(pulseSpacing);
spacingAbnormal = abs(pulseSpacing - spacingMedian) >= 1000;
ch2Discontinuity = clockAudit.continuityAudit.intervalTable. ...
    contains_ch2_crossing_outlier;
ch4Discontinuity = referenceAudit.continuityAudit.intervalTable. ...
    contains_ch4_cic_crossing_outlier;
carrierDiscontinuity = ch2Discontinuity | ch4Discontinuity;
ch1OnlyMissingCandidate = spacingAbnormal & ~carrierDiscontinuity;
nominalContinuous = ~spacingAbnormal & ~carrierDiscontinuity;

category = repmat("nominal_continuous", numel(interval), 1);
category(carrierDiscontinuity) = "carrier_discontinuity";
category(ch1OnlyMissingCandidate) = "ch1_only_missing_candidate";

intervalTable = table(interval, startTime, endTime, midTime, ...
    samplingLocation(1:end - 1), samplingLocation(2:end), pulseSpacing, ...
    pulseSpacing - spacingMedian, referenceCycles, clockCycles500, ...
    finalError2000, referenceEvent2000, pllTracking2000, closure2000, ...
    spacingAbnormal, ch2Discontinuity, ch4Discontinuity, ...
    carrierDiscontinuity, ch1OnlyMissingCandidate, category, ...
    'VariableNames', {'interval', 'start_time_s', 'end_time_s', ...
    'mid_time_s', 'sampling_start_raw', 'sampling_end_raw', ...
    'pulse_spacing_62M5', 'spacing_deviation_from_median', ...
    'reference_cycles_cic', 'clock_cycles_500', 'final_error_2000', ...
    'reference_event_2000', 'pll_tracking_2000', 'closure_2000', ...
    'spacing_abnormal', 'ch2_discontinuity', 'ch4_discontinuity', ...
    'carrier_discontinuity', 'ch1_only_missing_candidate', 'category'});

scope = ["all_corrected_intervals"; "nominal_continuous"; ...
    "carrier_discontinuity"; "ch1_only_missing_candidate"];
masks = {true(size(interval)); nominalContinuous; ...
    carrierDiscontinuity; ch1OnlyMissingCandidate};
count = zeros(4, 1);
finalRms = zeros(4, 1);
referenceEventRms = zeros(4, 1);
pllTrackingRms = zeros(4, 1);
finalPeak = zeros(4, 1);
finalRmsMrad = zeros(4, 1);
finalReferenceCorrelation = nan(4, 1);
for k = 1:4
    use = masks{k};
    count(k) = nnz(use);
    finalRms(k) = rms0(finalError2000(use));
    referenceEventRms(k) = rms0(referenceEvent2000(use));
    pllTrackingRms(k) = rms0(pllTracking2000(use));
    finalPeak(k) = max(abs(finalError2000(use)));
    finalRmsMrad(k) = pi * finalRms(k);
    if nnz(use) >= 2
        value = corrcoef(finalError2000(use), referenceEvent2000(use));
        finalReferenceCorrelation(k) = value(1, 2);
    end
end
summaryTable = table(scope, count, finalRms, referenceEventRms, ...
    pllTrackingRms, finalPeak, finalRmsMrad, ...
    finalReferenceCorrelation, ...
    'VariableNames', {'scope', 'interval_count', 'final_rms_2000', ...
    'reference_event_rms_2000', 'pll_tracking_rms_2000', ...
    'final_peak_2000', 'final_rms_mrad', ...
    'final_reference_correlation'});

tableDirectory = fullfile(resultDirectory, 'tables');
figureDirectory = fullfile(resultDirectory, 'figures');
writetable(intervalTable, fullfile(tableDirectory, ...
    'corrected_double_peak_interval_metrics_v2.csv'));
writetable(summaryTable, fullfile(tableDirectory, ...
    'corrected_double_peak_summary_metrics_v2.csv'));

corrected.schemaVersion = 1;
corrected.method = ['CH1-only low-threshold positive/negative double-peak ' ...
    'pairing; local template-correlation fractional refinement'];
corrected.posteriorPeakUsedByController = false;
corrected.samplingLocation = samplingLocation;
corrected.samplingCorrelation = samplingCorrelation;
corrected.intervalTable = intervalTable;
corrected.summaryTable = summaryTable;
corrected.spacingMedian_62M5 = spacingMedian;
save(fullfile(resultDirectory, ...
    'corrected_double_peak_tracking_analysis_v2.mat'), 'corrected', '-v7.3');

timeMs = 1e3 * midTime;
fig = figure('Color', 'w', 'Name', '修正双峰提取后的四通道评估', ...
    'Position', [100 100 1200 850]);
layout = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf(['修正双峰提取：完整双峰%d组；载波断点%d区间；' ...
    'CH1独立缺峰候选%d区间'], numel(samplingLocation), ...
    nnz(carrierDiscontinuity), nnz(ch1OnlyMissingCandidate)));

ax = nexttile(layout);
plot(ax, timeMs, pulseSpacing - spacingMedian, 'k-'); hold(ax, 'on');
scatter(ax, timeMs(carrierDiscontinuity), ...
    pulseSpacing(carrierDiscontinuity) - spacingMedian, 18, ...
    [0.82 0.12 0.12], 'filled');
scatter(ax, timeMs(ch1OnlyMissingCandidate), ...
    pulseSpacing(ch1OnlyMissingCandidate) - spacingMedian, 28, ...
    [0.58 0.16 0.70], 'filled');
ylabel(ax, 'CH1间距偏差 (点)'); grid(ax, 'on');
legend(ax, '全部完整双峰', 'CH2/CH4载波断点', ...
    'CH1独立缺峰候选', 'Location', 'best');

ax = nexttile(layout);
value = finalError2000; value(~nominalContinuous) = NaN;
plot(ax, timeMs, value, 'k-');
ylabel(ax, '最终误差 (点)'); grid(ax, 'on');
title(ax, sprintf('连续正常区间：最终 %.4f点 RMS / %.4f mrad', ...
    finalRms(2), finalRmsMrad(2)));

ax = nexttile(layout);
value1 = referenceEvent2000; value1(~nominalContinuous) = NaN;
value2 = pllTracking2000; value2(~nominalContinuous) = NaN;
plot(ax, timeMs, value1, 'Color', [0.00 0.35 0.78]); hold(ax, 'on');
plot(ax, timeMs, value2, 'Color', [0.90 0.40 0.05]);
ylabel(ax, '分解误差 (点)'); xlabel(ax, '固定62.5 MHz时间轴 (ms)');
legend(ax, 'reference-event', 'PLL自身', 'Location', 'best'); grid(ax, 'on');

savefig(fig, fullfile(figureDirectory, ...
    'fig16_corrected_double_peak_tracking_v2.fig'));
exportgraphics(fig, fullfile(figureDirectory, ...
    'fig16_corrected_double_peak_tracking_v2.png'), 'Resolution', 180);

disp(summaryTable);
fprintf('闭合残差最大值 %.3e 点\n', max(abs(closure2000)));

function [location, correlation] = refine_template_locations( ...
    path, location, template, searchHalf, channel, channelCount, headerBytes)
template = template(:);
template = template - mean(template);
templateHalf = (numel(template) - 1) / 2;
readHalf = templateHalf + searchHalf;
lag = (-searchHalf:searchHalf).';
correlation = zeros(size(location));
fileId = fopen(path, 'r', 'l');
for k = 1:numel(location)
    center = round(location(k));
    byteOffset = headerBytes + 2 * ...
        ((center - readHalf - 1) * channelCount + channel - 1);
    fseek(fileId, byteOffset, 'bof');
    window = fread(fileId, [2 * readHalf + 1, 1], 'uint16=>double', ...
        2 * (channelCount - 1));
    score = zeros(size(lag));
    for n = 1:numel(lag)
        first = readHalf + 1 + lag(n) - templateHalf;
        value = window(first:first + 2 * templateHalf);
        value = value - mean(value);
        score(n) = sum(value .* template) / ...
            sqrt(sum(value.^2) * sum(template.^2));
    end
    [correlation(k), index] = max(score);
    fraction = 0;
    if index > 1 && index < numel(score)
        denominator = score(index - 1) - 2 * score(index) + score(index + 1);
        fraction = 0.5 * (score(index - 1) - score(index + 1)) / denominator;
        fraction = max(-0.5, min(0.5, fraction));
    end
    location(k) = center + lag(index) + fraction;
end
fclose(fileId);
end

function value = rms0(input)
value = sqrt(mean(input(:).^2));
end
