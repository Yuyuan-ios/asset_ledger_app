import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/buttons/app_primary_button.dart';
import '../core/foundation/typography.dart';
import '../features/device/view/privacy_page.dart';
import '../features/device/view/terms_page.dart';
import '../patterns/layout/phone_page_layout.dart';
import '../tokens/mapper/core_tokens.dart';

typedef LegalPageBuilder = Widget Function();

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
        backgroundColor: AppColors.scaffoldBg,
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
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: 18,
              maxWideGain: 18,
            );
            final maxWidth = PhonePageLayout.resolveMaxContentWidth(
              constraints.maxWidth - horizontalPadding * 2,
              baseWidth: PhonePageLayout.designWidth,
            );

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    28,
                    horizontalPadding,
                    32,
                  ),
                  children: [
                    _LoginHeader(),
                    const SizedBox(height: 28),
                    _LoginFormPanel(
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryActionCapsule,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.phone_iphone, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 18),
        Text(
          '手机号登录',
          style: AppTypography.pageTitle(
            context,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '登录后用于识别本机账本。继续前请阅读并同意隐私政策和使用条款。',
          style: AppTypography.bodySecondary(
            context,
            fontSize: 15,
            height: 1.45,
            color: SheetColors.hint,
          ),
        ),
      ],
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LoginTextField(
            controller: phoneController,
            label: '手机号',
            hintText: '请输入 11 位手机号',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LoginTextField(
                  controller: codeController,
                  label: '验证码',
                  hintText: '6 位验证码',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: canRequestCode ? onRequestCode : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryActionCapsule,
                    side: const BorderSide(
                      color: AppColors.primaryActionCapsule,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(busy ? '处理中' : '获取验证码'),
                ),
              ),
            ],
          ),
          if (statusText != null) ...[
            const SizedBox(height: 10),
            Text(
              statusText!,
              style: AppTypography.caption(
                context,
                height: 1.35,
                color: SheetColors.hint,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _AgreementRow(
            accepted: agreementAccepted,
            onChanged: onAgreementChanged,
            onOpenPrivacyPolicy: onOpenPrivacyPolicy,
            onOpenTerms: onOpenTerms,
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              errorText!,
              style: AppTypography.caption(
                context,
                color: Colors.red.shade700,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: busy ? '登录中' : '登录',
            onPressed: canLogin ? onLogin : null,
          ),
        ],
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.keyboardType,
    required this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppTypography.body(context, color: SheetColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: SheetColors.fieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: _fieldBorder(),
        enabledBorder: _fieldBorder(),
        focusedBorder: _fieldBorder(color: AppColors.primaryActionCapsule),
      ),
    );
  }

  OutlineInputBorder _fieldBorder({Color color = SheetColors.fieldBorder}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.accepted,
    required this.onChanged,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTerms,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final normalStyle = AppTypography.caption(
      context,
      height: 1.35,
      color: SheetColors.textPrimary,
    );
    final linkStyle = AppTypography.caption(
      context,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryActionCapsule,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: accepted,
            activeColor: AppColors.primaryActionCapsule,
            onChanged: (value) => onChanged(value ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('我已阅读并同意', style: normalStyle),
              InkWell(
                onTap: onOpenPrivacyPolicy,
                child: Text('《隐私政策》', style: linkStyle),
              ),
              Text('和', style: normalStyle),
              InkWell(
                onTap: onOpenTerms,
                child: Text('《使用条款》', style: linkStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
