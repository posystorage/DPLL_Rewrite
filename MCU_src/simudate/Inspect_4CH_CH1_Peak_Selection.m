%% CH1双峰找峰局部证据检查
% 找峰始终从文件第1点处理到末尾；下面的起止点只控制图像显示范围。

close all;
clear;
clc;

%% 用户配置区
dataDirectory = ...
    "E:/JiangSiyi/THz器件采样/光源稳定性分析/20260809";
pciFileName = "dat2_62M5_4CH.pci";
displayStartRawSample = 20000000;
displayEndRawSample = inf;

sampleRateHz = 62.5e6;
channelCount = 4;
pulseChannel = 1;
headerBytes = 1024;
referenceCyclesPerPulse = 113;
nominalReferenceHz = 23.7e3;

samplingPeakMinimumVolts = 0.035;
doublePeakEventMinimumVolts = 0.008;
doublePeakEventMergeSeconds = 25e-6;
doublePeakPairToleranceSeconds = 80e-6;
samplingTemplateMinimumCorrelation = 0.50;
samplingTemplateRefineHalfSamples = 64;
samplingTemplateHalfSamples = 200;
interactionBeforeRangeSeconds = [0.20e-3, 0.65e-3];
spacingOutlierSamples = 1000;

outputParentDirectory = fullfile(fileparts(mfilename('fullpath')), ...
    "results_4ch_peak_inspection");
showFigures = true;
%% 用户配置区结束

pciPath = fullfile(dataDirectory, pciFileName);
fileInfo = dir(pciPath);
sampleCount = (fileInfo.bytes - headerBytes) / (2 * channelCount);
displayFirst = max(1, displayStartRawSample);
displayLast = min(sampleCount, displayEndRawSample);
[~, datasetName] = fileparts(pciPath);
tag = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outputDirectory = fullfile(outputParentDirectory, datasetName + "_" + tag);
figureDirectory = fullfile(outputDirectory, "figures");
tableDirectory = fullfile(outputDirectory, "tables");
mkdir(figureDirectory);
mkdir(tableDirectory);

fprintf('\n=== CH1双峰找峰局部证据检查 ===\n');
fprintf('文件：%s\n', pciPath);
fprintf('完整找峰范围：1 .. %d\n', sampleCount);
fprintf('图像显示范围：%d .. %d（%.3f .. %.3f ms）\n', ...
    displayFirst, displayLast, 1e3 * (displayFirst - 1) / sampleRateHz, ...
    1e3 * (displayLast - 1) / sampleRateHz);

raw = read_pci_channel(pciPath, pulseChannel, sampleCount, ...
    channelCount, headerBytes);
signal = (raw - 8192) / 8192;
signal = signal - median(signal);
clear raw

config.sampleRateHz = sampleRateHz;
config.referenceCyclesPerPulse = referenceCyclesPerPulse;
config.nominalReferenceHz = nominalReferenceHz;
config.samplingPeakMinimumVolts = samplingPeakMinimumVolts;
config.doublePeakEventMinimumVolts = doublePeakEventMinimumVolts;
config.doublePeakEventMergeSeconds = doublePeakEventMergeSeconds;
config.doublePeakPairToleranceSeconds = doublePeakPairToleranceSeconds;
config.samplingTemplateMinimumCorrelation = ...
    samplingTemplateMinimumCorrelation;
config.samplingTemplateRefineHalfSamples = ...
    samplingTemplateRefineHalfSamples;
config.samplingTemplateHalfSamples = samplingTemplateHalfSamples;
config.interactionBeforeRangeSeconds = interactionBeforeRangeSeconds;

[peaks, candidate] = locate_double_peaks_with_evidence(signal, config);

bootstrapSelected = false(size(candidate.bootstrapLocation));
nearestSelectedDifference = nan(size(candidate.bootstrapLocation));
for k = 1:numel(candidate.bootstrapLocation)
    nearestSelectedDifference(k) = min(abs(peaks.samplingLocation - ...
        candidate.bootstrapLocation(k)));
    bootstrapSelected(k) = nearestSelectedDifference(k) <= ...
        samplingTemplateRefineHalfSamples + 2;
