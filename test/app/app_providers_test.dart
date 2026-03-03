import 'package:asset_ledger/app/app_providers.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('AppProviders exposes repositories and reuses startup store instances', (
    WidgetTester tester,
  ) async {
    final bundle = AppProviders.build();

    late DeviceRepository deviceRepository;
    late TimingRepository timingRepository;
    late FuelRepository fuelRepository;
    late MaintenanceRepository maintenanceRepository;
    late AccountPaymentRepository accountPaymentRepository;
    late ProjectRateRepository projectRateRepository;
    late DeviceStore deviceStore;
    late TimingStore timingStore;
    late FuelStore fuelStore;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MultiProvider(
          providers: bundle.providers,
          child: Builder(
            builder: (context) {
              deviceRepository = context.read<DeviceRepository>();
              timingRepository = context.read<TimingRepository>();
              fuelRepository = context.read<FuelRepository>();
              maintenanceRepository = context.read<MaintenanceRepository>();
              accountPaymentRepository = context.read<AccountPaymentRepository>();
              projectRateRepository = context.read<ProjectRateRepository>();
              deviceStore = context.read<DeviceStore>();
              timingStore = context.read<TimingStore>();
              fuelStore = context.read<FuelStore>();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(deviceRepository, isA<DeviceRepository>());
    expect(timingRepository, isA<TimingRepository>());
    expect(fuelRepository, isA<FuelRepository>());
    expect(maintenanceRepository, isA<MaintenanceRepository>());
    expect(accountPaymentRepository, isA<AccountPaymentRepository>());
    expect(projectRateRepository, isA<ProjectRateRepository>());

    expect(identical(deviceStore, bundle.deviceStore), isTrue);
    expect(identical(timingStore, bundle.timingStore), isTrue);
    expect(identical(fuelStore, bundle.fuelStore), isTrue);
  });
}
