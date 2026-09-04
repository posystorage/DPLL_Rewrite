%% 四通道CH1双峰提取独立核查
% 不使用周期预测，也不使用CH2/CH3/CH4；只按CH1正负事件及双峰内间隔配对。

close all;
clear;
clc;

dataDirectory = "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260809";
pciFileName = "dat5_62M5_4CH.pci";
analysisMat = fullfile(dataDirectory, "results_4ch_tracking", ...
    "dat5_62M5_4CH_20260809_230252", ...
    "four_channel_tracking_analysis.mat");
outputDirectory = "E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/MCU_src/simudate/" + ...
    "results_4ch_tracking/dat5_62M5_4CH_20260809_230252";

sampleRateHz = 62.5e6;
channelCount = 4;
channelIndex = 1;
headerBytes = 1024;
chunkSamples = 5e6;
overlapSamples = round(1e-3 * sampleRateHz);
mergeGapSamples = round(80e-6 * sampleRateHz);
lowEventThresholdV = 0.008;
primarySamplingThresholdV = 0.035;
pairOffsetRangeSamples = round([0.20e-3, 0.65e-3] * sampleRateHz);

pciPath = fullfile(dataDirectory, pciFileName);
saved = load(analysisMat, 'result');
oldSampling = saved.result.peaks.samplingLocation(:);
oldInteraction = saved.result.peaks.interactionLocation(:);
targetPairOffset = median(oldSampling - oldInteraction);
clear saved

fileInfo = dir(pciPath);
sampleCount = (fileInfo.bytes - headerBytes) / (2 * channelCount);
probe = read_channel(pciPath, 1, 1e6, channelIndex, channelCount, headerBytes);
if probe(1) >= 32768, probe(1) = probe(1) - 32768; end
baselineCode = median(probe);
clear probe

positiveLocation = zeros(0, 1);
positiveAmplitude = zeros(0, 1);
negativeLocation = zeros(0, 1);
negativeAmplitude = zeros(0, 1);
stepSamples = chunkSamples - overlapSamples;

fprintf('独立扫描CH1正负事件：%s\n', pciPath);
for firstSample = 1:stepSamples:sampleCount
    count = min(chunkSamples, sampleCount - firstSample + 1);
    raw = read_channel(pciPath, firstSample, count, channelIndex, ...
        channelCount, headerBytes);
    if firstSample == 1 && raw(1) >= 32768, raw(1) = raw(1) - 32768; end
    volts = (raw - baselineCode) / 8192;
    clear raw

    [posLocal, posAmp] = threshold_extrema(volts, ...
        volts >= lowEventThresholdV, 1);
    [negLocal, negAmp] = threshold_extrema(volts, ...
        volts <= -lowEventThresholdV, -1);

    coreLast = firstSample + count - 1;
    if coreLast < sampleCount, coreLast = firstSample + stepSamples - 1; end
    posGlobal = firstSample - 1 + posLocal;
    negGlobal = firstSample - 1 + negLocal;
    keep = posGlobal >= firstSample & posGlobal <= coreLast;
    positiveLocation = [positiveLocation; posGlobal(keep)]; %#ok<AGROW>
    positiveAmplitude = [positiveAmplitude; posAmp(keep)]; %#ok<AGROW>
    keep = negGlobal >= firstSample & negGlobal <= coreLast;
    negativeLocation = [negativeLocation; negGlobal(keep)]; %#ok<AGROW>
    negativeAmplitude = [negativeAmplitude; negAmp(keep)]; %#ok<AGROW>

    fprintf('  %5.1f%%\n', 100 * min(coreLast, sampleCount) / sampleCount);
end

[positiveLocation, positiveAmplitude] = merge_events( ...
    positiveLocation, positiveAmplitude, mergeGapSamples);
[negativeLocation, negativeAmplitude] = merge_events( ...
    negativeLocation, negativeAmplitude, mergeGapSamples);

[positiveIndex, pairOffset] = pair_double_peaks(positiveLocation, ...
    negativeLocation, targetPairOffset, pairOffsetRangeSamples);
paired = positiveIndex > 0;
primary = paired & negativeAmplitude >= primarySamplingThresholdV;
weakPaired = paired & negativeAmplitude < primarySamplingThresholdV;

