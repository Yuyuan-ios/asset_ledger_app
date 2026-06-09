import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/device.dart';
import '../../data/models/project_device_rate.dart';
import '../../data/models/timing_record.dart';
import '../../features/timing/calculator/model/staged_timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import '../../features/timing/calculator/view/work_hour_calculator_sheet.dart';
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

  @override
  void initState() {
    super.initState();

    final editing = widget.editing;
    _selectedDate = DateTime.now();
    _dateCtrl.text = FormatUtils.date(FormatUtils.ymdFromDate(_selectedDate));
    if (editing == null) {
      _applyDefaultDeviceForCreate();
      return;
    }

    _selectedDeviceId = editing.deviceId;
    _selectedDate = FormatUtils.dateFromYmd(editing.startDate);
    _dateCtrl.text = FormatUtils.date(editing.startDate);
    _contactCtrl.text = editing.contact;
    _siteCtrl.text = editing.site;
    _mode = editing.type == TimingType.hours ? WorkMode.hours : WorkMode.rent;
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

  void _toastInSheet(String msg) {
    _bottomTipTimer?.cancel();
    if (mounted) {
      setState(() => _bottomTip = msg);
    }
    _bottomTipTimer = Timer(DurationTokens.snackBar, () {
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
    final picked = await showSheetDatePickerDialog(
      context: context,
      initialDate: _selectedDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _dateCtrl.text = FormatUtils.date(FormatUtils.ymdFromDate(_selectedDate));
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
    final excludeFuel = !isRent && _excludeFromFuelEfficiency;
    final editing = widget.editing;
    final allocationEndExclusiveYmd =
        !isRent && editing?.type == TimingType.hours
        ? editing?.allocationCutoffDate
        : null;
    final displayEndDateYmd = isRent && editing?.type == TimingType.rent
        ? editing?.displayEndDate
        : null;

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

  void _selectModeIndex(int index) {
    setState(() {
      _mode = index == 0 ? WorkMode.hours : WorkMode.rent;
      if (_mode == WorkMode.hours) _incomeCtrl.text = '0.0';
      if (_mode == WorkMode.rent) {
        _excludeFromFuelEfficiency = false;
        _attachmentMode = AttachmentMode.digging;
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
                              label: '工时（小时）',
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
                      ExcludeFuelSwitchCard(
                        value: _excludeFromFuelEfficiency,
                        onChanged: (v) =>
                            setState(() => _excludeFromFuelEfficiency = v),
                      ),
                    ] else ...[
                      _field(
                        controller: _hoursCtrl,
                        hint: '0.0（可空）',
                        label: '工时（小时，可空）',
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
