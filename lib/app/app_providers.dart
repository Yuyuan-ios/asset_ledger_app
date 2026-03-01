import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../features/account/state/account_controller.dart';
import '../features/account/state/account_payment_controller.dart';
import '../features/account/state/project_rate_controller.dart';
import '../features/device/state/device_controller.dart';
import '../features/fuel/state/fuel_controller.dart';
import '../features/maintenance/state/maintenance_controller.dart';
import '../features/timing/state/timing_controller.dart';

class AppProviders {
  static List<SingleChildWidget> build() {
    return [
      ChangeNotifierProvider<DeviceStore>(create: (_) => DeviceStore()),
      ChangeNotifierProvider<TimingStore>(create: (_) => TimingStore()),
      ChangeNotifierProvider<FuelStore>(create: (_) => FuelStore()),
      ChangeNotifierProvider<MaintenanceStore>(
        create: (_) => MaintenanceStore(),
      ),
      ChangeNotifierProvider<AccountPaymentStore>(
        create: (_) => AccountPaymentStore(),
      ),
      ChangeNotifierProvider<AccountStore>(create: (_) => AccountStore()),
      ChangeNotifierProvider<ProjectRateStore>(create: (_) => ProjectRateStore()),
    ];
  }
}
