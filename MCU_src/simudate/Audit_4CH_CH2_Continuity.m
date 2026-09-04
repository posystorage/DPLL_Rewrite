%% 四通道CH2自适应时钟连续性核查
% 流式扫描CH2正过零，仅保存载波周期异常，检查是否与CH1/CH4同步断裂。

close all;
clear;
clc;

dataDirectory = "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260809";
pciFileName = "dat5_62M5_4CH.pci";
doublePeakAuditMat = "E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/" + ...
    "MCU_src/simudate/results_4ch_tracking/dat5_62M5_4CH_20260809_230252/" + ...
    "double_peak_extraction_audit.mat";
outputDirectory = "E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/" + ...
    "MCU_src/simudate/results_4ch_tracking/dat5_62M5_4CH_20260809_230252";

sampleRateHz = 62.5e6;
channelCount = 4;
clockChannel = 2;
headerBytes = 1024;
chunkSamples = 5e6;

pciPath = fullfile(dataDirectory, pciFileName);
fileInfo = dir(pciPath);
sampleCount = (fileInfo.bytes - headerBytes) / (2 * channelCount);
saved = load(doublePeakAuditMat, 'audit');
intervals = saved.audit.intervals;
abnormal = intervals.abnormal_spacing;
clear saved

probe = read_channel(pciPath, 1, 5e6, clockChannel, channelCount, headerBytes);
if probe(1) >= 32768, probe(1) = probe(1) - 32768; end
baselineCode = median(probe);
probe = probe - baselineCode;
probeCrossing = positive_crossings(probe, 1);
probeSpacing = diff(probeCrossing);
spacingMedian = median(probeSpacing);
spacingMad = median(abs(probeSpacing - spacingMedian));
outlierThreshold = max(0.25, 20 * 1.4826 * spacingMad);
clear probe probeCrossing probeSpacing

outlierLocation = zeros(100000, 1);
outlierSpacing = zeros(100000, 1);
outlierCount = 0;
crossingCount = 0;
previousCode = NaN;
previousCrossing = NaN;

fprintf('流式扫描CH2正过零：中位周期 %.6f 点，阈值 %.6f 点\n', ...
    spacingMedian, outlierThreshold);
