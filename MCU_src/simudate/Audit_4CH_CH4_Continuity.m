%% 四通道CH4采集时间轴连续性核查
% 用CH4原始正弦的逐周期正过零间距检查PCI时间轴是否发生拼接跳变。

close all;
clear;
clc;

dataDirectory = "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260809";
pciFileName = "dat5_62M5_4CH.pci";
auditMat = "E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/MCU_src/simudate/" + ...
    "results_4ch_tracking/dat5_62M5_4CH_20260809_230252/" + ...
    "double_peak_extraction_audit.mat";
outputDirectory = "E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/MCU_src/simudate/" + ...
    "results_4ch_tracking/dat5_62M5_4CH_20260809_230252";

sampleRateHz = 62.5e6;
channelCount = 4;
referenceChannel = 4;
headerBytes = 1024;
chunkSamples = 5e6;

pciPath = fullfile(dataDirectory, pciFileName);
fileInfo = dir(pciPath);
sampleCount = (fileInfo.bytes - headerBytes) / (2 * channelCount);
saved = load(auditMat, 'audit');
intervals = saved.audit.intervals;
abnormal = intervals.abnormal_spacing;
clear saved
probe = read_channel(pciPath, 1, 1e6, referenceChannel, ...
    channelCount, headerBytes);
if probe(1) >= 32768, probe(1) = probe(1) - 32768; end
baselineCode = median(probe);
clear probe

crossingLocation = zeros(300000, 1);
crossingCount = 0;
previousCode = NaN;

fprintf('扫描CH4原始正过零：%s\n', pciPath);
for firstSample = 1:chunkSamples:sampleCount
    count = min(chunkSamples, sampleCount - firstSample + 1);
    raw = read_channel(pciPath, firstSample, count, referenceChannel, ...
        channelCount, headerBytes);
    if firstSample == 1 && raw(1) >= 32768, raw(1) = raw(1) - 32768; end
    centered = raw - baselineCode;
    clear raw

    if firstSample > 1
        centered = vertcat(previousCode, centered);
        baseSample = firstSample - 1;
    else
        baseSample = firstSample;
    end
    left = find(centered(1:end - 1) <= 0 & centered(2:end) > 0);
    fraction = -centered(left) ./ (centered(left + 1) - centered(left));
    location = baseSample - 1 + left + fraction;
    n = numel(location);
    crossingLocation(crossingCount + (1:n)) = location;
    crossingCount = crossingCount + n;
    previousCode = centered(end);

    fprintf('  %5.1f%%\n', 100 * (firstSample + count - 1) / sampleCount);
end
crossingLocation = crossingLocation(1:crossingCount);

crossingSpacing = diff(crossingLocation);
spacingMedian = median(crossingSpacing);
spacingMad = median(abs(crossingSpacing - spacingMedian));
outlierThreshold = max(20, 20 * 1.4826 * spacingMad);
crossingOutlier = abs(crossingSpacing - spacingMedian) >= outlierThreshold;
outlierTime = 0.5 * (crossingLocation(1:end - 1) + ...
    crossingLocation(2:end));

intervalHasCrossingOutlier = false(height(intervals), 1);
maximumCrossingDeviation = zeros(height(intervals), 1);
for k = 1:height(intervals)
    use = outlierTime >= intervals.start_location_raw(k) & ...
        outlierTime <= intervals.end_location_raw(k);
    intervalHasCrossingOutlier(k) = any(crossingOutlier & use);
    inside = crossingSpacing(use);
    maximumCrossingDeviation(k) = max(abs(inside - spacingMedian));
end

summary = table(crossingCount, spacingMedian, spacingMad, ...
    outlierThreshold, nnz(crossingOutlier), nnz(abnormal), ...
    nnz(abnormal & intervalHasCrossingOutlier), ...
    nnz(~abnormal & intervalHasCrossingOutlier), ...
    'VariableNames', {'crossing_count', 'median_spacing_samples', ...
    'spacing_mad_samples', 'outlier_threshold_samples', ...
    'crossing_outlier_count', 'abnormal_pulse_interval_count', ...
    'abnormal_pulse_intervals_with_ch4_outlier', ...
    'normal_pulse_intervals_with_ch4_outlier'});

