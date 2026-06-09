import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/device/view/privacy_page.dart';
import '../features/device/view/terms_page.dart';

typedef LegalPageBuilder = Widget Function();

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

class PhoneLoginSession {
  const PhoneLoginSession({
    required this.loggedIn,
    required this.privacyAccepted,
    this.phoneNumber,
    this.authToken,
    this.tokenExpiresAt,
  });

  final bool loggedIn;
  final bool privacyAccepted;
  final String? phoneNumber;
  final String? authToken;
  final int? tokenExpiresAt;
}

abstract class PhoneLoginStore {
  Future<PhoneLoginSession> read();

  Future<void> save(PhoneLoginSession session);
}

class SharedPreferencesPhoneLoginStore implements PhoneLoginStore {
  const SharedPreferencesPhoneLoginStore();

  static const String loggedInKey = 'app.phoneLogin.loggedIn.v1';
  static const String phoneNumberKey = 'app.phoneLogin.phoneNumber.v1';
  static const String authTokenKey = 'app.phoneLogin.authToken.v1';
  static const String tokenExpiresAtKey = 'app.phoneLogin.tokenExpiresAt.v1';
  static const String privacyAcceptedKey = 'app.privacyNotice.acknowledged.v1';

  @override
  Future<PhoneLoginSession> read() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString(phoneNumberKey);
    final authToken = prefs.getString(authTokenKey);
    final tokenExpiresAt = prefs.getInt(tokenExpiresAtKey);
    final loggedIn = prefs.getBool(loggedInKey) ?? false;
    final privacyAccepted = prefs.getBool(privacyAcceptedKey) ?? false;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tokenValid =
        authToken != null &&
        authToken.isNotEmpty &&
        (tokenExpiresAt == null || tokenExpiresAt > nowSeconds);

    return PhoneLoginSession(
      loggedIn:
          loggedIn &&
          phoneNumber != null &&
          phoneNumber.isNotEmpty &&
          tokenValid,
      privacyAccepted: privacyAccepted,
      phoneNumber: phoneNumber,
      authToken: authToken,
      tokenExpiresAt: tokenExpiresAt,
    );
  }

  @override
  Future<void> save(PhoneLoginSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedInKey, session.loggedIn);
    await prefs.setBool(privacyAcceptedKey, session.privacyAccepted);
    final phoneNumber = session.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      await prefs.remove(phoneNumberKey);
      await prefs.remove(authTokenKey);
      await prefs.remove(tokenExpiresAtKey);
    } else {
      await prefs.setString(phoneNumberKey, phoneNumber);
      final authToken = session.authToken;
      if (authToken == null || authToken.isEmpty) {
        await prefs.remove(authTokenKey);
      } else {
        await prefs.setString(authTokenKey, authToken);
      }
      final tokenExpiresAt = session.tokenExpiresAt;
      if (tokenExpiresAt == null) {
        await prefs.remove(tokenExpiresAtKey);
      } else {
        await prefs.setInt(tokenExpiresAtKey, tokenExpiresAt);
      }
    }
  }
}

class PhoneVerificationSendResult {
  const PhoneVerificationSendResult({required this.message});

  final String message;
}

abstract class PhoneVerificationService {
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber);

  Future<PhoneVerificationVerifyResult> verifyCode({
    required String phoneNumber,
    required String code,
  });
}

class PhoneVerificationVerifyResult {
  const PhoneVerificationVerifyResult({
    required this.success,
    this.token,
    this.expiresAt,
    this.message,
  });

  final bool success;
  final String? token;
  final int? expiresAt;
  final String? message;
}

class PhoneVerificationException implements Exception {
  const PhoneVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HttpPhoneVerificationService implements PhoneVerificationService {
  const HttpPhoneVerificationService({
    this.baseUrl = const String.fromEnvironment(
      'FLEET_LEDGER_API_BASE_URL',
      defaultValue: 'https://api.yuyuan.net.cn/fleet-ledger',
    ),
    this.timeout = const Duration(seconds: 10),
  });

  final String baseUrl;
  final Duration timeout;

  @override
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber) async {
    final body = await _postJson('/v1/auth/sms/request', <String, Object?>{
      'phone': phoneNumber,
    });
    final ok = body['ok'] == true;
    if (!ok) {
      throw PhoneVerificationException(
        _messageFromError(body['error']) ?? '验证码获取失败，请稍后重试',
      );
    }
    final seconds = body['expiresInSeconds'];
    final message = seconds is int && seconds > 0
        ? '验证码已发送，${(seconds / 60).round()} 分钟内有效。'
        : '验证码已发送';
    return PhoneVerificationSendResult(message: message);
  }

