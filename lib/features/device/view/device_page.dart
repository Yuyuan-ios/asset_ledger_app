// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_environment.dart';
import '../../../app/sync_runtime.dart';
import '../../../app/phone_login_gate.dart';
import '../../../components/feedback/store_action_feedback_l10n.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../infrastructure/cloud/cloud_backup_gateway.dart';
import '../application/controllers/cloud_backup_controller.dart';
import '../application/controllers/local_backup_controller.dart';
import '../application/controllers/subscription_controller.dart';
import '../domain/entities/device.dart';
import '../domain/entities/local_backup_entities.dart';
import '../domain/entities/subscription.dart';
import '../../../features/account/state/account_payment_store.dart';
import '../../../features/account/state/account_store.dart';
import '../../../features/account/state/project_rate_store.dart';
import '../../../features/device/state/device_store.dart';
import '../../../features/fuel/state/fuel_store.dart';
import '../../../features/maintenance/state/maintenance_store.dart';
import '../../../features/timing/state/timing_store.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/pro_gate.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../domain/services/device_business_ledger.dart';
import '../domain/services/lifecycle_payback_calculator.dart';
import 'lifecycle_amount_sheet.dart';
import 'device_page_actions.dart';
import 'device_page_content.dart';
import 'device_page_sections.dart';
import 'device_account_center_page.dart';
import 'device_account_status.dart';
import 'device_backup_widgets.dart';
import 'device_subpage_route.dart';
import '../../sync/sync_conflict_review_page.dart';

// =====================================================================
// ============================== 二、DevicePage：设备页入口 ==============================
// =====================================================================

part 'dialogs/device_backup_dialogs.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

enum _ManualBackupAction { backupOnly, backupAndShare }

// =====================================================================
// ============================== 三、State：仅做 UI 状态与交互 ==============================
// =====================================================================

class _DevicePageState extends State<DevicePage> with _DeviceBackupDialogs {
  static const _phoneLoginStore = SharedPreferencesPhoneLoginStore();
  static const _subscriptionController = SubscriptionController();
  static const _deviceBusinessLedgerUseCase = DeviceBusinessLedgerUseCase();

  @override
  bool _isExportingBackup = false;
  @override
  bool _isCloudBackupBusy = false;
  PhoneLoginSession _loginSession = const PhoneLoginSession.unauthenticated();
  final Map<int, LifecyclePaybackAmounts> _lifecyclePaybackAmountsByDeviceId =
      {};

  @override
  LocalBackupController get _localBackupController =>
      context.read<LocalBackupController>();

  @override
  CloudBackupController get _cloudBackupController =>
      context.read<CloudBackupController>();