intervalTable = table(intervals.interval, intervals.start_location_raw, ...
    intervals.end_location_raw, intervals.spacing_samples, abnormal, ...
    intervalHasCrossingOutlier, maximumCrossingDeviation, ...
    'VariableNames', {'interval', 'start_location_raw', ...
    'end_location_raw', 'pulse_spacing_samples', ...
    'abnormal_pulse_spacing', 'contains_ch4_crossing_outlier', ...
    'maximum_ch4_crossing_deviation_samples'});
crossingTable = table(outlierTime(crossingOutlier), ...
    crossingSpacing(crossingOutlier), ...
    crossingSpacing(crossingOutlier) - spacingMedian, ...
    'VariableNames', {'location_raw', 'crossing_spacing_samples', ...
    'spacing_deviation_samples'});

tableDirectory = fullfile(outputDirectory, 'tables');
figureDirectory = fullfile(outputDirectory, 'figures');
writetable(summary, fullfile(tableDirectory, ...
    'ch4_continuity_audit_summary.csv'));
writetable(intervalTable, fullfile(tableDirectory, ...
    'ch4_continuity_by_pulse_interval.csv'));
writetable(crossingTable, fullfile(tableDirectory, ...
    'ch4_crossing_outliers.csv'));

continuityAudit.schemaVersion = 1;
continuityAudit.summary = summary;
continuityAudit.intervalTable = intervalTable;
continuityAudit.crossingOutliers = crossingTable;
save(fullfile(outputDirectory, 'ch4_continuity_audit.mat'), ...
    'continuityAudit', '-v7.3');

timeMs = 1e3 * (intervals.start_location_raw - 1) / sampleRateHz;
fig = figure('Color', 'w', 'Name', 'CH4时间轴连续性核查', ...
    'Position', [100 100 1200 700]);
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('CH4正过零连续性：脉冲异常%d，其中%d个区间含CH4断点', ...
    nnz(abnormal), nnz(abnormal & intervalHasCrossingOutlier)));

ax = nexttile(layout);
plot(ax, 1e3 * (outlierTime - 1) / sampleRateHz, ...
    crossingSpacing - spacingMedian, 'Color', [0.25 0.25 0.25]); hold(ax, 'on');
scatter(ax, 1e3 * (outlierTime(crossingOutlier) - 1) / sampleRateHz, ...
    crossingSpacing(crossingOutlier) - spacingMedian, 18, ...
    [0.82 0.12 0.12], 'filled');
ylabel(ax, 'CH4过零间距偏差 (点)'); grid(ax, 'on');

ax = nexttile(layout);
plot(ax, timeMs, maximumCrossingDeviation, 'Color', [0.00 0.35 0.78]); hold(ax, 'on');
scatter(ax, timeMs(abnormal), maximumCrossingDeviation(abnormal), ...
    18, [0.82 0.12 0.12], 'filled');
ylabel(ax, '区间内最大CH4偏差 (点)');
xlabel(ax, '固定62.5 MHz时间轴 (ms)'); grid(ax, 'on');
legend(ax, '全部脉冲区间', 'CH1大间距变化', 'Location', 'best');

savefig(fig, fullfile(figureDirectory, 'fig12_ch4_continuity_audit.fig'));
exportgraphics(fig, fullfile(figureDirectory, ...
    'fig12_ch4_continuity_audit.png'), 'Resolution', 180);

disp(summary);

function raw = read_channel(path, firstSample, count, channel, ...
    channelCount, headerBytes)
fileId = fopen(path, 'r', 'l');
byteOffset = headerBytes + 2 * ((firstSample - 1) * channelCount + channel - 1);
fseek(fileId, byteOffset, 'bof');
raw = fread(fileId, [count 1], 'uint16=>double', 2 * (channelCount - 1));
fclose(fileId);
end
