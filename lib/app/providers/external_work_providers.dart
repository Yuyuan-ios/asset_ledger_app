import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../core/operations/operation_access_control.dart';
import '../../data/repositories/external_import_repository.dart';
import '../../data/repositories/external_work_record_repository.dart';
import '../../data/services/project_share_file_picker.dart';
import '../../data/share/jztshare/project_external_work_importer.dart';
import '../../features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart';
import '../../features/external_work/import_preview/use_cases/pick_external_work_share_file_use_case.dart';
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

  factory ExternalWorkProviders.build({ActorContext? actorContext}) {
    // R5.25-Hardening: thread the persisted owner ActorContext (from
    // AppIdentityService via IdentityProviders) into both the record
    // repository (link/unlink/delete enqueue) and the importer (batch create
    // enqueue). Preview path is read-only and does not need an actor.
    final actorProvider = actorContext == null ? null : () => actorContext;
    final importRepository = SqfliteExternalImportRepository();
    final recordRepository = SqfliteExternalWorkRecordRepository(
      actorProvider: actorProvider,
    );
    final timingExternalWorkStore = TimingExternalWorkStore(
      importRepository: importRepository,
      recordRepository: recordRepository,
    );
    const prepareImportPreview = PrepareExternalWorkImportPreviewUseCase();
    final confirmImport = ConfirmExternalWorkImportUseCase(
      importer: ProjectExternalWorkImporter(actorProvider: actorProvider),
    );
    const pickShareFile = PickExternalWorkShareFileUseCase(
      FilePickerProjectShareFilePicker(),
    );

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
        Provider<PickExternalWorkShareFileUseCase>.value(value: pickShareFile),
      ],
    );
  }
}
