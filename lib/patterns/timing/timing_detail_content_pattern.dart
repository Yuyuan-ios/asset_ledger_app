import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/device.dart';
import '../../data/models/project_device_rate.dart';
import '../../data/models/timing_record.dart';
import '../../core/measure/measure_unit.dart';
import '../../features/timing/calculator/model/staged_timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import '../../features/timing/calculator/view/work_hour_calculator_sheet.dart';
import '../../features/timing/domain/services/timing_entry_template.dart';
import '../../components/fields/timing_time_block.dart';
import 'exclude_fuel_switch_card_pattern.dart';
import '../../tokens/mapper/bottom_sheet_tokens.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../../core/foundation/typography.dart';
import '../../core/utils/form_feedback.dart';
import '../../core/utils/interaction_feedback.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/text_field_utils.dart';
import '../../components/fields/app_auto_suggest_field.dart';
import '../../patterns/device/device_picker_pattern.dart';
import '../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../components/fields/app_date_field.dart';
import '../../components/feedback/app_toast_bubble.dart';
import '../../components/pickers/app_date_picker_dialog.dart';

part '../../features/timing/presentation/widgets/timing_detail/timing_detail_form_sections.dart';

enum WorkMode { hours, rent }

enum AttachmentMode { digging, breaking }

const _workHourCalculatorIconAsset =
    'assets/icons/timing/work_hour_calculator_icon.png';
const _timingFieldIconSize = 30.0;
const _submitFailureTipDuration = Duration(seconds: 4);

typedef TimingIncomeResolver =
    FutureOr<double> Function({
      required int deviceId,
      required String contact,
      required String site,
      required bool isBreaking,
      required double hours,
    });

typedef TimingMeterBoundsValidator =
    String? Function({
      required int deviceId,
      required int startDate,
      required double endMeter,
      int? excludeId,
    });

/// 返回指定设备当前码表读数（小时）。计算由 feature/view 层完成（一般通过
/// TimingService.currentMeter + 当前记录列表），让 pattern 层不必直接依赖
/// data/services。
typedef TimingCurrentMeterResolver = double Function(int deviceId);

typedef TimingDetailSubmitHandler =
    Future<void> Function(
      TimingRecord record,
      List<TimingCalculationHistory> calculationHistories,
    );

typedef TimingEntryTemplateResolver =
    TimingEntryTemplate Function(Device device);

class TimingDetailContent extends StatefulWidget {
  const TimingDetailContent({
    super.key,
    this.editing,
    required this.records,
    required this.activeDevices,
    required this.allDevices,
    required this.deviceById,
    required this.deviceItems,
    required this.projectRates,
    required this.contactSuggestions,
    required this.siteSuggestions,
    required this.resolveIncome,
    required this.validateMeterBounds,
    required this.resolveCurrentMeter,
    this.resolveEntryTemplate,
    this.existingCalculationHistories = const [],
    this.onCancel,
    required this.onSubmit,
    required this.onToast,
  });

  final TimingRecord? editing;
  final List<TimingRecord> records;
  final List<Device> activeDevices;
  final List<Device> allDevices;
  final Map<int, Device> deviceById;
  final List<DevicePickerItemVm> deviceItems;
  final List<ProjectDeviceRate> projectRates;
  final List<String> Function(String) contactSuggestions;
  final List<String> Function(String) siteSuggestions;
  final TimingIncomeResolver resolveIncome;
  final TimingMeterBoundsValidator validateMeterBounds;
  final TimingCurrentMeterResolver resolveCurrentMeter;
  final TimingEntryTemplateResolver? resolveEntryTemplate;
  final List<TimingCalculationHistory> existingCalculationHistories;
  final VoidCallback? onCancel;
  final TimingDetailSubmitHandler onSubmit;
  final void Function(String msg) onToast;

  @override
  State<TimingDetailContent> createState() => TimingDetailContentState();
}

class TimingDetailContentState extends State<TimingDetailContent> {
  final _contactCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _startMeterCtrl = TextEditingController(text: '0.0');
  final _endMeterCtrl = TextEditingController(text: '0.0');
  final _hoursCtrl = TextEditingController(text: '0.0');
  final _incomeCtrl = TextEditingController(text: '0.0');

