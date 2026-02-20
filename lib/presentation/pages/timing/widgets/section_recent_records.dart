import 'package:flutter/material.dart';

import '../../../../models/timing_record.dart';
import '../../../../store/device_store.dart';
import '../../../utils/format_utils.dart';

class SectionRecentRecords extends StatelessWidget {
  final List<TimingRecord> records;
  final DeviceStore? deviceStore;
  final ValueChanged<TimingRecord>? onTapRecord;
  final ValueChanged<TimingRecord>? onLongPressRecord;

  const SectionRecentRecords({
    super.key,
    required this.records,
    this.deviceStore,
    this.onTapRecord,
    this.onLongPressRecord,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '暂无记录',
          style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
        ),
      );
    }

    final sorted = List<TimingRecord>.of(records)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final grouped = <int, List<TimingRecord>>{};
    for (final record in sorted) {
      grouped.putIfAbsent(record.startDate, () => <TimingRecord>[]).add(record);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return _DateGroup(
          ymd: entry.key,
          items: entry.value,
          onTapRecord: onTapRecord,
          onLongPressRecord: onLongPressRecord,
        );
      }).toList(),
    );
  }
}

class _DateGroup extends StatelessWidget {
  final int ymd;
  final List<TimingRecord> items;
  final ValueChanged<TimingRecord>? onTapRecord;
  final ValueChanged<TimingRecord>? onLongPressRecord;

  const _DateGroup({
    required this.ymd,
    required this.items,
    this.onTapRecord,
    this.onLongPressRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ymd.toString(),
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFD9D9D9)),
        ...items.map(
          (record) => _RecordRow(
            record: record,
            onTap: onTapRecord == null ? null : () => onTapRecord!(record),
            onLongPress: onLongPressRecord == null
                ? null
                : () => onLongPressRecord!(record),
          ),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  final TimingRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _RecordRow({required this.record, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD0D0D0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${record.contact}·${record.site}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '1#',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${FormatUtils.meter(record.startMeter)} \u2192 ${FormatUtils.meter(record.endMeter)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      FormatUtils.hours(record.hours),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
