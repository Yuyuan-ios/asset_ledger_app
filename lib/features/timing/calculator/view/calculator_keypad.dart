import 'package:flutter/material.dart';

// [新增] 满足 no_textstyle_in_migrated_modules：用 AppTypography.actionText
// 代替按键的 textStyle 直接 TextStyle 构造。
import '../../../../core/foundation/typography.dart';

const _keyHeight = 62.0;
const _keyRadius = 20.0;
const _keypadBackground = Color(0xFF050505);
const _digitBackground = Color(0xFF242424);
const _digitText = Color(0xFFF2F2F2);
const _neutralBackground = Color(0xFF2D2D2D);
const _neutralText = Color(0xFFD0C8BE);
const _operatorText = Color(0xFFF58220);
const _equalBackground = Color(0xFFF58220);

enum _KeyTone { digit, neutral, operator }

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
    final bottomSafePadding = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomSafePadding + 14),
      decoration: const BoxDecoration(color: _keypadBackground),
      child: Column(
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
              _TextKey(label: 'C', tone: _KeyTone.neutral, onPressed: onClear),
            ],
          ),
          const SizedBox(height: 8),
          _KeyRow(
            children: [
              _DigitKey(label: '1', onPressed: () => onDigit('1')),
              _DigitKey(label: '2', onPressed: () => onDigit('2')),
              _DigitKey(label: '3', onPressed: () => onDigit('3')),
              _TextKey(label: '+', tone: _KeyTone.operator, onPressed: onPlus),
            ],
          ),
          const SizedBox(height: 8),
          _KeyRow(
            children: [
              _EqualKey(onPressed: onEqual),
              _DigitKey(label: '0', onPressed: () => onDigit('0')),
              _TextKey(label: '.', onPressed: onDecimal),
            ],
          ),
        ],
      ),
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
  const _TextKey({
    required this.label,
    required this.onPressed,
    this.tone = _KeyTone.digit,
  });

  final String label;
  final VoidCallback onPressed;
  final _KeyTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _keyColors(tone);
    return SizedBox(
      height: _keyHeight,
      child: DecoratedBox(
        decoration: _keyShadowDecoration(),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: colors.background,
            foregroundColor: colors.foreground,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size.fromHeight(_keyHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_keyRadius),
            ),
            textStyle: AppTypography.actionText(
              context,
              fontSize: tone == _KeyTone.digit ? 32 : 30,
              fontWeight: tone == _KeyTone.digit
                  ? FontWeight.w600
                  : FontWeight.w700,
            ),
          ),
          child: Text(label),
        ),
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
      height: _keyHeight,
      child: DecoratedBox(
        decoration: _keyShadowDecoration(),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: _neutralBackground,
            foregroundColor: _neutralText,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size.fromHeight(_keyHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_keyRadius),
            ),
          ),
          child: Icon(icon, size: 25),
        ),
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
      height: _keyHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_keyRadius),
          boxShadow: [
            BoxShadow(
              color: _equalBackground.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _equalBackground,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size.fromHeight(_keyHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_keyRadius),
            ),
            textStyle: AppTypography.actionText(
              context,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '=',
                style: AppTypography.actionText(
                  context,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                  color: Colors.white,
                ),
              ),
              Text(
                '填入',
                style: AppTypography.actionText(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_KeyColors _keyColors(_KeyTone tone) {
  switch (tone) {
    case _KeyTone.digit:
      return const _KeyColors(
        background: _digitBackground,
        foreground: _digitText,
      );
    case _KeyTone.neutral:
      return const _KeyColors(
        background: _neutralBackground,
        foreground: _neutralText,
      );
    case _KeyTone.operator:
      return const _KeyColors(
        background: _digitBackground,
        foreground: _operatorText,
      );
  }
}

BoxDecoration _keyShadowDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(_keyRadius),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.035),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

class _KeyColors {
  const _KeyColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