samplingLocation = negativeLocation(primary);
samplingAmplitude = negativeAmplitude(primary);
interactionLocation = positiveLocation(positiveIndex(primary));
interactionAmplitude = positiveAmplitude(positiveIndex(primary));
doublePeakSeparation = pairOffset(primary);

[nearestOldIndex, oldDifference] = nearest_sorted(oldSampling, samplingLocation);
spacing = diff(samplingLocation);
spacingMedian = median(spacing);
spacingAbnormal = abs(spacing - spacingMedian) >= 1000;

summary = table(numel(positiveLocation), numel(negativeLocation), ...
    nnz(paired), nnz(primary), nnz(weakPaired), numel(oldSampling), ...
    max(abs(oldDifference)), median(abs(oldDifference)), ...
    nnz(spacingAbnormal), spacingMedian, ...
    'VariableNames', {'positive_candidate_count', ...
    'negative_candidate_count', 'paired_candidate_count', ...
    'primary_pair_count', 'weak_paired_count', 'old_sampling_count', ...
    'maximum_old_location_difference_samples', ...
    'median_old_location_difference_samples', ...
    'abnormal_spacing_count', 'median_spacing_samples'});

pairTable = table((1:numel(samplingLocation)).', samplingLocation, ...
    samplingAmplitude, interactionLocation, interactionAmplitude, ...
    doublePeakSeparation, nearestOldIndex, oldDifference, ...
    'VariableNames', {'event', 'sampling_location_raw', ...
    'sampling_amplitude_v', 'interaction_location_raw', ...
    'interaction_amplitude_v', 'double_peak_separation_samples', ...
    'nearest_old_event', 'old_location_difference_samples'});
intervalTable = table((1:numel(spacing)).', samplingLocation(1:end-1), ...
    samplingLocation(2:end), spacing, spacingAbnormal, ...
    'VariableNames', {'interval', 'start_location_raw', ...
    'end_location_raw', 'spacing_samples', 'abnormal_spacing'});
weakTable = table(negativeLocation(weakPaired), ...
    negativeAmplitude(weakPaired), ...
    positiveLocation(positiveIndex(weakPaired)), pairOffset(weakPaired), ...
    'VariableNames', {'negative_location_raw', 'negative_amplitude_v', ...
    'positive_location_raw', 'double_peak_separation_samples'});

figureDirectory = fullfile(outputDirectory, 'figures');
tableDirectory = fullfile(outputDirectory, 'tables');
writetable(summary, fullfile(tableDirectory, ...
    'double_peak_extraction_audit_summary.csv'));
writetable(pairTable, fullfile(tableDirectory, ...
    'double_peak_extraction_pairs.csv'));
writetable(intervalTable, fullfile(tableDirectory, ...
    'double_peak_extraction_intervals.csv'));
writetable(weakTable, fullfile(tableDirectory, ...
    'double_peak_extraction_weak_pairs.csv'));

audit.schemaVersion = 1;
audit.method = ['CH1-only low-threshold positive/negative event detection; ' ...
    'no period prediction; causal order-independent double-peak pairing'];
audit.summary = summary;
audit.pairs = pairTable;
audit.intervals = intervalTable;
audit.weakPairs = weakTable;
audit.positiveCandidateLocation = positiveLocation;
audit.positiveCandidateAmplitude = positiveAmplitude;
audit.negativeCandidateLocation = negativeLocation;
audit.negativeCandidateAmplitude = negativeAmplitude;
save(fullfile(outputDirectory, 'double_peak_extraction_audit.mat'), ...
    'audit', '-v7.3');

timeMs = 1e3 * (samplingLocation(1:end-1) - 1) / sampleRateHz;
fig = figure('Color', 'w', 'Name', 'CH1双峰提取独立核查', ...
    'Position', [100 100 1200 850]);
layout = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf(['CH1无周期预测双峰提取：主峰%d，低幅完整双峰%d，' ...
    '旧结果最大位置差%.2f点'], nnz(primary), nnz(weakPaired), ...
    max(abs(oldDifference))));