  @override
  Future<PhoneVerificationVerifyResult> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    final body = await _postJson('/v1/auth/sms/verify', <String, Object?>{
      'phone': phoneNumber,
      'code': code,
    });
    final ok = body['ok'] == true;
    if (!ok) {
      return PhoneVerificationVerifyResult(
        success: false,
        message: _messageFromError(body['error']) ?? '验证码不正确或已过期',
      );
    }

    final token = body['token'];
    final expiresAt = body['expiresAt'];
    if (token is! String || token.isEmpty) {
      throw const PhoneVerificationException('登录响应无效，请稍后重试');
    }
    return PhoneVerificationVerifyResult(
      success: true,
      token: token,
      expiresAt: expiresAt is int ? expiresAt : null,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> payload,
  ) async {
    final uri = _resolve(path);
    final encoded = jsonEncode(payload);
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.write(encoded);

      final response = await request.close().timeout(timeout);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final decoded = responseBody.isEmpty ? null : jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const PhoneVerificationException('服务响应格式无效，请稍后重试');
    } on PhoneVerificationException {
      rethrow;
    } on TimeoutException {
      throw const PhoneVerificationException('网络连接超时，请稍后重试');
    } on FormatException {
      throw const PhoneVerificationException('服务响应格式无效，请稍后重试');
    } on SocketException {
      throw const PhoneVerificationException('网络连接失败，请检查网络后重试');
    } finally {
      client.close(force: true);
    }
  }

  Uri _resolve(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  String? _messageFromError(Object? error) {
    final code = error is String ? error : null;
    return switch (code) {
      'invalid_phone' => '请输入有效的手机号',
      'sms_send_too_frequent' => '验证码发送过于频繁，请稍后再试',
      'dypns_access_key_not_configured' => '验证码服务暂未配置完成',
      'invalid_sms_code' => '验证码不正确或已过期',
      'sms_code_expired_or_missing' => '请先获取验证码',
      _ => null,
    };
  }
}

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
      body: LayoutBuilder(
        builder: (context, constraints) {
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
                    height: 36,
                    child: Text(
                      '登录后可用于云端备份和同步管理您的账本数据。',
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
                    top: 340,
                    width: 111,
                    height: 110,
                    child: CustomPaint(painter: _LoginClockMoneyPainter()),
                  ),
                  _ScaledPositioned(
                    scale: scale,
                    originX: originX,
                    left: 64,
                    top: 474,
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

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.scale,
    required this.phoneController,
    required this.codeController,
    required this.busy,
    required this.agreementAccepted,
    required this.canRequestCode,
    required this.canLogin,
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
  final bool busy;
  final bool agreementAccepted;
  final bool canRequestCode;
  final bool canLogin;
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
                  painter: const _AgreementCheckPainter(accepted: true),
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
  const _CodeTextField({required this.scale, required this.controller});

  final double scale;
  final TextEditingController controller;

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
            keyboardType: TextInputType.number,
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
    required this.onRequestCode,
  });

  final double scale;
  final bool busy;
  final bool canRequestCode;
  final VoidCallback onRequestCode;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: canRequestCode ? onRequestCode : null,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        foregroundColor: WidgetStateProperty.all(_loginOutline),
        overlayColor: WidgetStateProperty.all(
          _loginOutline.withValues(alpha: 0.08),
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: _loginOutline, width: 2 * scale),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        backgroundColor: WidgetStateProperty.all(
          Colors.white.withValues(alpha: 0.12),
        ),
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
      child: Text(busy ? '处理中' : '获取验证码'),
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

class _LoginBackgroundGeometryPainter extends CustomPainter {
  const _LoginBackgroundGeometryPainter(this.scale, this.originX);

  final double scale;
  final double originX;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _loginGeometryColor.withValues(alpha: 0.35)
      ..strokeWidth = scale
      ..style = PaintingStyle.stroke;

    void line(List<Offset> points) {
      final path = Path()
        ..moveTo(originX + points.first.dx * scale, points.first.dy * scale);
      for (final point in points.skip(1)) {
        path.lineTo(originX + point.dx * scale, point.dy * scale);
      }
      canvas.drawPath(path, paint);
    }

    line([const Offset(610, 560), const Offset(760, 456)]);
    line([const Offset(610, 645), const Offset(760, 542)]);
    line([const Offset(596, 744), const Offset(760, 634)]);
    line([
      const Offset(630, 565),
      const Offset(630, 927),
      const Offset(760, 1015),
    ]);
    line([
      const Offset(187, 934),
      const Offset(403, 788),
      const Offset(738, 1014),
      const Offset(522, 1160),
      const Offset(187, 934),
    ]);
    line([
      const Offset(244, 1017),
      const Offset(540, 817),
      const Offset(823, 1008),
    ]);
    line([
      const Offset(181, 1221),
      const Offset(475, 1022),
      const Offset(731, 1195),
      const Offset(300, 1486),
    ]);
    line([
      const Offset(302, 1323),
      const Offset(598, 1123),
      const Offset(826, 1277),
    ]);
    line([
      const Offset(408, 950),
      const Offset(726, 736),
      const Offset(948, 886),
    ]);
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundGeometryPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.originX != originX;
  }
}