end
omittedBootstrap = candidate.bootstrapLocation(~bootstrapSelected);
omittedAmplitude = candidate.bootstrapAmplitude(~bootstrapSelected);
preliminarySpacingMedian = median(diff(peaks.samplingLocation));
expectedMacroDistance = distance_to_expected_macro_slot( ...
    candidate.bootstrapLocation, peaks.samplingLocation, ...
    preliminarySpacingMedian);
macroSlotToleranceSamples = round(0.03 * preliminarySpacingMedian);
nearExpectedMacroSlot = expectedMacroDistance <= ...
    macroSlotToleranceSamples;

nearestNegativeIndex = zeros(size(candidate.bootstrapLocation));
for k = 1:numel(candidate.bootstrapLocation)
    [~, nearestNegativeIndex(k)] = min(abs(candidate.negativeLocation - ...
        candidate.bootstrapLocation(k)));
end
nearestNegativeAmplitude = ...
    candidate.negativeAmplitude(nearestNegativeIndex);
nearestNegativeCorrelation = ...
    candidate.negativeCorrelation(nearestNegativeIndex);
nearestNegativePaired = ...
    candidate.negativePairIndex(nearestNegativeIndex) > 0;

bootstrapTable = table((1:numel(candidate.bootstrapLocation)).', ...
    candidate.bootstrapLocation, candidate.bootstrapAmplitude, ...
    bootstrapSelected, nearestSelectedDifference, ...
    nearestNegativeAmplitude, nearestNegativeCorrelation, ...
    nearestNegativePaired, expectedMacroDistance, nearExpectedMacroSlot, ...
    'VariableNames', {'bootstrap_event', 'location_raw', ...
    'negative_amplitude_v', 'selected_by_double_peak', ...
    'nearest_selected_difference_samples', ...
    'merged_negative_amplitude_v', 'sampling_template_correlation', ...
    'has_positive_interaction_pair', ...
    'distance_to_expected_macro_slot_samples', ...
    'near_expected_macro_slot'});

spacing = diff(peaks.samplingLocation);
spacingMedian = median(spacing);
spacingOutlier = abs(spacing - spacingMedian) >= spacingOutlierSamples;
selectedTable = table((1:numel(peaks.samplingLocation)).', ...
    peaks.samplingLocation, peaks.interactionLocation, ...
    peaks.separationSamples, peaks.samplingCorrelation, ...
    peaks.interactionCorrelation, ...
    'VariableNames', {'event', 'sampling_location_raw', ...
    'interaction_location_raw', 'double_peak_separation_samples', ...
    'sampling_template_correlation', ...
    'interaction_template_correlation'});
intervalTable = table((1:numel(spacing)).', ...
    peaks.samplingLocation(1:end - 1), peaks.samplingLocation(2:end), ...
    spacing, spacing - spacingMedian, spacingOutlier, ...
    'VariableNames', {'interval', 'start_location_raw', ...
    'end_location_raw', 'spacing_samples', ...
    'spacing_deviation_samples', 'spacing_outlier'});

summaryTable = table(numel(candidate.bootstrapLocation), ...
    numel(peaks.samplingLocation), nnz(~bootstrapSelected), ...
    nnz(~bootstrapSelected & nearExpectedMacroSlot), ...
    nnz(~bootstrapSelected & nearestNegativePaired), ...
    nnz(~bootstrapSelected & ~nearestNegativePaired), ...
    spacingMedian, nnz(spacingOutlier), ...
    median(peaks.separationSamples), ...
    min(peaks.samplingCorrelation), ...
    'VariableNames', {'strong_negative_peak_count', ...
    'selected_complete_double_peak_count', ...
    'omitted_strong_negative_peak_count', ...
    'omitted_near_expected_macro_slot_count', ...
    'omitted_with_positive_pair_count', ...
    'omitted_without_positive_pair_count', ...
    'selected_spacing_median_samples', 'selected_spacing_outlier_count', ...
    'double_peak_separation_median_samples', ...
    'sampling_correlation_minimum'});