  final _contactFocus = FocusNode();
  final _siteFocus = FocusNode();

  int? _selectedDeviceId;
  late DateTime _selectedDate;
  DateTime? _selectedEndDate;
  WorkMode _mode = WorkMode.hours;
  AttachmentMode _attachmentMode = AttachmentMode.digging;
  bool _excludeFromFuelEfficiency = false;
  bool _submitting = false;
  bool _syncingFromHours = false;
  String? _bottomTip;
  Timer? _bottomTipTimer;
  Timer? _meterValidateTimer;
  int _calculationHistoryIdSequence = 0;
  List<StagedTimingCalculationHistory> _stagedCalculationHistories = [];

  bool get _supportsBreakingMode {
    if (_mode != WorkMode.hours) return false;
    final id = _selectedDeviceId;
    if (id == null) return false;
    final device = widget.deviceById[id];
    if (device == null) return false;
    if (device.equipmentType == EquipmentType.loader) return false;
    if ((device.breakingUnitPrice ?? 0) > 0) return true;
    final editing = widget.editing;
    return editing != null && editing.deviceId == id && editing.isBreaking;
  }

  TimingEntryTemplate get _entryTemplate {
    final id = _selectedDeviceId;
    final device = id == null ? null : widget.deviceById[id];
    if (device == null) return TimingEntryTemplates.excavator;
    final resolver =
        widget.resolveEntryTemplate ?? TimingEntryTemplates.forDevice;
    return resolver(device);
  }

  TimingEntryUnitLayout get _hourLayout =>
      _entryTemplate.layoutFor(MeasureUnit.hour);

  TimingEntryUnitLayout get _rentLayout =>
      _entryTemplate.layoutFor(MeasureUnit.rent);

  bool get _showsEnergyExclusionControl =>
      _mode == WorkMode.hours && _entryTemplate.showsEnergyExclusion;

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;
    _selectedDate = DateTime.now();
    _syncDateText();
    if (editing == null) {
      _applyDefaultDeviceForCreate();
      return;
    }

