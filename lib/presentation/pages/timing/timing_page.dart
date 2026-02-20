import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/timing_record.dart';
import '../../../store/device_store.dart';
import '../../../store/timing_store.dart';
import '../../content/timing_detail_content.dart';
import '../../sheets/app_bottom_sheet_shell.dart';
import 'widgets/card_main_chart.dart';
import 'widgets/records_title.dart';
import 'widgets/section_header.dart';
import 'widgets/section_recent_records.dart';

class TimingPage extends StatefulWidget {
  const TimingPage({super.key});

  @override
  State<TimingPage> createState() => _TimingPageState();
}

class _TimingPageState extends State<TimingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deviceStore = context.read<DeviceStore>();
      final timingStore = context.read<TimingStore>();
      await deviceStore.loadAll();
      await timingStore.loadAll();
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openTimingEditor({TimingRecord? editing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AppBottomSheetShell(
          title: editing == null ? '新建计时' : '编辑计时',
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: TimingDetailContent(
              editing: editing,
              onCancel: () => Navigator.of(context).pop(),
              onToast: _toast,
              onSubmit: (record) async {
                final store = context.read<TimingStore>();
                await store.save(record);
                if (!mounted) return;

                if (store.error != null) {
                  _toast('保存失败：${store.error}');
                  return;
                }

                _toast('已保存');
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteRecord(TimingRecord record) async {
    if (record.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('删除记录'),
          content: Text(
            '日期：${record.startDate}\\n'
            '联系人：${record.contact}\\n'
            '工地：${record.site}\\n\\n'
            '确定删除这条记录吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    if (!mounted) return;

    final store = context.read<TimingStore>();
    await store.deleteById(record.id!);
    if (!mounted) return;
    if (store.error != null) {
      _toast('删除失败：${store.error}');
    } else {
      _toast('已删除');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timingStore = context.watch<TimingStore>();
    final deviceStore = context.watch<DeviceStore>();

    final loading = timingStore.loading || deviceStore.loading;
    final error = timingStore.error ?? deviceStore.error;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 420
                ? 393.0
                : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
                  child: Column(
                    children: [
                      SectionHeader(onAdd: () => _openTimingEditor()),
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (loading)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: LinearProgressIndicator(minHeight: 2),
                                ),
                              if (error != null && error.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    error,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const CardMainChart(),
                              const SizedBox(height: 8),
                              RecordsTitle(count: timingStore.records.length),
                              const SizedBox(height: 2),
                              SectionRecentRecords(
                                records: timingStore.records,
                                deviceStore: deviceStore,
                                onTapRecord: (r) =>
                                    _openTimingEditor(editing: r),
                                onLongPressRecord: _deleteRecord,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