writetable(bootstrapTable, fullfile(tableDirectory, ...
    'bootstrap_strong_negative_events.csv'));
writetable(selectedTable, fullfile(tableDirectory, ...
    'selected_double_peak_events.csv'));
writetable(intervalTable, fullfile(tableDirectory, ...
    'selected_peak_intervals.csv'));
writetable(summaryTable, fullfile(tableDirectory, 'summary.csv'));

%% 图1：指定范围总览
visible = figure_visibility(showFigures);
fig = figure('Color', 'w', 'Visible', visible, ...
    'Name', 'CH1找峰证据总览', 'Position', [80 80 1500 950]);
layout = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf(['%s：完整记录找峰，仅显示原始点 %d–%d；' ...
    '强负峰%d，完整双峰%d，漏选强负峰%d'], datasetName, ...
    displayFirst, displayLast, numel(candidate.bootstrapLocation), ...
    numel(peaks.samplingLocation), nnz(~bootstrapSelected)), ...
    'Interpreter', 'none');

ax = nexttile(layout);
[envelopeX, envelopeY] = minmax_envelope(signal, displayFirst, ...
    displayLast, 300000);
plot(ax, envelopeX, envelopeY, 'Color', [0.25 0.45 0.78]); hold(ax, 'on');
use = peaks.samplingLocation >= displayFirst & ...
    peaks.samplingLocation <= displayLast;
scatter(ax, peaks.samplingLocation(use), ...
    signal(round(peaks.samplingLocation(use))), 30, ...
    [0.82 0.12 0.12], 'v', 'filled');
useInteraction = peaks.interactionLocation >= displayFirst & ...
    peaks.interactionLocation <= displayLast;
scatter(ax, peaks.interactionLocation(useInteraction), ...
    signal(round(peaks.interactionLocation(useInteraction))), ...
    24, [0.92 0.48 0.08], '^', 'filled');
useOmitted = omittedBootstrap >= displayFirst & ...
    omittedBootstrap <= displayLast;
scatter(ax, omittedBootstrap(useOmitted), -omittedAmplitude(useOmitted), ...
    52, [0.62 0.12 0.72], 'x', 'LineWidth', 1.5);
ylabel(ax, 'CH1电压 (V)');
legend(ax, '原始CH1最小/最大包络', '最终主采样峰', ...
    '配对相互作用峰', '漏选的强负峰', 'Location', 'best');
grid(ax, 'on'); xlim(ax, [displayFirst displayLast]);

ax = nexttile(layout);
intervalMid = 0.5 * (peaks.samplingLocation(1:end - 1) + ...
    peaks.samplingLocation(2:end));
plot(ax, intervalMid, spacing - spacingMedian, 'k-', ...
    'LineWidth', 1.0); hold(ax, 'on');
bootstrapSpacing = diff(candidate.bootstrapLocation);
bootstrapMedian = median(bootstrapSpacing);
bootstrapMid = 0.5 * (candidate.bootstrapLocation(1:end - 1) + ...
    candidate.bootstrapLocation(2:end));
plot(ax, bootstrapMid, bootstrapSpacing - bootstrapMedian, ...
    'Color', [0.00 0.35 0.78], 'LineWidth', 1.0);
scatter(ax, intervalMid(spacingOutlier), ...
    spacing(spacingOutlier) - spacingMedian, 28, ...
    [0.82 0.12 0.12], 'filled');
ylabel(ax, '相邻峰间距偏差 (点)');
legend(ax, '完整双峰严格结果', '仅强负峰基线', ...
    '严格结果大间距', 'Location', 'best');
grid(ax, 'on'); xlim(ax, [displayFirst displayLast]);

ax = nexttile(layout);
yyaxis(ax, 'left');
plot(ax, peaks.samplingLocation, peaks.samplingCorrelation, ...
    'Color', [0.12 0.48 0.20], 'LineWidth', 1.0);
