import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/device/view/privacy_page.dart';
import '../features/device/view/terms_page.dart';
import 'phone_login_store.dart';
import 'phone_verification_service.dart';

export 'phone_login_store.dart';
export 'phone_verification_service.dart';

part 'phone_login_widgets.dart';
part 'phone_login_painters.dart';

typedef LegalPageBuilder = Widget Function();

class PhoneLoginGate extends StatefulWidget {
  const PhoneLoginGate({
    super.key,
    required this.child,
    this.store = const SharedPreferencesPhoneLoginStore(),
    this.verificationService,
    this.privacyPageBuilder,
    this.termsPageBuilder,
  });

  final Widget child;
  final PhoneLoginStore store;
  final PhoneVerificationService? verificationService;
  final LegalPageBuilder? privacyPageBuilder;
  final LegalPageBuilder? termsPageBuilder;

  @override
  State<PhoneLoginGate> createState() => _PhoneLoginGateState();
}

class _PhoneLoginGateState extends State<PhoneLoginGate> {
  late final PhoneVerificationService _verificationService;
  PhoneLoginSession? _session;

  @override
  void initState() {
    super.initState();
    _verificationService =
        widget.verificationService ?? const HttpPhoneVerificationService();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await widget.store.read();
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _handleLoggedIn({
    required String phoneNumber,
    required String authToken,
    required int? tokenExpiresAt,
  }) async {
    final session = PhoneLoginSession(
      loggedIn: true,
      privacyAccepted: true,
      phoneNumber: phoneNumber,
      authToken: authToken,
      tokenExpiresAt: tokenExpiresAt,
    );
    await widget.store.save(session);
    if (!mounted) return;
    setState(() => _session = session);
  }

  void _openPrivacyPolicy(BuildContext context) {
    final builder = widget.privacyPageBuilder;
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => builder == null ? const PrivacyPage() : builder(),
      ),
    );
  }

  void _openTerms(BuildContext context) {
    final builder = widget.termsPageBuilder;
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => builder == null ? const TermsPage() : builder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(
        backgroundColor: _loginBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.loggedIn && session.privacyAccepted) {
      return widget.child;
    }

    return PhoneLoginPage(
      verificationService: _verificationService,
      initialAgreementAccepted: session.privacyAccepted,
      onLoggedIn: _handleLoggedIn,
      onOpenPrivacyPolicy: () => _openPrivacyPolicy(context),
      onOpenTerms: () => _openTerms(context),
    );
  }
}

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({
    super.key,
    required this.verificationService,
    required this.initialAgreementAccepted,
    required this.onLoggedIn,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTerms,
  });

  final PhoneVerificationService verificationService;
  final bool initialAgreementAccepted;
  final Future<void> Function({
    required String phoneNumber,
    required String authToken,
    required int? tokenExpiresAt,
  })
  onLoggedIn;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTerms;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _agreementAccepted = false;
  bool _codeRequested = false;
  bool _busy = false;
  String? _errorText;
  String? _statusText;
  String? _requestedPhoneNumber;

  bool get _phoneValid =>
      RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text.trim());

  bool get _codeValid =>
      RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim());

  bool get _canRequestCode => _phoneValid && _agreementAccepted && !_busy;

  bool get _canLogin =>
      _canRequestCode &&
      _codeRequested &&
      _requestedPhoneNumber == _phoneController.text.trim() &&
      _codeValid &&
      !_busy;

  @override
  void initState() {
    super.initState();
    _agreementAccepted = widget.initialAgreementAccepted;
    _phoneController.addListener(_handleInputChanged);
    _codeController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _phoneController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _codeController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    setState(() {
      _errorText = null;
      if (_codeRequested &&
          _requestedPhoneNumber != _phoneController.text.trim()) {
        _codeRequested = false;
        _requestedPhoneNumber = null;
        _statusText = null;
      }
    });
  }

  Future<void> _requestCode() async {
    if (!_agreementAccepted) {
      setState(() => _errorText = '请先阅读并同意隐私政策和使用条款');
      return;
    }
    if (!_phoneValid) {
      setState(() => _errorText = '请输入有效的手机号');
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
      _statusText = null;
    });
    late final PhoneVerificationSendResult result;
    try {
      result = await widget.verificationService.sendCode(
        _phoneController.text.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = error is PhoneVerificationException
            ? error.message
            : '验证码获取失败，请稍后重试';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeRequested = true;
      _requestedPhoneNumber = _phoneController.text.trim();
      _statusText = result.message;
    });
  }

  Future<void> _login() async {
    if (!_canLogin) return;

    setState(() {
      _busy = true;
      _errorText = null;
    });
    final phoneNumber = _phoneController.text.trim();
    late final PhoneVerificationVerifyResult result;
    try {
      result = await widget.verificationService.verifyCode(
        phoneNumber: phoneNumber,
        code: _codeController.text.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = error is PhoneVerificationException
            ? error.message
            : '登录失败，请稍后重试';
      });
      return;
    }
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _busy = false;
        _errorText = result.message ?? '验证码不正确，请重新输入';
      });
      return;
    }
    final token = result.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _busy = false;
        _errorText = '登录响应无效，请稍后重试';
      });
      return;
    }
    await widget.onLoggedIn(
      phoneNumber: phoneNumber,
      authToken: token,
      tokenExpiresAt: result.expiresAt,
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _loginBackground,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
          final widthScale = constraints.maxWidth / _loginBaseWidth;
          final viewportRatio = constraints.maxHeight / constraints.maxWidth;
          final baseRatio = _loginBaseHeight / _loginBaseWidth;
          final scale = viewportRatio < baseRatio * 0.75
              ? constraints.maxHeight / _loginBaseHeight
              : widthScale;
          final originX = (constraints.maxWidth - _loginBaseWidth * scale) / 2;
          final pageHeight = math.max(
            constraints.maxHeight,
            _loginBaseHeight * scale,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: SizedBox(
              width: constraints.maxWidth,
              height: pageHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LoginBackgroundGeometryPainter(scale, originX),
                    ),
                  ),
                  _ScaledPositioned(
                    scale: scale,
                    originX: originX,
                    left: 221,
                    top: 192,
                    width: 261,
                    height: 58,
                    child: Text(
                      '手机号登录',
                      textAlign: TextAlign.center,
                      strutStyle: _loginStrut(48, 58, scale),
                      style: _loginTextStyle(
                        fontSize: 48,
                        lineHeight: 58,
                        fontWeight: FontWeight.w600,
                        color: _loginTextPrimary,
                        scale: scale,
                      ),
                    ),
                  ),
                  _ScaledPositioned(
                    scale: scale,
                    originX: originX,
                    left: 92,
                    top: 269,
                    width: 520,
                    height: 72,
                    child: Text(
                      '登录后可用于云端备份和同步管理\n您的账本数据。',
                      textAlign: TextAlign.center,
                      strutStyle: _loginStrut(28, 36, scale),
                      style: _loginTextStyle(
                        fontSize: 28,
                        lineHeight: 36,
                        color: _loginTextSecondary,
                        scale: scale,
                      ),
                    ),
                  ),
                  _ScaledPositioned(
                    scale: scale,
                    originX: originX,
                    left: 296,
                    top: 376,
                    width: 111,
                    height: 110,
                    child: CustomPaint(painter: _LoginClockMoneyPainter()),
                  ),
                  _ScaledPositioned(
                    scale: scale,
                    originX: originX,
                    left: 64,
                    top: 510,
                    width: 576,
                    height: 469,
                    child: _LoginFormPanel(
                      scale: scale,
                      phoneController: _phoneController,
                      codeController: _codeController,
                      busy: _busy,
                      agreementAccepted: _agreementAccepted,
                      canRequestCode: _canRequestCode,
                      canLogin: _canLogin,
                      errorText: _errorText,
                      statusText: _statusText,
                      onAgreementChanged: (value) {
                        setState(() {
                          _agreementAccepted = value;
                          _errorText = null;
                        });
                      },
                      onRequestCode: _requestCode,
                      onLogin: _login,
                      onOpenPrivacyPolicy: widget.onOpenPrivacyPolicy,
                      onOpenTerms: widget.onOpenTerms,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