  @override
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _subscriptionController.notifier.addListener(_handleSubscriptionChanged);
    Future.microtask(() async {
      await _loadLoginSession();
      await _subscriptionController.init();
    });
  }

  @override
  void dispose() {
    _subscriptionController.notifier.removeListener(_handleSubscriptionChanged);
    super.dispose();
  }

  void _handleSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Future<PhoneLoginSession> _loadLoginSession() async {
    final session = await _phoneLoginStore.read();
    if (!mounted) return session;
    setState(() => _loginSession = session);
    return session;
  }

  // -------------------------------------------------------------------
  // 3.1 通用：提示消息（SnackBar）
  // -------------------------------------------------------------------
  @override
  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  @override
  Future<void> _showAccountSyncPlaceholder({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.deviceDoneAction),
            ),
          ],
        );
      },
    );
  }

  // =====================================================================
  // ============================== 四、新增/编辑弹窗（同一套表单复用） ==============================
  // =====================================================================
  Future<void> _openDeviceDialog({
    Device? device,
    String? initialBrand,
    EquipmentType? initialEquipmentType,
  }) async {
    await DevicePageActions.openDeviceDialog(
      context: context,
      store: context.read<DeviceStore>(),
      isMounted: () => mounted,
      toast: _toast,
      device: device,
      initialBrand: initialBrand,
      initialEquipmentType: initialEquipmentType,
    );
  }

  Future<void> _openAddDeviceFlow() async {
    await DevicePageActions.openAddDeviceFlow(
      context: context,
      store: context.read<DeviceStore>(),
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _retryLoad() async {
    await DevicePageActions.retryLoad(context.read<DeviceStore>());
  }

  Future<void> _openRateApp() async {
    await DevicePageActions.openRateApp(
      l10n: AppLocalizations.of(context),
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _openTermsPage() async {
    await DevicePageActions.openTermsPage(context);
  }

  Future<void> _openPrivacyPage() async {
    await DevicePageActions.openPrivacyPage(context);
  }

  Future<void> _openContactSupport() async {
    await DevicePageActions.openSupportPage(
      l10n: AppLocalizations.of(context),
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  @override
  Future<void> _openUpgradePage({
    SubscriptionProductKind initialPlan = SubscriptionProductKind.pro,
  }) async {
    await DevicePageActions.openUpgradePage(context, initialPlan: initialPlan);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openMaxUpgradePage() {
    return _openUpgradePage(initialPlan: SubscriptionProductKind.max);
  }

  Future<void> _openLifecyclePaybackSheet(DeviceBusinessLedger ledger) async {
    final store = context.read<DeviceStore>();
    final current =
        _lifecyclePaybackAmountsByDeviceId[ledger.deviceId] ??
        _lifecyclePaybackAmountsFromDevice(store.tryFindById(ledger.deviceId));
    final result = await showLifecycleAmountSheet(
      context: context,
      deviceName: ledger.deviceName,
      netReceivedFen: lifecyclePaybackNetReceivedFen(ledger),
      initialCostFen: current?.initialCostFen,
      estimatedResidualFen: current?.estimatedResidualFen,
    );
    if (!mounted || result == null) return;
    try {
      await store.updateLifecyclePaybackAmounts(
        deviceId: ledger.deviceId,
        lifecycleInitialCostFen: result.initialCostFen,
        lifecycleEstimatedResidualFen: result.estimatedResidualFen,
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        store.failure == null
            ? _l10n.deviceSaveFailureDataNotSaved
            : localizeStoreActionFeedback(
                _l10n,
                storeActionFeedback(store, action: StoreActionKind.save),
              ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _lifecyclePaybackAmountsByDeviceId[ledger.deviceId] = result;
    });
  }

  LifecyclePaybackAmounts? _lifecyclePaybackAmountsFor(
    DeviceBusinessLedger ledger,
    Map<int, Device> devicesById,
  ) {
    return _lifecyclePaybackAmountsByDeviceId[ledger.deviceId] ??
        _lifecyclePaybackAmountsFromDevice(devicesById[ledger.deviceId]);
  }

  LifecyclePaybackAmounts? _lifecyclePaybackAmountsFromDevice(Device? device) {
    if (device == null) return null;
    final initialCostFen = device.lifecycleInitialCostFen;
    final estimatedResidualFen = device.lifecycleEstimatedResidualFen;
    if (initialCostFen == null && estimatedResidualFen == null) return null;
    return LifecyclePaybackAmounts(
      initialCostFen: initialCostFen,
      estimatedResidualFen: estimatedResidualFen,
    );
  }

  Future<SubscriptionRestoreOutcome> _restorePurchases() {
    return _subscriptionController.restorePurchases();
  }

  @override
  Future<PhoneLoginSession> _openPhoneLogin() async {
    if (RuntimeGate.shouldBypassAuth) {
      return const PhoneLoginSession.skipped(privacyAccepted: true);
    }

    final initialSession = _loginSession;
    final navigator = Navigator.of(context, rootNavigator: true);
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PhoneLoginPage(
          verificationService: const ReviewAccessPhoneVerificationService(),
          reviewAccessPolicy: RuntimeGate.reviewAccessPolicy,
          initialAgreementAccepted: initialSession.privacyAccepted,
          onLoggedIn:
              ({
                required String phoneNumber,
                required String authToken,
                required int? tokenExpiresAt,
              }) async {
                await _phoneLoginStore.save(
                  PhoneLoginSession(
                    loggedIn: true,
                    privacyAccepted: true,
                    phoneNumber: phoneNumber,
                    authToken: authToken,
                    tokenExpiresAt: tokenExpiresAt,
                  ),
                );
                RuntimeGate.resolveAccessForAccount(
                  accountIdentifier: phoneNumber,
                  isAuthenticated: true,
                  reviewAccessPolicy: RuntimeGate.reviewAccessPolicy,
                );
                if (navigator.mounted) navigator.pop();
              },
          onLoginSkipped: () async {
            await _phoneLoginStore.save(
              PhoneLoginSession.skipped(
                privacyAccepted: initialSession.privacyAccepted,
              ),
            );
            if (navigator.mounted) navigator.pop();
          },
          onOpenPrivacyPolicy: () => DevicePageActions.openPrivacyPage(context),
          onOpenTerms: () => DevicePageActions.openTermsPage(context),
        ),
      ),
    );
    return _loadLoginSession();
  }

  Future<void> _openAccountCenter() async {
    final syncRuntime = context.read<SyncRuntime?>();
    await Navigator.of(context).push<void>(
      deviceSubpageRoute<void>(
        builder: (context) => AccountCenterPage(
          loginSession: _loginSession,
          subscriptionListenable: _subscriptionController.notifier,
          onOpenPhoneLogin: _openPhoneLogin,
          onOpenUpgradePage: () => _openUpgradePage(),
          onOpenMaxUpgradePage: _openMaxUpgradePage,
          onRestorePurchases: _restorePurchases,
          onOpenLocalBackup: _openLocalBackup,
          onOpenLocalRestore: _openLocalRestorePreview,
          onOpenSyncInfo: _openSyncInfoPlaceholder,
          onOpenCloudBackup: _openCloudBackup,
          onOpenCloudRestore: _openCloudRestore,
          onOpenSyncConflictReview: _openSyncConflictReview,
          syncConflictReviewAvailable: syncRuntime?.isAvailable ?? false,
          cloudBackupAvailable: _cloudBackupController.isAvailable,
          cloudBackupUnavailableMessage:
              _cloudBackupController.serverUnavailableMessage,
        ),
      ),
    );
    if (!mounted) return;
    await _loadLoginSession();
  }

  Future<void> _openSyncConflictReview() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SyncConflictReviewPage()),
    );
  }

  Future<void> _openSyncInfoPlaceholder() async {
    await _showAccountSyncPlaceholder(
      title: _l10n.deviceSyncInfoTitle,
      message: _l10n.deviceSyncInfoMessage,
    );
  }

  // =====================================================================
  // ============================== 五、UI 构建 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = context.watch<DeviceStore>();
    final timingStore = context.watch<TimingStore>();
    final paymentStore = context.watch<AccountPaymentStore>();
    final rateStore = context.watch<ProjectRateStore>();
    final accountStore = context.watch<AccountStore>();
    final activeDevices = store.activeDevices;
    final allDevices = store.allDevices;
    final devicesById = {
      for (final device in allDevices)
        if (device.id != null) device.id!: device,
    };
    final businessLedgers = _deviceBusinessLedgerUseCase.execute(
      timingRecords: timingStore.records,
      devices: allDevices,
      rates: rateStore.rates,
      payments: paymentStore.records,
      writeOffs: accountStore.writeOffs,
      activeMergeGroups: accountStore.activeMergeGroups,
      settledProjectIds: accountStore.settledProjectIds,
    );

    final sections = buildDevicePageSections(
      l10n: l10n,
      devices: activeDevices,
      handlers: DevicePageSectionHandlers(
        onOpenUpgradePage: () => _openUpgradePage(),
        onOpenAccountCenter: _openAccountCenter,
        accountCenterSubtitle: deviceAccountCenterSubtitle(
          l10n: l10n,
          session: _loginSession,
          subscription: _subscriptionController.snapshot,
        ),
        onOpenAddDeviceFlow: _openAddDeviceFlow,
        onOpenRateApp: _openRateApp,
        onOpenTermsPage: _openTermsPage,
        onOpenPrivacyPage: _openPrivacyPage,
        onOpenContact: _openContactSupport,
        onDeviceTap: (d) => _openDeviceDialog(device: d),
        onDeviceLongPress: (d) async {
          await DevicePageActions.deactivateDevice(
            context: context,
            store: context.read<DeviceStore>(),
            device: d,
            isMounted: () => mounted,
            toast: _toast,
          );
        },
        businessLedgers: businessLedgers,
        lifecyclePaybackAmountsFor: (ledger) =>
            _lifecyclePaybackAmountsFor(ledger, devicesById),
        onOpenLifecyclePayback: _openLifecyclePaybackSheet,
      ),
    );

    return DevicePageContent(
      errorMessage: store.failure == null
          ? null
          : localizeStoreActionFeedback(
              l10n,
              storeActionFeedback(store, action: StoreActionKind.read),
            ),
      isLoading: store.loading,
      onRetryLoad: _retryLoad,
      sections: sections,
    );
  }
}