ylabel(ax, '主峰模板相关'); ylim(ax, [0 1.05]);
yyaxis(ax, 'right');
plot(ax, peaks.samplingLocation, peaks.separationSamples, ...
    'Color', [0.76 0.18 0.12], 'LineWidth', 1.0);
ylabel(ax, '双峰内间隔 (点)');
xlabel(ax, '原始62.5 MHz样点');
grid(ax, 'on'); xlim(ax, [displayFirst displayLast]);
save_figure(fig, figureDirectory, 'fig01_ch1_peak_selection_overview');

%% 图2：显示范围内第一个大间距的原始波形证据
bad = find(spacingOutlier & intervalMid >= displayFirst & ...
    intervalMid <= displayLast, 1);
if isempty(bad)
    inside = find(intervalMid >= displayFirst & intervalMid <= displayLast);
    [~, maximumIndex] = max(abs(spacing(inside) - spacingMedian));
    bad = inside(maximumIndex);
end
zoomFirst = max(1, round(peaks.samplingLocation(bad) - 0.7e-3 * sampleRateHz));
zoomLast = min(sampleCount, round(peaks.samplingLocation(bad + 1) + ...
    0.7e-3 * sampleRateHz));
fig = figure('Color', 'w', 'Visible', visible, ...
    'Name', '大间距原始波形证据', 'Position', [80 80 1500 720]);
[zoomX, zoomY] = minmax_envelope(signal, zoomFirst, zoomLast, 300000);
plot(zoomX, zoomY, 'Color', [0.25 0.45 0.78]); hold on;
use = peaks.samplingLocation >= zoomFirst & peaks.samplingLocation <= zoomLast;
scatter(peaks.samplingLocation(use), ...
    signal(round(peaks.samplingLocation(use))), ...
    42, [0.82 0.12 0.12], 'v', 'filled');
useInteraction = peaks.interactionLocation >= zoomFirst & ...
    peaks.interactionLocation <= zoomLast;
scatter(peaks.interactionLocation(useInteraction), ...
    signal(round(peaks.interactionLocation(useInteraction))), ...
    38, [0.92 0.48 0.08], '^', 'filled');
useOmitted = omittedBootstrap >= zoomFirst & omittedBootstrap <= zoomLast;
scatter(omittedBootstrap(useOmitted), -omittedAmplitude(useOmitted), ...
    72, [0.62 0.12 0.72], 'x', 'LineWidth', 1.8);
xlabel('原始62.5 MHz样点'); ylabel('CH1电压 (V)'); grid on;
title(sprintf(['第%d个严格区间：间距 %.1f点（中位数 %.1f点）；' ...
    '紫叉为仍存在但因双峰条件未入选的强负峰'], ...
    bad, spacing(bad), spacingMedian));
legend('原始CH1最小/最大包络', '最终主采样峰', ...
    '配对相互作用峰', '漏选的强负峰', 'Location', 'best');
save_figure(fig, figureDirectory, 'fig02_first_bad_interval_raw_evidence');

%% 图3：逐个放大显示范围内漏选的强负峰
omittedInDisplay = find(omittedBootstrap >= displayFirst & ...
    omittedBootstrap <= displayLast);
fig = figure('Color', 'w', 'Visible', visible, ...
    'Name', '漏选强负峰逐个放大', 'Position', [80 80 1500 950]);
rowCount = max(1, ceil(numel(omittedInDisplay) / 3));
layout = tiledlayout(rowCount, 3, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, sprintf('%s：漏选强负峰局部原始波形', datasetName), ...
    'Interpreter', 'none');
