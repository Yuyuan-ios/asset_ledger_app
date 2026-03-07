import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../../data/services/timing_service.dart';
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
import '../../components/fields/app_auto_suggest_field.dart';
import '../../patterns/device/device_picker_pattern.dart';
import '../../components/fields/app_date_field.dart';
import '../../components/pickers/app_date_picker_dialog.dart';

enum WorkMode { hours, rent }

enum AttachmentMode { digging, breaking }

class TimingDetailContent extends StatefulWidget {
  const TimingDetailContent({
    super.key,
    this.editing,
    required this.records,
    required this.activeDevices,
    required this.deviceById,
    required this.deviceItems,
    required this.contactSuggestions,
    required this.siteSuggestions,
    this.onCancel,
    required this.onSubmit,
    required this.onToast,
  });

  final TimingRecord? editing;
  final List<TimingRecord> records;
  final List<Device> activeDevices;
  final Map<int, Device> deviceById;
  final List<DevicePickerItemVm> deviceItems;
  final List<String> Function(String) contactSuggestions;
  final List<String> Function(String) siteSuggestions;
  final VoidCallback? onCancel;
  final Future<void> Function(TimingRecord record) onSubmit;
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

  bool get _isSelectedLoader {
    final id = _selectedDeviceId;
    if (id == null) return false;
    final device = widget.deviceById[id];
    if (device == null) return false;
    return device.equipmentType == EquipmentType.loader;
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

    final currentMeter = TimingService.currentMeter(
      widget.records,
      defaultDeviceId,
      baseMeterHours: device.baseMeterHours,
    );
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
    widget.onToast(msg);
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

  Future<void> _pickDate() async {
    final picked = await showSheetDatePickerDialog(
      context: context,
      initialDate: _selectedDate,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _dateCtrl.text = FormatUtils.date(FormatUtils.ymdFromDate(_selectedDate));
    });
  }

