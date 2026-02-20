import 'package:flutter/material.dart';

class CardMainChart extends StatelessWidget {
  const CardMainChart({super.key});

  @override
  Widget build(BuildContext context) {
    const months = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    const incomeBars = [
      150.0,
      150.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ];
    const expenseBars = [
      15.0,
      75.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ];

    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: Column(
          children: [
            const SizedBox(
              height: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '<',
                    style: TextStyle(
                      fontSize: 20,
                      height: 1,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    '2026年',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '>',
                    style: TextStyle(
                      fontSize: 20,
                      height: 1,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFD9D9D9)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(months.length, (index) {
                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: incomeBars[index],
                                      color: const Color(0xFF82C99E),
                                    ),
                                    const SizedBox(width: 1),
                                    Container(
                                      width: 6,
                                      height: expenseBars[index],
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  months[index],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Legend(
                            label: '收入',
                            swatchColor: Color(0xFF82C99E),
                            value: '￥1000000',
                          ),
                          SizedBox(width: 10),
                          _Legend(
                            label: '支出',
                            swatchColor: Colors.black,
                            value: '￥500000',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color swatchColor;
  final String value;

  const _Legend({
    required this.label,
    required this.swatchColor,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: swatchColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Colors.black, height: 1),
        ),
      ],
    );
  }
}