for n = 1:numel(omittedInDisplay)
    k = omittedInDisplay(n);
    center = round(omittedBootstrap(k));
    first = center - round(0.7e-3 * sampleRateHz);
    last = center + round(0.7e-3 * sampleRateHz);
    index = (first:last).';
    ax = nexttile(layout);
    plot(ax, index, signal(index), 'Color', [0.25 0.45 0.78]); hold(ax, 'on');
    scatter(ax, center, signal(center), 56, [0.62 0.12 0.72], ...
        'x', 'LineWidth', 1.6);
    expectedInteraction = center - candidate.targetPairOffset;
    xline(ax, expectedInteraction, '--', '期望正峰位置');
    positiveUse = candidate.positiveLocation >= first & ...
        candidate.positiveLocation <= last;
    scatter(ax, candidate.positiveLocation(positiveUse), ...
        candidate.positiveAmplitude(positiveUse), 22, ...
        [0.92 0.48 0.08], '^', 'filled');
    bootstrapIndex = find(candidate.bootstrapLocation == ...
        omittedBootstrap(k));
    title(ax, sprintf(['原始点%d；正峰配对=%d；' ...
        '距应有宏周期%.0f点'], center, ...
        nearestNegativePaired(bootstrapIndex), ...
        expectedMacroDistance(bootstrapIndex)));
    xlabel(ax, '原始样点'); ylabel(ax, 'CH1 (V)'); grid(ax, 'on');
end
if isempty(omittedInDisplay)
    ax = nexttile(layout, [1 3]);
    text(ax, 0.5, 0.5, '显示范围内没有漏选的强负峰', ...
        'HorizontalAlignment', 'center', 'FontSize', 16);
    axis(ax, 'off');
end
save_figure(fig, figureDirectory, 'fig03_omitted_strong_peak_closeups');

%% 图4：所有大间距内的应有宏周期位置
badInterval = find(spacingOutlier & intervalMid >= displayFirst & ...
    intervalMid <= displayLast);
fig = figure('Color', 'w', 'Visible', visible, ...
    'Name', '所有大间距宏周期位置核对', 'Position', [80 80 1500 950]);
layout = tiledlayout(max(1, numel(badInterval)), 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, ['虚线为按相邻已选主峰线性分割得到的应有宏周期位置；' ...
    '紫叉为固定模板拒绝的强负峰']);
for n = 1:numel(badInterval)
    k = badInterval(n);
    multiple = round(spacing(k) / spacingMedian);
    expected = peaks.samplingLocation(k) + spacing(k) / multiple * ...
        (1:multiple - 1).';
    first = round(peaks.samplingLocation(k) - 0.25e-3 * sampleRateHz);
    last = round(peaks.samplingLocation(k + 1) + 0.25e-3 * sampleRateHz);
    [x, y] = minmax_envelope(signal, first, last, 180000);
    ax = nexttile(layout);
    plot(ax, x, y, 'Color', [0.25 0.45 0.78]); hold(ax, 'on');
    scatter(ax, peaks.samplingLocation(k:k + 1), ...
        signal(round(peaks.samplingLocation(k:k + 1))), ...
        38, [0.82 0.12 0.12], 'v', 'filled');
    for m = 1:numel(expected)
        xline(ax, expected(m), '--', '应有周期');
    end
    use = omittedBootstrap >= first & omittedBootstrap <= last;
    scatter(ax, omittedBootstrap(use), -omittedAmplitude(use), ...
        56, [0.62 0.12 0.72], 'x', 'LineWidth', 1.6);
    ylabel(ax, 'CH1 (V)'); grid(ax, 'on');
    title(ax, sprintf('区间%d：%.2f倍中位周期，内部应有%d个主峰', ...
        k, spacing(k) / spacingMedian, multiple - 1));
end
if isempty(badInterval)
    ax = nexttile(layout);
    text(ax, 0.5, 0.5, '显示范围内没有大间距区间', ...
        'HorizontalAlignment', 'center', 'FontSize', 16);
    axis(ax, 'off');
end
xlabel(layout, '原始62.5 MHz样点');
save_figure(fig, figureDirectory, ...
    'fig04_all_bad_intervals_expected_macro_slots');