  InputDecoration _sheetDecoration({
    required String hint,
    String? label,
    Widget? suffixIcon,
  }) {
    final hintStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.hint,
    );
    final labelStyle = AppTypography.bodySecondary(
      context,
      fontSize: SheetTokens.fieldLabelSize,
      color: SheetColors.textPrimary,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      labelText: label,
      labelStyle: labelStyle,
      floatingLabelBehavior: label == null
          ? FloatingLabelBehavior.never
          : FloatingLabelBehavior.always,
      filled: true,
      fillColor: SheetColors.fieldBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SheetTokens.fieldContentHPadding,
        vertical: SheetTokens.fieldContentVPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
        borderSide: const BorderSide(
          color: SheetColors.fieldBorder,
          width: SheetTokens.fieldBorderWidth,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
        borderSide: const BorderSide(
          color: SheetColors.fieldBorder,
          width: SheetTokens.fieldBorderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SheetTokens.fieldRadius),
        borderSide: const BorderSide(
          color: SheetColors.fieldBorder,
          width: SheetTokens.fieldBorderWidth,
        ),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    String? label,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    final fieldStyle = AppTypography.body(
      context,
      fontSize: SheetTokens.fieldTextSize,
      color: SheetColors.textPrimary,
    );
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: fieldStyle,
      decoration: _sheetDecoration(
        hint: hint,
        label: label,
        suffixIcon: suffixIcon,
      ),
    );
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

    final currentMeter = TimingService.currentMeter(
      widget.records,
      id,
      baseMeterHours: device.baseMeterHours,
    );

    _setStart(currentMeter);
    _setEnd(currentMeter);
    _hoursCtrl.text = '0.0';

    setState(() {});

    if (_isSelectedLoader &&
        _mode == WorkMode.hours &&
        _attachmentMode != AttachmentMode.digging) {
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
    final income = isRent ? _d(_incomeCtrl.text) : 0.0;
    if (isRent && income <= 0) {
      _toastInSheet(formValidationMessage('租金模式请填写金额（元）'));
      return;
    }

    final isClosed = (endMeter > startMeter) || (hours > 0);
    if (isClosed) {
      final excludeId = widget.editing?.id;

      final lower = TimingService.lowerBound(
        records: widget.records,
        deviceId: deviceId,
        startDate: ymd,
        excludeId: excludeId,
      );
      final upper = TimingService.upperBound(
        records: widget.records,
        deviceId: deviceId,
        startDate: ymd,
        excludeId: excludeId,
      );

      if (endMeter < lower) {
        _toastInSheet(formValidationMessage('结束码表($endMeter) < 下界($lower)'));
        return;
      }
      if (upper != double.infinity && endMeter > upper) {
        _toastInSheet(formValidationMessage('结束码表($endMeter) > 上界($upper)'));
        return;
      }
    }

    final type = isRent ? TimingType.rent : TimingType.hours;
    final excludeFuel = !isRent && _excludeFromFuelEfficiency;
    final isBreaking =
        !isRent &&
        !_isSelectedLoader &&
        _attachmentMode == AttachmentMode.breaking;

    final record = TimingRecord(
      id: widget.editing?.id,
      deviceId: deviceId,
      startDate: ymd,
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

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(record);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                          if (!_isSelectedLoader) ...[
                            _buildAttachmentSelector(compact: true),
                            const SizedBox(width: TimingTokens.twoColumnGap),
                          ],
                          Expanded(
                            child: _field(
                              controller: _hoursCtrl,
                              hint: _hoursCtrl.text,
                              label: '工时（小时）',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => _recalcEndFromHours(),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TimingTokens.tipHPadding,
                        vertical: TimingTokens.tipVPadding,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(
                          TimingTokens.tipRadius,
                        ),
                      ),
                      child: Text(
                        _bottomTip!,
                        style: AppTypography.caption(
                          context,
                          color: Colors.white,
                          fontSize: TimingTokens.tipTextSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoOptionSegment({
    required int selectedIndex,
    required void Function(int index) onTap,
    required String leftText,
    required String rightText,
    double? width,
    double? height,
    double? inset,
    double? radius,
    double? itemHeight,
    double? checkRightGap,
    double? checkSize,
    double? textSize,
  }) {
    final resolvedRadius = radius ?? TimingTokens.segmentRadius;
    final resolvedHeight = height ?? TimingTokens.segmentHeight;
    final resolvedInset = inset ?? TimingTokens.segmentInset;
    final resolvedItemHeight = itemHeight ?? TimingTokens.segmentItemHeight;
    final resolvedCheckRightGap =
        checkRightGap ?? TimingTokens.segmentCheckRightGap;
    final resolvedCheckSize = checkSize ?? TimingTokens.segmentCheckSize;
    final resolvedTextSize = textSize ?? TimingTokens.segmentTextSize;
    final checkStyle = AppTypography.caption(
      context,
      fontSize: resolvedCheckSize,
      color: SheetColors.textPrimary,
    );
    final segmentTextStyle = AppTypography.body(
      context,
      fontSize: resolvedTextSize,
      color: SheetColors.textPrimary,
    );

    Widget buildSegmentItem(int index, String text) {
      final selected = selectedIndex == index;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(resolvedRadius),
          onTap: () => onTap(index),
          child: Container(
            height: resolvedItemHeight,
            decoration: BoxDecoration(
              color: selected
                  ? SheetColors.segmentSelected
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(resolvedRadius),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected)
                  Padding(
                    padding: EdgeInsets.only(right: resolvedCheckRightGap),
                    child: Text('✓', style: checkStyle),
                  ),
                Text(text, style: segmentTextStyle),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: width ?? double.infinity,
      height: resolvedHeight,
      padding: EdgeInsets.all(resolvedInset),
      decoration: BoxDecoration(
        color: SheetColors.segmentBackground,
        borderRadius: BorderRadius.circular(resolvedRadius),
        border: Border.all(color: SheetColors.segmentBorder),
      ),
      child: Row(
        children: [
          buildSegmentItem(0, leftText),
          buildSegmentItem(1, rightText),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return _buildTwoOptionSegment(
      selectedIndex: _mode == WorkMode.hours ? 0 : 1,
      onTap: (index) {
        setState(() {
          _mode = index == 0 ? WorkMode.hours : WorkMode.rent;
          if (_mode == WorkMode.hours) _incomeCtrl.text = '0.0';
          if (_mode == WorkMode.rent) {
            _excludeFromFuelEfficiency = false;
            _attachmentMode = AttachmentMode.digging;
          }
        });
      },
      leftText: '工时',
      rightText: '租金',
    );
  }

  Widget _buildAttachmentSelector({bool compact = false}) {
    return _buildTwoOptionSegment(
      selectedIndex: _attachmentMode == AttachmentMode.digging ? 0 : 1,
      onTap: (index) {
        setState(() {
          _attachmentMode = index == 0
              ? AttachmentMode.digging
              : AttachmentMode.breaking;
        });
      },
      leftText: '挖斗',
      rightText: '破碎',
      width: compact ? 148 : null,
      height: compact ? SheetTokens.fieldHeight : null,
      inset: compact ? 2 : null,
      radius: compact ? SheetTokens.fieldRadius : null,
      itemHeight: compact ? SheetTokens.fieldHeight - 4 : null,
      checkRightGap: compact ? 2 : null,
      checkSize: compact ? 10 : null,
      textSize: compact ? 12 : null,
    );
  }
}
