import 'package:flutter/material.dart';

// [新增] 满足 no_textstyle_in_migrated_modules：用 AppTypography.actionText
// 代替按键的 textStyle 直接 TextStyle 构造。
import '../../../../core/foundation/typography.dart';

class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onPlus,
    required this.onBackspace,
    required this.onClear,
    required this.onEqual,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onPlus;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEqual;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyRow(
          children: [
            _DigitKey(label: '7', onPressed: () => onDigit('7')),
            _DigitKey(label: '8', onPressed: () => onDigit('8')),
            _DigitKey(label: '9', onPressed: () => onDigit('9')),
            _IconKey(icon: Icons.backspace_outlined, onPressed: onBackspace),
          ],
        ),
        const SizedBox(height: 8),
        _KeyRow(
          children: [
            _DigitKey(label: '4', onPressed: () => onDigit('4')),
            _DigitKey(label: '5', onPressed: () => onDigit('5')),
            _DigitKey(label: '6', onPressed: () => onDigit('6')),
            _TextKey(label: 'C', onPressed: onClear),
          ],
        ),
        const SizedBox(height: 8),
        _KeyRow(
          children: [
            _DigitKey(label: '1', onPressed: () => onDigit('1')),
            _DigitKey(label: '2', onPressed: () => onDigit('2')),
            _DigitKey(label: '3', onPressed: () => onDigit('3')),
            _TextKey(label: '+', onPressed: onPlus),
          ],
        ),
        const SizedBox(height: 8),
        _KeyRow(
          children: [
            _DigitKey(label: '0', onPressed: () => onDigit('0')),
            _TextKey(label: '.', onPressed: onDecimal),
            _EqualKey(onPressed: onEqual),
          ],
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _TextKey(label: label, onPressed: onPressed);
  }
}

class _TextKey extends StatelessWidget {
  const _TextKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          // [修改] TextStyle → AppTypography.actionText
          textStyle: AppTypography.actionText(
            context,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  const _IconKey({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _EqualKey extends StatelessWidget {
  const _EqualKey({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          // [修改] TextStyle → AppTypography.actionText（=号键与数字键同字号字重）
          textStyle: AppTypography.actionText(
            context,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Text('='),
      ),
    );
  }
}