inspection.schemaVersion = 1;
inspection.pciPath = char(pciPath);
inspection.fullDetectionRange = [1 sampleCount];
inspection.displayRange = [displayFirst displayLast];
inspection.peaks = peaks;
inspection.candidate = candidate;
inspection.bootstrapTable = bootstrapTable;
inspection.selectedTable = selectedTable;
inspection.intervalTable = intervalTable;
inspection.summaryTable = summaryTable;
save(fullfile(outputDirectory, 'ch1_peak_selection_inspection.mat'), ...
    'inspection', '-v7.3');

disp(summaryTable);
fprintf('结果目录：%s\n', outputDirectory);

function raw = read_pci_channel(path, channel, sampleCount, ...
    channelCount, headerBytes)
fileId = fopen(path, 'r', 'l');
fseek(fileId, headerBytes + 2 * (channel - 1), 'bof');
raw = fread(fileId, [sampleCount 1], 'uint16=>double', ...
    2 * (channelCount - 1));
fclose(fileId);
if raw(1) >= 32768, raw(1) = raw(1) - 32768; end
end

function [peaks, candidate] = locate_double_peaks_with_evidence(signal, config)
fs = config.sampleRateHz;
nominalPeriod = fs * config.referenceCyclesPerPulse / ...
    config.nominalReferenceHz;
[bootstrapAmplitude, bootstrapLocation] = findpeaks(-signal, ...
    'MinPeakHeight', config.samplingPeakMinimumVolts, ...
    'MinPeakDistance', round(0.70 * nominalPeriod));
bootstrapTemplate = median_template(signal, bootstrapLocation, ...
    config.samplingTemplateHalfSamples);
[positiveLocation, positiveAmplitude] = threshold_extrema(signal, ...
    signal >= config.doublePeakEventMinimumVolts, 1);
[negativeLocation, negativeAmplitude] = threshold_extrema(signal, ...
    signal <= -config.doublePeakEventMinimumVolts, -1);
mergeGap = round(config.doublePeakEventMergeSeconds * fs);
[positiveLocation, positiveAmplitude] = merge_events( ...
    positiveLocation, positiveAmplitude, mergeGap);
[negativeLocation, negativeAmplitude] = merge_events( ...
    negativeLocation, negativeAmplitude, mergeGap);

templateHalf = config.samplingTemplateHalfSamples;
inside = negativeLocation > templateHalf & ...
    negativeLocation <= numel(signal) - templateHalf;
negativeLocation = negativeLocation(inside);
negativeAmplitude = negativeAmplitude(inside);
primaryNegative = negativeAmplitude >= config.samplingPeakMinimumVolts;
negativeCorrelation = template_correlation_at_locations( ...
    signal, negativeLocation, bootstrapTemplate);
firstSampling = bootstrapLocation(1);
beforeRange = round(config.interactionBeforeRangeSeconds * fs);
[~, index] = max(signal(firstSampling - beforeRange(2): ...
    firstSampling - beforeRange(1)));
firstInteraction = firstSampling - beforeRange(2) + index - 1;
targetPairOffset = firstSampling - firstInteraction;

pairTolerance = round(config.doublePeakPairToleranceSeconds * fs);
negativePairIndex = pair_double_peaks(positiveLocation, ...
    negativeLocation, targetPairOffset, pairTolerance);
selected = primaryNegative & negativePairIndex > 0 & ...
    negativeCorrelation >= config.samplingTemplateMinimumCorrelation;
samplingLocation = negativeLocation(selected);
selectedPairIndex = pair_double_peaks(positiveLocation, samplingLocation, ...
    targetPairOffset, pairTolerance);
interactionLocation = positiveLocation(selectedPairIndex);
[samplingLocation, samplingCorrelation] = refine_template_locations( ...
    signal, samplingLocation, bootstrapTemplate, ...
    config.samplingTemplateRefineHalfSamples);
samplingTemplate = median_template(signal, samplingLocation, templateHalf);
interactionTemplate = median_template(signal, interactionLocation, templateHalf);
interactionCorrelation = template_correlation_at_locations( ...
    signal, interactionLocation, interactionTemplate);