    _selectedDeviceId = editing.deviceId;
    _selectedDate = FormatUtils.dateFromYmd(editing.startDate);
    _contactCtrl.text = editing.contact;
    _siteCtrl.text = editing.site;
    _mode = editing.type == TimingType.hours ? WorkMode.hours : WorkMode.rent;
    _selectedEndDate = _mode == WorkMode.hours
        ? _allocationEndInclusiveDateFromExclusiveYmd(
            editing.allocationCutoffDate,
          )
        : _displayEndDateFromYmd(editing.displayEndDate);
    _syncDateText();
    _attachmentMode = editing.isBreaking
        ? AttachmentMode.breaking
        : AttachmentMode.digging;
    _startMeterCtrl.text = FormatUtils.meter(editing.startMeter);
    _endMeterCtrl.text = FormatUtils.meter(editing.endMeter);
    _hoursCtrl.text = FormatUtils.meter(editing.hours);
    _incomeCtrl.text = FormatUtils.meter(editing.income);
    _excludeFromFuelEfficiency = editing.excludeFromFuelEfficiency;
  }

  void _applyDefaultDeviceForCreate() {
    if (widget.editing != null || _selectedDeviceId != null) return;

    final activeDevices = widget.activeDevices.where((d) => d.id != null);
    if (activeDevices.isEmpty) return;

    int? defaultDeviceId;
    for (final r in widget.records) {
      final d = widget.deviceById[r.deviceId];
      if (d != null && d.isActive) {
        defaultDeviceId = r.deviceId;
        break;
      }
    }

    defaultDeviceId ??= activeDevices.first.id;
    if (defaultDeviceId == null) return;

    final device = widget.deviceById[defaultDeviceId];
    if (device == null || !device.isActive) return;

    _selectedDeviceId = defaultDeviceId;

    final currentMeter = widget.resolveCurrentMeter(defaultDeviceId);
    _setStart(currentMeter);
    _setEnd(currentMeter);
    _hoursCtrl.text = '0.0';
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    _siteCtrl.dispose();
    _dateCtrl.dispose();
    _startMeterCtrl.dispose();
    _endMeterCtrl.dispose();
    _hoursCtrl.dispose();
    _incomeCtrl.dispose();
    _contactFocus.dispose();
    _siteFocus.dispose();
    _bottomTipTimer?.cancel();
    _meterValidateTimer?.cancel();
    super.dispose();
  }

  double _d(String s) => double.tryParse(s.trim()) ?? 0.0;

  void showSubmitFailure(String msg) {
    _toastInSheet(
      formValidationMessage(msg),
      duration: _submitFailureTipDuration,
    );
  }

  void _toastInSheet(
    String msg, {
    Duration duration = DurationTokens.snackBar,
  }) {
    _bottomTipTimer?.cancel();
    if (mounted) {
      setState(() => _bottomTip = msg);
    }
    _bottomTipTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _bottomTip = null);
    });
  }

  void _setStart(double v) => _startMeterCtrl.text = FormatUtils.meter(v);
  void _setEnd(double v) => _endMeterCtrl.text = FormatUtils.meter(v);

  bool _enforceMeterOrder() {
    final start = _d(_startMeterCtrl.text);
    final end = _d(_endMeterCtrl.text);
    if (end >= start) return true;
    _setEnd(start);
    return false;
  }

  void _scheduleMeterValidation() {
    _meterValidateTimer?.cancel();
    _meterValidateTimer = Timer(
      const Duration(milliseconds: TimingTokens.meterRollbackDebounceMs),
      () {
        if (!mounted) return;
        final corrected = !_enforceMeterOrder();
        _recalcHoursFromMeters();
        if (corrected) {
          _toastInSheet(autoCorrectedMessage('结束码表不能小于开始码表，已自动回滚'));
        }
      },
    );
  }

  void _recalcHoursFromMeters() {
    if (_syncingFromHours) return;
    final start = _d(_startMeterCtrl.text);
    final end = _d(_endMeterCtrl.text);
    if (end < start) {
      _hoursCtrl.text = '0.0';
      return;
    }
    _hoursCtrl.text = FormatUtils.meter(end - start);
  }

  void _recalcEndFromHours() {
    final start = _d(_startMeterCtrl.text);
    final hours = _d(_hoursCtrl.text);
    if (hours < 0) return;

    _syncingFromHours = true;
    _setEnd(start + hours);
    _syncingFromHours = false;
  }

  void _applyCalculatedHours(double result) {
    setState(() {
      _hoursCtrl.text = result.toStringAsFixed(1);
      _recalcEndFromHours();
    });
  }

  void _replaceStagedCalculationHistories(
    List<StagedTimingCalculationHistory> histories,
  ) {
    setState(() => _stagedCalculationHistories = List.of(histories));
  }

  List<TimingCalculationHistory> _buildCalculationHistoriesForSubmit() {
    if (_mode != WorkMode.hours || _stagedCalculationHistories.isEmpty) {
      return const <TimingCalculationHistory>[];
    }

    final timingRecordId = widget.editing?.id ?? 0;
    return _stagedCalculationHistories.map((history) {
      return TimingCalculationHistory(
        id: _nextCalculationHistoryId(),
        timingRecordId: timingRecordId,
        createdAt: history.createdAt,
        expression: history.expression,
        result: history.result,
        ticketCount: history.ticketCount,
      );
    }).toList();
  }

  String _nextCalculationHistoryId() {
    _calculationHistoryIdSequence += 1;
    return 'timing-calc-${DateTime.now().microsecondsSinceEpoch}-'
        '${identityHashCode(this)}-$_calculationHistoryIdSequence';
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showSheetDateRangePickerDialogResult(
      context: context,
      initialStartDate: _selectedDate,
      initialEndDate: _selectedEndDate,
      rangeEndMaxDate: _mode == WorkMode.hours
          ? _nextSameDeviceStartDateFor
          : null,
    );
    if (result.isCancelled || !mounted) return;
    final pickedStart = result.startDate;
    if (pickedStart == null) return;
    final pickedEnd = result.endDate;
    setState(() {
      _selectedDate = _dateOnly(pickedStart);
      _selectedEndDate = pickedEnd == null ? null : _dateOnly(pickedEnd);
      _syncDateText();
    });
  }

  void _onDeviceChanged(int? id) {
    setState(() => _selectedDeviceId = id);
    if (id == null) return;

    final device = widget.deviceById[id];
    if (device == null) {
      widget.onToast(missingEntityMessage('设备', id: id));
      setState(() => _selectedDeviceId = null);
      return;
    }

    if (widget.editing == null && !device.isActive) {
      widget.onToast(inactiveEntityCreateMessage('该设备'));
      setState(() => _selectedDeviceId = null);
      return;
    }

    final currentMeter = widget.resolveCurrentMeter(id);

    _setStart(currentMeter);
    _setEnd(currentMeter);
    _hoursCtrl.text = '0.0';

    if (!_supportsBreakingMode && _attachmentMode != AttachmentMode.digging) {
      setState(() => _attachmentMode = AttachmentMode.digging);
    }
    if (!_showsEnergyExclusionControl && _excludeFromFuelEfficiency) {
      setState(() => _excludeFromFuelEfficiency = false);
    }
  }

  Future<void> submit() async {
    if (_submitting) return;
    _meterValidateTimer?.cancel();
    _enforceMeterOrder();
    _recalcHoursFromMeters();
    FocusManager.instance.primaryFocus?.unfocus();

    final deviceId = _selectedDeviceId;
    if (deviceId == null) {
      _toastInSheet(formValidationMessage('请选择设备'));
      return;
    }

    final ymd = FormatUtils.ymdFromDate(_selectedDate);

    final contact = _contactCtrl.text.trim();
    final site = _siteCtrl.text.trim();
    if (contact.isEmpty || site.isEmpty) {
      _toastInSheet(formValidationMessage('联系人和工地不能为空'));
      return;
    }

    final startMeter = _d(_startMeterCtrl.text);
    final endMeter = _d(_endMeterCtrl.text);
    final hours = _d(_hoursCtrl.text);

    if (endMeter < startMeter) {
      _toastInSheet(formValidationMessage('结束码表不能小于开始码表'));
      return;
    }
    if (hours < 0) {
      _toastInSheet(formValidationMessage('工时不能为负数'));
      return;
    }

    final isRent = _mode == WorkMode.rent;
    final isBreaking =
        !isRent &&
        _supportsBreakingMode &&
        _attachmentMode == AttachmentMode.breaking;

    final income = isRent
        ? _d(_incomeCtrl.text)
        : await widget.resolveIncome(
            deviceId: deviceId,
            contact: contact,
            site: site,
            isBreaking: isBreaking,
            hours: hours,
          );

    if (isRent && income <= 0) {
      _toastInSheet(formValidationMessage('租金模式请填写金额（元）'));
      return;
    }

    final isClosed = (endMeter > startMeter) || (hours > 0);
    if (isClosed) {
      final boundsError = widget.validateMeterBounds(
        deviceId: deviceId,
        startDate: ymd,
        endMeter: endMeter,
        excludeId: widget.editing?.id,
      );
      if (boundsError != null) {
        _toastInSheet(formValidationMessage(boundsError));
        return;
      }
    }

    final type = isRent ? TimingType.rent : TimingType.hours;
    final excludeFuel =
        !isRent && _showsEnergyExclusionControl && _excludeFromFuelEfficiency;
    final allocationEndExclusiveYmd = isRent
        ? null
        : _allocationEndExclusiveYmd();
    final displayEndDateYmd = isRent ? _displayEndDateYmd() : null;

    final record = TimingRecord(
      id: widget.editing?.id,
      projectId: widget.editing?.projectId ?? '',
      deviceId: deviceId,
      startDate: ymd,
      allocationCutoffDate: allocationEndExclusiveYmd,
      displayEndDate: displayEndDateYmd,
      contact: contact,
      site: site,
      type: type,
      startMeter: startMeter,
      endMeter: endMeter,
      hours: hours,
      income: income,
      excludeFromFuelEfficiency: excludeFuel,
      isBreaking: isBreaking,
    );
    final calculationHistories = _buildCalculationHistoriesForSubmit();

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(record, calculationHistories);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _syncDateText() {
    final startYmd = FormatUtils.ymdFromDate(_selectedDate);
    _dateCtrl.text = FormatUtils.compactDateRange(startYmd, _selectedEndYmd());
  }

  int? _selectedEndYmd() {
    final endDate = _selectedEndDate;
    if (endDate == null || endDate.isBefore(_selectedDate)) return null;
    return FormatUtils.ymdFromDate(endDate);
  }

  int? _allocationEndExclusiveYmd() {
    final endDate = _selectedEndDate;
    if (endDate == null || endDate.isBefore(_selectedDate)) return null;
    final exclusiveEnd = endDate.add(const Duration(days: 1));
    return FormatUtils.ymdFromDate(exclusiveEnd);
  }

  int? _displayEndDateYmd() {
    final endDate = _selectedEndDate;
    if (endDate == null || endDate.isBefore(_selectedDate)) return null;
    return FormatUtils.ymdFromDate(endDate);
  }

  DateTime? _nextSameDeviceStartDateFor(DateTime startDate) {
    final deviceId = _selectedDeviceId;
    if (deviceId == null) return null;
    final startYmd = FormatUtils.ymdFromDate(startDate);
    final editingId = widget.editing?.id;
    final candidates =
        widget.records
            .where((record) {
              if (record.deviceId != deviceId) return false;
              if (editingId != null && record.id == editingId) return false;
              return record.startDate >= startYmd;
            })
            .toList(growable: false)
          ..sort(_compareRecordByDateMeterId);
    if (candidates.isEmpty) return null;
    return FormatUtils.dateFromYmd(candidates.first.startDate);
  }

  int _compareRecordByDateMeterId(TimingRecord a, TimingRecord b) {
    final byDate = a.startDate.compareTo(b.startDate);
    if (byDate != 0) return byDate;
    final byMeter = a.startMeter.compareTo(b.startMeter);
    if (byMeter != 0) return byMeter;
    return (a.id ?? 1 << 30).compareTo(b.id ?? 1 << 30);
  }

  DateTime? _allocationEndInclusiveDateFromExclusiveYmd(int? exclusiveYmd) {
    if (exclusiveYmd == null) return null;
    try {
      final exclusive = FormatUtils.dateFromYmd(exclusiveYmd);
      final inclusive = _dateOnly(exclusive.subtract(const Duration(days: 1)));
      return inclusive.isBefore(_selectedDate) ? null : inclusive;
    } on ArgumentError {
      return null;
    }
  }

  DateTime? _displayEndDateFromYmd(int? ymd) {
    if (ymd == null) return null;
    try {
      final displayEnd = _dateOnly(FormatUtils.dateFromYmd(ymd));
      return displayEnd.isBefore(_selectedDate) ? null : displayEnd;
    } on ArgumentError {
      return null;
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _selectModeIndex(int index) {
    setState(() {
      _mode = index == 0 ? WorkMode.hours : WorkMode.rent;
      if (_mode == WorkMode.hours) _incomeCtrl.text = '0.0';
      if (_mode == WorkMode.rent) {
        _excludeFromFuelEfficiency = false;
        _attachmentMode = AttachmentMode.digging;
      }
      if (!_entryTemplate.showsEnergyExclusion) {
        _excludeFromFuelEfficiency = false;
      }
    });
  }

  void _selectAttachmentIndex(int index) {
    setState(() {
      _attachmentMode = index == 0
          ? AttachmentMode.digging
          : AttachmentMode.breaking;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BottomSheetTokens.outerHPadding,
                  0,
                  BottomSheetTokens.outerHPadding,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DevicePickerPattern(
                      vm: DevicePickerVm(
                        selectedId: _selectedDeviceId,
                        items: widget.deviceItems,
                        onChanged: _submitting ? (_) {} : _onDeviceChanged,
                        hintText: '请选择设备',
                      ),
                    ),
                    const SizedBox(height: TimingTokens.contentGap),
                    _buildModeSelector(),
                    const SizedBox(height: TimingTokens.contentGap),
                    SheetDateField(
                      controller: _dateCtrl,
                      onPickDate: _pickDate,
                    ),
                    const SizedBox(height: TimingTokens.contentGap),
                    Row(
                      children: [
                        Flexible(
                          flex: TimingTokens.contactFieldFlex,
                          child: AutoSuggestField(
                            controller: _contactCtrl,
                            focusNode: _contactFocus,
                            label: '联系人',
                            hint: '联系人',
                            onSelected: (_) {},
                            suggestionsBuilder: widget.contactSuggestions,
                          ),
                        ),
                        const SizedBox(width: TimingTokens.twoColumnGap),
                        Flexible(
                          flex: TimingTokens.addressFieldFlex,
                          child: AutoSuggestField(
                            controller: _siteCtrl,
                            focusNode: _siteFocus,
                            label: '使用地址/工地',
                            hint: '使用地址/工地',
                            onSelected: (_) {},
                            suggestionsBuilder: widget.siteSuggestions,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TimingTokens.contentGap),
                    TimingTimeBlock(
                      title: '开始工作时间',
                      controller: _startMeterCtrl,
                      alignLabelToContainer: true,
                      onChanged: (start) {
                        final end = _d(_endMeterCtrl.text);
                        if (end < start) _setEnd(start);
                        _recalcHoursFromMeters();
                      },
                    ),
                    const SizedBox(height: TimingTokens.contentGap),
                    TimingTimeBlock(
                      title: '结束工作时间',
                      controller: _endMeterCtrl,
                      alignLabelToContainer: true,
                      onChanged: (_) {
                        _recalcHoursFromMeters();
                        _scheduleMeterValidation();
                      },
                    ),
                    const SizedBox(height: TimingTokens.contentGap),
                    if (_mode == WorkMode.hours) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_supportsBreakingMode) ...[
                            _buildAttachmentSelector(compact: true),
                            const SizedBox(width: TimingTokens.twoColumnGap),
                          ],
                          Expanded(
                            child: _field(
                              controller: _hoursCtrl,
                              hint: _hoursCtrl.text,
                              label: _hourLayout.quantityLabel,
                              onTap: _submitting
                                  ? null
                                  : _openWorkHourCalculator,
                              onChanged: (_) => _recalcEndFromHours(),
                              suffixIcon: _TimingFieldAssetIconButton(
                                tooltip: '工时计算依据',
                                assetPath: _workHourCalculatorIconAsset,
                                onPressed: _submitting
                                    ? null
                                    : _openWorkHourCalculator,
                              ),
                              readOnly: true,
                              canRequestFocus: false,
                              showCursor: false,
                              enableInteractiveSelection: false,
                              selectAllOnTap: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: TimingTokens.contentGap),
                      if (_showsEnergyExclusionControl)
                        ExcludeFuelSwitchCard(
                          value: _excludeFromFuelEfficiency,
                          title: _entryTemplate.energyExclusionTitle,
                          description:
                              _entryTemplate.energyExclusionDescription,
                          onChanged: (v) =>
                              setState(() => _excludeFromFuelEfficiency = v),
                        ),
                    ] else ...[
                      _field(
                        controller: _hoursCtrl,
                        hint: '0.0（可空）',
                        label: _rentLayout.quantityLabel,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _recalcEndFromHours(),
                        selectAllOnTap: true,
                      ),
                      const SizedBox(height: TimingTokens.contentGap),
                      _field(
                        controller: _incomeCtrl,
                        hint: _incomeCtrl.text,
                        label: '金额（元）',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _bottomTip == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(_bottomTip),
                    padding: const EdgeInsets.only(
                      bottom: TimingTokens.tipBottomGap,
                    ),
                    child: AppToastBubble(_bottomTip!),
                  ),
          ),
        ],
      ),
    );
  }
}
