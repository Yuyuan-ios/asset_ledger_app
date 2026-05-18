import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/timing_calculation_history_repository.dart';
import '../../data/repositories/timing_repository.dart';
import '../../data/services/project_resolver.dart';
import '../../features/timing/application/controllers/timing_action_controller.dart';
import '../../features/timing/state/timing_store.dart';

/// Timing composition slice: timing repository + store.
class TimingProviders {
  TimingProviders._({
    required this.timingRepository,
    required this.calculationHistoryRepository,
    required this.timingStore,
    required this.timingActionController,
    required this.providers,
  });

  final TimingRepository timingRepository;
  final TimingCalculationHistoryRepository calculationHistoryRepository;
  final TimingStore timingStore;
  final TimingActionController timingActionController;
  final List<SingleChildWidget> providers;

  factory TimingProviders.build({required ProjectResolver projectResolver}) {
    final timingRepository = SqfliteTimingRepository();
    final calculationHistoryRepository =
        SqfliteTimingCalculationHistoryRepository();
    final timingStore = TimingStore(timingRepository);
    final timingActionController = TimingActionController(
      calculationHistoryRepository: calculationHistoryRepository,
      projectResolver: projectResolver,
    );
    return TimingProviders._(
      timingRepository: timingRepository,
      calculationHistoryRepository: calculationHistoryRepository,
      timingStore: timingStore,
      timingActionController: timingActionController,
      providers: [
        Provider<TimingRepository>.value(value: timingRepository),
        Provider<TimingCalculationHistoryRepository>.value(
          value: calculationHistoryRepository,
        ),
        Provider<TimingActionController>.value(value: timingActionController),
        ChangeNotifierProvider<TimingStore>.value(value: timingStore),
      ],
    );
  }
}
