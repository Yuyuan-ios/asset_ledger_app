part of 'phone_login_gate.dart';

const double _loginBaseWidth = 704;
const double _loginBaseHeight = 1526;
const Color _loginBackground = Color(0xFFF5F1E8);
const Color _loginTextPrimary = Color(0xFF211F1B);
const Color _loginTextSecondary = Color(0xFF3F3B34);
const Color _loginBodyText = Color(0xFF4B463E);
const Color _loginMutedText = Color(0xFF8B877F);
const Color _loginFieldText = Color(0xFF24211D);
const Color _loginCodeText = Color(0xFF4F4A42);
const Color _loginAccent = Color(0xFFC95D21);
const Color _loginOutline = Color(0xFFA64B2C);
const Color _loginIconColor = Color(0xFFD9D5CD);
const Color _loginGeometryColor = Color(0xFFD9D4CA);
const Color _loginDisabledControl = Color(0xFFE2E1DD);

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.scale,
    required this.phoneController,
    required this.codeController,
    required this.codeFocusNode,
    required this.busy,
    required this.agreementAccepted,
    required this.canRequestCode,
    required this.canLogin,
    required this.requestCodeLabel,
    required this.onAgreementChanged,
    required this.onRequestCode,
    required this.onLogin,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTerms,
    this.errorText,
    this.statusText,
  });

  final double scale;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final FocusNode codeFocusNode;
  final bool busy;
  final bool agreementAccepted;
  final bool canRequestCode;
  final bool canLogin;
  final String requestCodeLabel;
  final String? errorText;
  final String? statusText;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onRequestCode;
  final VoidCallback onLogin;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26 * scale);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF503C23).withValues(alpha: 0.10),
            blurRadius: 45 * scale,
            offset: Offset(0, 20 * scale),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: scale,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 35 * scale,
                  top: 36 * scale,
                  width: 506 * scale,
                  height: 87 * scale,
                  child: _PhoneNumberField(
                    scale: scale,
                    controller: phoneController,
                  ),
                ),
                Positioned(
                  left: 36 * scale,
                  top: 147 * scale,
                  width: 274 * scale,
                  height: 87 * scale,
                  child: _CodeTextField(
                    scale: scale,
                    controller: codeController,
                    focusNode: codeFocusNode,
                  ),
                ),
                Positioned(
                  left: 330 * scale,
                  top: 147 * scale,
                  width: 212 * scale,
                  height: 87 * scale,
                  child: _RequestCodeButton(
                    scale: scale,
                    busy: busy,
                    canRequestCode: canRequestCode,
                    label: requestCodeLabel,
                    onRequestCode: onRequestCode,
                  ),
                ),
                if (statusText != null || errorText != null)
                  Positioned(
                    left: 35 * scale,
                    top: 238 * scale,
                    width: 506 * scale,
                    child: _LoginFeedbackText(
                      scale: scale,
                      statusText: statusText,
                      errorText: errorText,
                    ),
                  ),
                Positioned(
                  left: 41 * scale,
                  top: 271 * scale,
                  width: 470 * scale,
                  height: 70 * scale,
                  child: _AgreementRow(
                    scale: scale,
                    accepted: agreementAccepted,
                    onChanged: onAgreementChanged,
                    onOpenPrivacyPolicy: onOpenPrivacyPolicy,
                    onOpenTerms: onOpenTerms,
                  ),
                ),
                Positioned(
                  left: 34 * scale,
                  top: 360 * scale,
                  width: 508 * scale,
                  height: 71 * scale,
                  child: _LoginButton(
                    scale: scale,
                    busy: busy,
                    canLogin: canLogin,
                    onLogin: onLogin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.scale,
    required this.accepted,
    required this.onChanged,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTerms,
  });

  final double scale;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final normalStyle = _loginTextStyle(
      fontSize: 23,
      lineHeight: 32,
      color: _loginBodyText,
      scale: scale,
    );
    final linkStyle = _loginTextStyle(
      fontSize: 23,
      lineHeight: 32,
      color: _loginOutline,
      scale: scale,
    );

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 6 * scale,
          width: 38 * scale,
          height: 37 * scale,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AgreementCheckPainter(accepted: accepted),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.001,
                  child: Checkbox(
                    value: accepted,
                    onChanged: (value) => onChanged(value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 60 * scale,
          top: 0,
          height: 32 * scale,
          child: Row(
            children: [
              Text(
                '我已阅读并同意',
                strutStyle: _loginStrut(23, 32, scale),
                style: normalStyle,
              ),
              InkWell(
                onTap: onOpenPrivacyPolicy,
                child: Text(
                  '《隐私政策》',
                  strutStyle: _loginStrut(23, 32, scale),
                  style: linkStyle,
                ),
              ),
              Text(
                '和',
                strutStyle: _loginStrut(23, 32, scale),
                style: normalStyle,
              ),
            ],
          ),
        ),
        Positioned(
          left: 70 * scale,
          top: 30 * scale,
          height: 32 * scale,
          child: Row(
            children: [
              InkWell(
                onTap: onOpenTerms,
                child: Text(
                  '《使用条款》',
                  strutStyle: _loginStrut(23, 32, scale),
                  style: linkStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneNumberField extends StatelessWidget {
  const _PhoneNumberField({required this.scale, required this.controller});

  final double scale;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _LoginFieldShell(
      scale: scale,
      child: Stack(
        children: [
          Positioned(
            left: 22 * scale,
            top: 29 * scale,
            width: 39 * scale,
            height: 29 * scale,
            child: CustomPaint(painter: _ChinaFlagPainter()),
          ),
          Positioned(
            left: 71 * scale,
            top: 25 * scale,
            height: 36 * scale,
            child: Text(
              '+86',
              strutStyle: _loginStrut(28, 36, scale),
              style: _loginTextStyle(
                fontSize: 28,
                lineHeight: 36,
                fontWeight: FontWeight.w600,
                color: _loginFieldText,
                scale: scale,
              ),
            ),
          ),
          Positioned(
            left: 146 * scale,
            top: 25 * scale,
            width: 2 * scale,
            height: 42 * scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFD1CDC5).withValues(alpha: 0.9),
              ),
            ),
          ),
          Positioned(
            left: 171 * scale,
            top: 24 * scale,
            width: 300 * scale,
            height: 42 * scale,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              cursorColor: _loginOutline,
              style: _loginTextStyle(
                fontSize: 30,
                lineHeight: 40,
                color: _loginFieldText,
                scale: scale,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: '手机号',
                hintStyle: _loginTextStyle(
                  fontSize: 30,
                  lineHeight: 40,
                  color: _loginMutedText,
                  scale: scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeTextField extends StatelessWidget {
  const _CodeTextField({
    required this.scale,
    required this.controller,
    required this.focusNode,
  });

  final double scale;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return _LoginFieldShell(
      scale: scale,
      child: Padding(
        padding: EdgeInsets.only(left: 32 * scale, top: 26 * scale),
        child: SizedBox(
          height: 40 * scale,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            cursorColor: _loginOutline,
            style: _loginTextStyle(
              fontSize: 29,
              lineHeight: 38,
              color: _loginCodeText,
              scale: scale,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: '验证码',
              hintStyle: _loginTextStyle(
                fontSize: 29,
                lineHeight: 38,
                color: _loginCodeText,
                scale: scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFieldShell extends StatelessWidget {
  const _LoginFieldShell({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E1DD).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: scale,
        ),
      ),
      child: child,
    );
  }
}

class _RequestCodeButton extends StatelessWidget {
  const _RequestCodeButton({
    required this.scale,
    required this.busy,
    required this.canRequestCode,
    required this.label,
    required this.onRequestCode,
  });

  final double scale;
  final bool busy;
  final bool canRequestCode;
  final String label;
  final VoidCallback onRequestCode;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: canRequestCode ? onRequestCode : null,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _loginMutedText;
          }
          return _loginOutline;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          return _loginOutline.withValues(alpha: 0.08);
        }),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? _loginIconColor
                : _loginOutline,
            width: 2 * scale,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _loginDisabledControl.withValues(alpha: 0.44);
          }
          return Colors.white.withValues(alpha: 0.12);
        }),
        textStyle: WidgetStateProperty.all(
          _loginTextStyle(
            fontSize: 29,
            lineHeight: 38,
            fontWeight: FontWeight.w600,
            color: _loginOutline,
            scale: scale,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6 * scale),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(busy ? '处理中' : label),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.scale,
    required this.busy,
    required this.canLogin,
    required this.onLogin,
  });

  final double scale;
  final bool busy;
  final bool canLogin;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: canLogin ? onLogin : null,
      style: ButtonStyle(
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.all(_loginAccent),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        overlayColor: WidgetStateProperty.all(
          Colors.white.withValues(alpha: 0.10),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          _loginTextStyle(
            fontSize: 29,
            lineHeight: 38,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            scale: scale,
          ),
        ),
      ),
      child: Text(busy ? '登录中' : '登录'),
    );
  }
}

class _LoginFeedbackText extends StatelessWidget {
  const _LoginFeedbackText({
    required this.scale,
    required this.statusText,
    required this.errorText,
  });

  final double scale;
  final String? statusText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final text = errorText ?? statusText;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _loginTextStyle(
        fontSize: 18,
        lineHeight: 24,
        color: errorText == null ? _loginBodyText : Colors.red.shade700,
        scale: scale,
      ),
    );
  }
}

class _ScaledPositioned extends StatelessWidget {
  const _ScaledPositioned({
    required this.scale,
    required this.originX,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.child,
  });

  final double scale;
  final double originX;
  final double left;
  final double top;
  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: originX + left * scale,
      top: top * scale,
      width: width * scale,
      height: height * scale,
      child: child,
    );
  }
}

TextStyle _loginTextStyle({
  required double fontSize,
  required double lineHeight,
  required Color color,
  required double scale,
  FontWeight fontWeight = FontWeight.w400,
}) {
  return TextStyle(
    fontFamily: 'PingFang SC',
    fontSize: fontSize * scale,
    height: lineHeight / fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: 0,
  );
}

StrutStyle _loginStrut(double fontSize, double lineHeight, double scale) {
  return StrutStyle(
    fontFamily: 'PingFang SC',
    fontSize: fontSize * scale,
    height: lineHeight / fontSize,
    forceStrutHeight: true,
  );
}