for firstSample = 1:chunkSamples:sampleCount
    count = min(chunkSamples, sampleCount - firstSample + 1);
    raw = read_channel(pciPath, firstSample, count, clockChannel, ...
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
    crossing = positive_crossings(centered, baseSample);
    if isfinite(previousCrossing)
        crossing = vertcat(previousCrossing, crossing);
    end
    spacing = diff(crossing);
    midpoint = 0.5 * (crossing(1:end - 1) + crossing(2:end));
    isOutlier = abs(spacing - spacingMedian) >= outlierThreshold;
    n = nnz(isOutlier);
    outlierLocation(outlierCount + (1:n)) = midpoint(isOutlier);
    outlierSpacing(outlierCount + (1:n)) = spacing(isOutlier);
    outlierCount = outlierCount + n;
    crossingCount = crossingCount + numel(crossing) - isfinite(previousCrossing);
    previousCode = centered(end);
    previousCrossing = crossing(end);

    fprintf('  %5.1f%%，累计异常 %d\n', ...
        100 * (firstSample + count - 1) / sampleCount, outlierCount);
end
outlierLocation = outlierLocation(1:outlierCount);
outlierSpacing = outlierSpacing(1:outlierCount);

intervalHasClockOutlier = false(height(intervals), 1);
maximumClockDeviation = zeros(height(intervals), 1);
for k = 1:height(intervals)
    use = outlierLocation >= intervals.start_location_raw(k) & ...
        outlierLocation <= intervals.end_location_raw(k);
    intervalHasClockOutlier(k) = any(use);
    if any(use)
        maximumClockDeviation(k) = max(abs( ...
            outlierSpacing(use) - spacingMedian));
    end
end

summary = table(crossingCount, spacingMedian, spacingMad, ...
    outlierThreshold, outlierCount, nnz(abnormal), ...
    nnz(abnormal & intervalHasClockOutlier), ...
    nnz(~abnormal & intervalHasClockOutlier), ...
    'VariableNames', {'crossing_count', 'median_spacing_samples', ...
    'spacing_mad_samples', 'outlier_threshold_samples', ...
    'crossing_outlier_count', 'abnormal_pulse_interval_count', ...
    'abnormal_pulse_intervals_with_ch2_outlier', ...
    'normal_pulse_intervals_with_ch2_outlier'});

intervalTable = table(intervals.interval, intervals.start_location_raw, ...
    intervals.end_location_raw, intervals.spacing_samples, abnormal, ...
    intervalHasClockOutlier, maximumClockDeviation, ...
    'VariableNames', {'interval', 'start_location_raw', ...
    'end_location_raw', 'pulse_spacing_samples', ...
    'abnormal_pulse_spacing', 'contains_ch2_crossing_outlier', ...
    'maximum_ch2_crossing_deviation_samples'});
outlierTable = table(outlierLocation, outlierSpacing, ...
    outlierSpacing - spacingMedian, ...
    'VariableNames', {'location_raw', 'crossing_spacing_samples', ...
    'spacing_deviation_samples'});

tableDirectory = fullfile(outputDirectory, 'tables');
figureDirectory = fullfile(outputDirectory, 'figures');
writetable(summary, fullfile(tableDirectory, ...
    'ch2_continuity_audit_summary.csv'));
writetable(intervalTable, fullfile(tableDirectory, ...
    'ch2_continuity_by_pulse_interval.csv'));
writetable(outlierTable, fullfile(tableDirectory, ...
    'ch2_crossing_outliers.csv'));

continuityAudit.schemaVersion = 1;
continuityAudit.method = 'streamed CH2 positive-crossing interval audit';
continuityAudit.summary = summary;
continuityAudit.intervalTable = intervalTable;
continuityAudit.crossingOutliers = outlierTable;
save(fullfile(outputDirectory, 'ch2_continuity_audit.mat'), ...
    'continuityAudit', '-v7.3');

timeMs = 1e3 * (intervals.start_location_raw - 1) / sampleRateHz;
fig = figure('Color', 'w', 'Name', 'CH2时间轴连续性核查', ...
    'Position', [100 100 1200 700]);
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf(['CH2正过零连续性：脉冲大间距变化%d，' ...
    '其中%d个区间含时钟载波断点'], nnz(abnormal), ...
    nnz(abnormal & intervalHasClockOutlier)));

ax = nexttile(layout);
scatter(ax, 1e3 * (outlierLocation - 1) / sampleRateHz, ...
    outlierSpacing - spacingMedian, 12, [0.82 0.12 0.12], 'filled');
ylabel(ax, 'CH2过零间距偏差 (点)'); grid(ax, 'on');

ax = nexttile(layout);
plot(ax, timeMs, maximumClockDeviation, 'Color', [0.00 0.35 0.78]); hold(ax, 'on');
scatter(ax, timeMs(abnormal), maximumClockDeviation(abnormal), ...
    18, [0.82 0.12 0.12], 'filled');
ylabel(ax, '区间内最大CH2偏差 (点)');
xlabel(ax, '固定62.5 MHz时间轴 (ms)'); grid(ax, 'on');
legend(ax, '全部脉冲区间', 'CH1大间距变化', 'Location', 'best');

savefig(fig, fullfile(figureDirectory, 'fig14_ch2_continuity_audit.fig'));
exportgraphics(fig, fullfile(figureDirectory, ...
    'fig14_ch2_continuity_audit.png'), 'Resolution', 180);

disp(summary);

function crossing = positive_crossings(signal, baseSample)
left = find(signal(1:end - 1) <= 0 & signal(2:end) > 0);
fraction = -signal(left) ./ (signal(left + 1) - signal(left));
crossing = baseSample - 1 + left + fraction;
end

function raw = read_channel(path, firstSample, count, channel, ...
    channelCount, headerBytes)
fileId = fopen(path, 'r', 'l');
byteOffset = headerBytes + 2 * ((firstSample - 1) * channelCount + channel - 1);
fseek(fileId, byteOffset, 'bof');
raw = fread(fileId, [count 1], 'uint16=>double', 2 * (channelCount - 1));
fclose(fileId);
end