class _LoginClockMoneyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 111;
    final sy = size.height / 110;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = _loginIconColor.withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = const Offset(56, 55);
    final rect = Rect.fromCircle(center: center, radius: 50);
    canvas.drawArc(rect, -math.pi * 1.22, math.pi * 1.86, false, paint);
    canvas.drawLine(const Offset(56, 17), const Offset(56, 55), paint);
    canvas.drawLine(const Offset(56, 55), const Offset(78, 70), paint);
    canvas.drawLine(const Offset(20, 55), const Offset(28, 55), paint);
    canvas.drawLine(const Offset(87, 55), const Offset(95, 55), paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: r'$',
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 42,
          height: 1,
          color: _loginIconColor.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(38, 68));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChinaFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rect = Offset.zero & size;
    paint.color = const Color(0xFFDE2910);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.04)),
      paint,
    );

    paint.color = const Color(0xFFFFDE00);
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.24, size.height * 0.32),
      size.height * 0.13,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.42, size.height * 0.18),
      size.height * 0.045,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.48, size.height * 0.32),
      size.height * 0.045,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.48, size.height * 0.48),
      size.height * 0.045,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.42, size.height * 0.62),
      size.height * 0.045,
      -math.pi / 2,
    );
  }

  void _drawStar(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
    double rotation,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i += 1) {
      final currentRadius = i.isEven ? radius : radius * 0.42;
      final angle = rotation + i * math.pi / 5;
      final point = Offset(
        center.dx + math.cos(angle) * currentRadius,
        center.dy + math.sin(angle) * currentRadius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AgreementCheckPainter extends CustomPainter {
  const _AgreementCheckPainter({required this.accepted});

  final bool accepted;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    if (accepted) {
      paint.color = const Color(0xFFC85D20);
      canvas.drawCircle(center, radius, paint);
      final checkPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3 * (size.width / 38)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(size.width * 0.28, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.68)
        ..lineTo(size.width * 0.74, size.height * 0.34);
      canvas.drawPath(path, checkPaint);
    } else {
      paint.color = Colors.white.withValues(alpha: 0.45);
      canvas.drawCircle(center, radius, paint);
      final borderPaint = Paint()
        ..color = const Color(0xFFC85D20).withValues(alpha: 0.55)
        ..strokeWidth = 2 * (size.width / 38)
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(
        center,
        radius - borderPaint.strokeWidth / 2,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgreementCheckPainter oldDelegate) {
    return oldDelegate.accepted != accepted;
  }
}
