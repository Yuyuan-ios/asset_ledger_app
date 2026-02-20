// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 Flutter 原生库
import 'package:flutter/material.dart';

// 1.2 第三方状态管理库：Provider
import 'package:provider/provider.dart';

// 1.3 项目内：页面
import 'presentation/pages/timing/timing_page.dart';
import 'pages/device_page.dart';
import 'store/fuel_store.dart';
import 'pages/fuel_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/account_page.dart';

// 1.4 项目内：状态层 Store
import 'store/device_store.dart';
import 'store/timing_store.dart';
import 'store/maintenance_store.dart';
import 'store/account_payment_store.dart';
import 'store/project_rate_store.dart';
import 'store/account_store.dart';

// 1.5 项目内：Service（订阅能力缓存）
import 'services/subscription_service.dart';

import 'presentation/theme/app_theme.dart';

// ✅ Figma 风格 TabBar（代替原生 BottomNavigationBar，避免出现双底栏）
import 'presentation/pages/timing/widgets/component_tab_bar.dart';

// =====================================================================
// ============================== 二、应用入口 main() ==============================
// =====================================================================

Future<void> main() async {
  // -------------------------------------------------------------------
  // 2.1 确保 Flutter 引擎已初始化（否则 path_provider / IAP 等可能报错）
  // -------------------------------------------------------------------
  WidgetsFlutterBinding.ensureInitialized();

  SubscriptionService.setPlanForDebug(Plan.pro);

  // -------------------------------------------------------------------
  // 2.2 Step 10-7：启动时刷新订阅缓存（让 ProGate 同步读到正确值）
  //
  // 关键点：
  // - ProGate 只读 SubscriptionService.proCached（同步）
  // - 所以我们必须在 runApp 前，把缓存 refresh 一次
  //
  // 当前阶段：
  // - refresh() 只是把手动 plan 同步到 _proCached
  // 未来接 IAP：
  // - refresh() 内会读取真实订阅状态再写入 _proCached
  // -------------------------------------------------------------------
  await SubscriptionService.refresh();

  // -------------------------------------------------------------------
  // 2.3 用 MultiProvider 在应用最外层注入所有 Store
  //
  // 注意：
  // - 这里“只负责创建 Store”，不负责触发 loadAll()
  // - loadAll() 会 notifyListeners()，若在 create 阶段触发，少数情况下会引起构建时序问题
  // -------------------------------------------------------------------
  runApp(
    MultiProvider(
      providers: [
        // 2.4 DeviceStore：设备相关状态（devices 列表、增删改、error/loading 等）
        ChangeNotifierProvider(create: (_) => DeviceStore()),

        // 2.5 TimingStore：计时记录相关状态（records 列表、save/delete/load 等）
        ChangeNotifierProvider(create: (_) => TimingStore()),

        // 2.6 FuelStore
        ChangeNotifierProvider(create: (_) => FuelStore()),

        ChangeNotifierProvider(create: (_) => MaintenanceStore()),

        ChangeNotifierProvider(create: (_) => AccountPaymentStore()),

        ChangeNotifierProvider(create: (_) => AccountStore()),

        ChangeNotifierProvider(create: (_) => ProjectRateStore()),
      ],
      child: const AssetLedgerApp(),
    ),
  );
}

// =====================================================================
// ============================== 三、App 根组件（MaterialApp）==============================
// =====================================================================

class AssetLedgerApp extends StatelessWidget {
  const AssetLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asset Ledger',
      debugShowCheckedModeBanner: false,

      // ✅ Step DS-2：全局 Theme 统一从 AppTheme 来
      theme: AppTheme.light(),

      home: const MainPage(),
    );
  }
}

// =====================================================================
// ============================== 四、主页：底部导航壳（UI层）==============================
// =====================================================================

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // -------------------------------------------------------------------
  // 4.1 当前 Tab 下标
  // -------------------------------------------------------------------
  int _currentIndex = 0;

  // -------------------------------------------------------------------
  // 4.2 各 Tab 页面
  // -------------------------------------------------------------------
  final List<Widget> _pages = const [
    TimingPage(),
    FuelPage(),
    AccountPage(),
    MaintenancePage(),
    DevicePage(),
  ];

  // -------------------------------------------------------------------
  // 4.3 生命周期：initState
  //
  // 目标：应用启动后“统一触发各 Store 的首次加载”（只做一次）
  // -------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // ① 先加载 devices（TimingPage 下拉框依赖）
      await context.read<DeviceStore>().loadAll();

      // ② 再加载 timing_records
      await context.read<TimingStore>().loadAll();

      await context.read<FuelStore>().loadAll(); // ✅ 新增
    });
  }

  // -------------------------------------------------------------------
  // 4.4 主 build：只拼 UI
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: ComponentTabBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
