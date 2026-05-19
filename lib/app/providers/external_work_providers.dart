import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart';
import '../../features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart';

/// External-work composition slice: import preview and confirm use cases.
class ExternalWorkProviders {
  ExternalWorkProviders._({required this.providers});

  final List<SingleChildWidget> providers;

  factory ExternalWorkProviders.build() {
    const prepareImportPreview = PrepareExternalWorkImportPreviewUseCase();
    const confirmImport = ConfirmExternalWorkImportUseCase();

    return ExternalWorkProviders._(
      providers: [
        Provider<ExternalWorkImportPreviewPreparer>.value(
          value: prepareImportPreview,
        ),
        Provider<ExternalWorkImportConfirmer>.value(value: confirmImport),
      ],
    );
  }
}