ax = nexttile(layout);
plot(ax, timeMs, spacing - spacingMedian, 'k-'); hold(ax, 'on');
scatter(ax, timeMs(spacingAbnormal), ...
    spacing(spacingAbnormal) - spacingMedian, 18, [0.82 0.12 0.12], 'filled');
ylabel(ax, '相邻主峰间距偏差 (点)'); grid(ax, 'on');
legend(ax, '全部双峰配对', '大间距变化', 'Location', 'best');

ax = nexttile(layout);
plot(ax, 1e3 * (samplingLocation - 1) / sampleRateHz, ...
    samplingAmplitude, 'Color', [0.82 0.12 0.12]); hold(ax, 'on');
plot(ax, 1e3 * (samplingLocation - 1) / sampleRateHz, ...
    interactionAmplitude, 'Color', [0.92 0.48 0.08]);
ylabel(ax, '峰幅度 (V)'); grid(ax, 'on');
legend(ax, '负向主采样峰', '正向相互作用峰', 'Location', 'best');

ax = nexttile(layout);
plot(ax, 1e3 * (samplingLocation - 1) / sampleRateHz, ...
    doublePeakSeparation, 'Color', [0.00 0.35 0.78]);
ylabel(ax, '双峰内间隔 (点)');
xlabel(ax, '固定62.5 MHz时间轴 (ms)'); grid(ax, 'on');

savefig(fig, fullfile(figureDirectory, ...
    'fig11_double_peak_extraction_audit.fig'));
exportgraphics(fig, fullfile(figureDirectory, ...
    'fig11_double_peak_extraction_audit.png'), 'Resolution', 180);

disp(summary);
fprintf('低幅但双峰关系完整的额外主峰：%d\n', nnz(weakPaired));

function raw = read_channel(path, firstSample, count, channel, ...
    channelCount, headerBytes)
fileId = fopen(path, 'r', 'l');
byteOffset = headerBytes + 2 * ((firstSample - 1) * channelCount + channel - 1);
fseek(fileId, byteOffset, 'bof');
raw = fread(fileId, [count 1], 'uint16=>double', 2 * (channelCount - 1));
fclose(fileId);
end

function [location, amplitude] = threshold_extrema(signal, mask, polarity)
index = find(mask);
breaks = [0; find(diff(index) > 1); numel(index)];
location = zeros(numel(breaks) - 1, 1);
amplitude = zeros(size(location));
for k = 1:numel(location)
    region = index(breaks(k) + 1:breaks(k + 1));
    [amplitude(k), position] = max(polarity * signal(region));
    location(k) = region(position);
end
end

function [location, amplitude] = merge_events(location, amplitude, gap)
[location, order] = sort(location);
amplitude = amplitude(order);
mergedLocation = location(1);
mergedAmplitude = amplitude(1);
for k = 2:numel(location)
    if location(k) - mergedLocation(end) <= gap
        if amplitude(k) > mergedAmplitude(end)
            mergedLocation(end) = location(k);
            mergedAmplitude(end) = amplitude(k);
        end
    else
        mergedLocation(end + 1, 1) = location(k); %#ok<AGROW>
        mergedAmplitude(end + 1, 1) = amplitude(k); %#ok<AGROW>
    end
end
location = mergedLocation;
amplitude = mergedAmplitude;
end

function [positiveIndex, offset] = pair_double_peaks(positiveLocation, ...
    negativeLocation, targetOffset, offsetRange)
positiveIndex = zeros(size(negativeLocation));
offset = nan(size(negativeLocation));
for k = 1:numel(negativeLocation)
    distance = negativeLocation(k) - positiveLocation;
    candidate = find(distance >= offsetRange(1) & distance <= offsetRange(2));
    if isempty(candidate), continue; end
    [~, nearest] = min(abs(distance(candidate) - targetOffset));
    positiveIndex(k) = candidate(nearest);
    offset(k) = distance(candidate(nearest));
end
end

function [nearestIndex, difference] = nearest_sorted(reference, query)
nearestIndex = zeros(size(query));
difference = zeros(size(query));
for k = 1:numel(query)
    [~, nearestIndex(k)] = min(abs(reference - query(k)));
    difference(k) = query(k) - reference(nearestIndex(k));
end
end