peaks.samplingLocation = samplingLocation;
peaks.interactionLocation = interactionLocation;
peaks.samplingCorrelation = samplingCorrelation;
peaks.interactionCorrelation = interactionCorrelation;
peaks.separationSamples = samplingLocation - interactionLocation;
peaks.samplingTemplate = samplingTemplate;
peaks.interactionTemplate = interactionTemplate;

candidate.bootstrapLocation = bootstrapLocation;
candidate.bootstrapAmplitude = bootstrapAmplitude;
candidate.positiveLocation = positiveLocation;
candidate.positiveAmplitude = positiveAmplitude;
candidate.negativeLocation = negativeLocation;
candidate.negativeAmplitude = negativeAmplitude;
candidate.negativeCorrelation = negativeCorrelation;
candidate.negativePairIndex = negativePairIndex;
candidate.targetPairOffset = targetPairOffset;
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

function pairIndex = pair_double_peaks(positiveLocation, negativeLocation, ...
    targetOffset, tolerance)
pairIndex = zeros(size(negativeLocation));
for k = 1:numel(negativeLocation)
    distance = negativeLocation(k) - positiveLocation;
    candidate = find(abs(distance - targetOffset) <= tolerance);
    if isempty(candidate), continue; end
    [~, nearest] = min(abs(distance(candidate) - targetOffset));
    pairIndex(k) = candidate(nearest);
end
end

function correlation = template_correlation_at_locations(signal, locations, template)
offset = (-(numel(template) - 1) / 2:(numel(template) - 1) / 2).';
correlation = zeros(size(locations));
for k = 1:numel(locations)
    value = signal(round(locations(k)) + offset);
    value = value - mean(value);
    correlation(k) = sum(value .* template) / ...
        sqrt(sum(value.^2) * sum(template.^2));
end
end

function [location, correlation] = refine_template_locations( ...
    signal, location, template, searchHalf)
template = template(:);
templateOffset = (-(numel(template) - 1) / 2: ...
    (numel(template) - 1) / 2).';
lag = (-searchHalf:searchHalf).';
correlation = zeros(size(location));
for k = 1:numel(location)
    center = round(location(k));
    score = zeros(size(lag));
    for n = 1:numel(lag)
        value = signal(center + lag(n) + templateOffset);
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
end

function template = median_template(signal, locations, halfWidth)
offset = (-halfWidth:halfWidth).';
waveform = zeros(numel(offset), numel(locations));
for k = 1:numel(locations)
    waveform(:, k) = signal(round(locations(k)) + offset);
end
template = median(waveform, 2);
template = template - mean(template);
end

function [x, y] = minmax_envelope(signal, first, last, maximumPoints)
count = last - first + 1;
block = max(1, ceil(3 * count / maximumPoints));
blockCount = floor(count / block);
value = reshape(signal(first:first + block * blockCount - 1), ...
    block, blockCount);
minimum = min(value, [], 1);
maximum = max(value, [], 1);
center = first - 1 + ((1:blockCount) - 0.5) * block;
x = reshape([center; center; nan(1, blockCount)], [], 1);
y = reshape([minimum; maximum; nan(1, blockCount)], [], 1);
end

function distance = distance_to_expected_macro_slot(location, ...
    selectedLocation, spacingMedian)
distance = nan(size(location));
for k = 1:numel(location)
    left = find(selectedLocation < location(k), 1, 'last');
    right = find(selectedLocation > location(k), 1);
    if isempty(left) || isempty(right), continue; end
    gap = selectedLocation(right) - selectedLocation(left);
    multiple = round(gap / spacingMedian);
    expected = selectedLocation(left) + gap / multiple * ...
        (1:multiple - 1).';
    if ~isempty(expected)
        distance(k) = min(abs(expected - location(k)));
    end
end
end

function visible = figure_visibility(showFigures)
if showFigures, visible = 'on'; else, visible = 'off'; end
end

function save_figure(fig, directory, name)
savefig(fig, fullfile(directory, name + ".fig"));
exportgraphics(fig, fullfile(directory, name + ".png"), ...
    'Resolution', 180);
end
