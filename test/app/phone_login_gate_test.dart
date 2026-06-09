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
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(verificationService.sendCalls, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
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
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.enterText(find.byType(TextField).at(0), '13900139000');
    await tester.pump();

    await tester.ensureVisible(find.text('登录'));
    final loginButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '登录'),
    );
    expect(loginButton.onPressed, isNull);
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
  int sendCalls = 0;
  String? sentPhone;

  @override
  Future<PhoneVerificationSendResult> sendCode(String phoneNumber) async {
    sendCalls++;
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
