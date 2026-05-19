import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/external_import_repository.dart';
import '../../data/repositories/external_work_record_repository.dart';
import '../../features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart';
import '../../features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart';
import '../../features/timing/state/timing_external_work_store.dart';

/// External-work composition slice: import preview and confirm use cases.
class ExternalWorkProviders {
  ExternalWorkProviders._({
    required this.timingExternalWorkStore,
    required this.providers,
  });

  final TimingExternalWorkStore timingExternalWorkStore;
  final List<SingleChildWidget> providers;

  factory ExternalWorkProviders.build() {
    final importRepository = SqfliteExternalImportRepository();
    final recordRepository = SqfliteExternalWorkRecordRepository();
    final timingExternalWorkStore = TimingExternalWorkStore(
      importRepository: importRepository,
      recordRepository: recordRepository,
    );
    const prepareImportPreview = PrepareExternalWorkImportPreviewUseCase();
    const confirmImport = ConfirmExternalWorkImportUseCase();

    return ExternalWorkProviders._(
      timingExternalWorkStore: timingExternalWorkStore,
      providers: [
        Provider<ExternalImportRepository>.value(value: importRepository),
        Provider<ExternalWorkRecordRepository>.value(value: recordRepository),
        ChangeNotifierProvider<TimingExternalWorkStore>.value(
          value: timingExternalWorkStore,
        ),
        Provider<ExternalWorkImportPreviewPreparer>.value(
          value: prepareImportPreview,
        ),
        Provider<ExternalWorkImportConfirmer>.value(value: confirmImport),
      ],
    );
  }
}
