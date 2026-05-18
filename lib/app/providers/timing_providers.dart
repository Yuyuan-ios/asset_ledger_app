import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/timing_repository.dart';
import '../../features/timing/state/timing_store.dart';

/// Timing composition slice: timing repository + store.
class TimingProviders {
  TimingProviders._({
    required this.timingRepository,
    required this.timingStore,
    required this.providers,
  });

  final TimingRepository timingRepository;
  final TimingStore timingStore;
  final List<SingleChildWidget> providers;

  factory TimingProviders.build() {
    final timingRepository = SqfliteTimingRepository();
    final timingStore = TimingStore(timingRepository);
    return TimingProviders._(
      timingRepository: timingRepository,
      timingStore: timingStore,
      providers: [
        Provider<TimingRepository>.value(value: timingRepository),
        ChangeNotifierProvider<TimingStore>.value(value: timingStore),
      ],
    );
  }
}
