import 'package:asset_ledger/app/phone_login_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone login requires agreement and persists session', (
    WidgetTester tester,
  ) async {
    final store = _MemoryPhoneLoginStore();
    final verificationService = _FakePhoneVerificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: store,
          verificationService: verificationService,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('手机号登录'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    final disabledRequestButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '获取验证码'),
    );
    expect(disabledRequestButton.onPressed, isNull);
    expect(
      disabledRequestButton.style?.foregroundColor?.resolve({
        WidgetState.disabled,
      }),
      isNot(disabledRequestButton.style?.foregroundColor?.resolve({})),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final enabledRequestButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '获取验证码'),
    );
    expect(enabledRequestButton.onPressed, isNotNull);

    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 1);
    expect(verificationService.sentPhone, '13800138000');
    expect(find.text('验证码已发送'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.pump();
    await tester.ensureVisible(find.text('登录'));
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(store.savedSession?.loggedIn, isTrue);
    expect(store.savedSession?.privacyAccepted, isTrue);
    expect(store.savedSession?.phoneNumber, '13800138000');
    expect(store.savedSession?.authToken, 'test-auth-token');
    expect(store.savedSession?.tokenExpiresAt, 2000000000);
  });

  testWidgets('skips login page when session is already valid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(
            initial: const PhoneLoginSession(
              loggedIn: true,
              privacyAccepted: true,
              phoneNumber: '13800138000',
              authToken: 'test-auth-token',
              tokenExpiresAt: 2000000000,
            ),
          ),
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('手机号登录'), findsNothing);
  });

  testWidgets('requesting code focuses code field after success', (
    WidgetTester tester,
  ) async {
    final verificationService = _FakePhoneVerificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          verificationService: verificationService,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 1);
    final codeField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(codeField.focusNode?.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('failed code request does not focus code field', (
    WidgetTester tester,
  ) async {
    final verificationService = _FakePhoneVerificationService(
      sendError: const PhoneVerificationException('验证码获取失败，请稍后重试'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          verificationService: verificationService,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 1);
    expect(find.text('重新获取(60s)'), findsNothing);
    final codeField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(codeField.focusNode?.hasFocus, isFalse);
  });

  testWidgets('phone and code fields expose autofill hints', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          verificationService: _FakePhoneVerificationService(),
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    final phoneField = tester.widget<TextField>(find.byType(TextField).at(0));
    final codeField = tester.widget<TextField>(find.byType(TextField).at(1));

    expect(phoneField.autofillHints, contains(AutofillHints.telephoneNumber));
    expect(codeField.autofillHints, contains(AutofillHints.oneTimeCode));
  });

  testWidgets('requesting code starts cooldown and disables request button', (
    WidgetTester tester,
  ) async {
    final verificationService = _FakePhoneVerificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          verificationService: verificationService,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 1);
    expect(find.text('重新获取(60s)'), findsOneWidget);
    final cooldownButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '重新获取(60s)'),
    );
    expect(cooldownButton.onPressed, isNull);

    await tester.tap(find.text('重新获取(60s)'));
    await tester.pump();

    expect(verificationService.sendCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('cooldown counts down and re-enables request button', (
    WidgetTester tester,
  ) async {
    final verificationService = _FakePhoneVerificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          verificationService: verificationService,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 1);
    expect(find.text('重新获取(60s)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('重新获取(59s)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));

    expect(find.text('重新获取(1s)'), findsNothing);
    final requestButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '获取验证码'),
    );
    expect(requestButton.onPressed, isNotNull);

    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 2);
    expect(find.text('重新获取(60s)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('failed request does not start cooldown', (
    WidgetTester tester,
  ) async {
    final verificationService = _FakePhoneVerificationService(
      sendError: const PhoneVerificationException('验证码获取失败，请稍后重试'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          verificationService: verificationService,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 1);
    expect(find.text('重新获取(60s)'), findsNothing);
    expect(find.text('验证码获取失败，请稍后重试'), findsOneWidget);
    final requestButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '获取验证码'),
    );
    expect(requestButton.onPressed, isNotNull);

    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 2);
    expect(find.text('重新获取(60s)'), findsNothing);
  });

  testWidgets('changing phone after code request clears requested code', (
    WidgetTester tester,
  ) async {
    final verificationService = _FakePhoneVerificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          verificationService: verificationService,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    expect(find.text('重新获取(60s)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.enterText(find.byType(TextField).at(0), '13900139000');
    await tester.pump();

    expect(find.text('重新获取(60s)'), findsNothing);
    final requestButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '获取验证码'),
    );
    expect(requestButton.onPressed, isNotNull);
    await tester.ensureVisible(find.text('登录'));
    final loginButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '登录'),
    );
    expect(loginButton.onPressed, isNull);

    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('legal links open privacy policy and terms pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginGate(
          store: _MemoryPhoneLoginStore(),
          privacyPageBuilder: () => const Scaffold(body: Text('privacy page')),
          termsPageBuilder: () => const Scaffold(body: Text('terms page')),
          child: const Text('home'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('《隐私政策》'));
    await tester.pumpAndSettle();

    expect(find.text('privacy page'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('《使用条款》'));
    await tester.pumpAndSettle();

    expect(find.text('terms page'), findsOneWidget);
  });

  testWidgets('keyboard inset keeps login layout size stable', (
    WidgetTester tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final store = _MemoryPhoneLoginStore();
    final verificationService = _FakePhoneVerificationService();

    Future<void> pumpLogin({required double keyboardInset}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: PhoneLoginGate(
              store: store,
              verificationService: verificationService,
              child: const Text('home'),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpLogin(keyboardInset: 0);

    final titleSize = tester.getSize(find.text('手机号登录'));
    final phoneFieldSize = tester.getSize(find.byType(TextField).at(0));
    final codeFieldSize = tester.getSize(find.byType(TextField).at(1));
    final loginButtonSize = tester.getSize(
      find.widgetWithText(ElevatedButton, '登录'),
    );

    await pumpLogin(keyboardInset: 320);
    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();

    expect(_sameSize(tester.getSize(find.text('手机号登录')), titleSize), isTrue);
    expect(
      _sameSize(tester.getSize(find.byType(TextField).at(0)), phoneFieldSize),
      isTrue,
    );
    expect(
      _sameSize(tester.getSize(find.byType(TextField).at(1)), codeFieldSize),
      isTrue,
    );
    expect(
      _sameSize(
        tester.getSize(find.widgetWithText(ElevatedButton, '登录')),
        loginButtonSize,
      ),
      isTrue,
    );

    final keyboardTop = tester.view.physicalSize.height - 320;
    final phoneFieldBottom = tester
        .getBottomLeft(find.byType(TextField).at(0))
        .dy;
    expect(phoneFieldBottom, lessThan(keyboardTop));

    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();

    final codeFieldBottom = tester
        .getBottomLeft(find.byType(TextField).at(1))
        .dy;
    expect(codeFieldBottom, lessThan(keyboardTop));
  });
}

bool _sameSize(Size actual, Size expected) {
  const epsilon = 0.001;
  return (actual.width - expected.width).abs() <= epsilon &&
      (actual.height - expected.height).abs() <= epsilon;
}

class _MemoryPhoneLoginStore implements PhoneLoginStore {
  _MemoryPhoneLoginStore({PhoneLoginSession? initial})
    : _session =
          initial ??
          const PhoneLoginSession(loggedIn: false, privacyAccepted: false);

  PhoneLoginSession _session;
  PhoneLoginSession? savedSession;

  @override
  Future<PhoneLoginSession> read() async => _session;

  @override
  Future<void> save(PhoneLoginSession session) async {
    _session = session;
    savedSession = session;
  }
}

class _FakePhoneVerificationService implements PhoneVerificationService {
  _FakePhoneVerificationService({this.sendError});

  final Object? sendError;
  int sendCalls = 0;
  String? sentPhone;

  @override
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber) async {
    sendCalls++;
    final error = sendError;
    if (error != null) {
      throw error;
    }
    sentPhone = phoneNumber;
    return const PhoneVerificationSendResult(message: '验证码已发送');
  }

  @override
  Future<PhoneVerificationVerifyResult> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    if (phoneNumber == sentPhone && code == '123456') {
      return const PhoneVerificationVerifyResult(
        success: true,
        token: 'test-auth-token',
        expiresAt: 2000000000,
      );
    }
    return const PhoneVerificationVerifyResult(success: false);
  }
}
