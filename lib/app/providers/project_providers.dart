import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/project_repository.dart';
import '../../data/services/project_resolver.dart';

/// Project identity composition slice: project repository + resolver.
class ProjectProviders {
  ProjectProviders._({
    required this.projectRepository,
    required this.projectResolver,
    required this.providers,
  });

  final ProjectRepository projectRepository;
  final ProjectResolver projectResolver;
  final List<SingleChildWidget> providers;

  factory ProjectProviders.build() {
    final projectRepository = SqfliteProjectRepository();
    final projectResolver = ProjectResolver(
      projectRepository: projectRepository,
    );
    return ProjectProviders._(
      projectRepository: projectRepository,
      projectResolver: projectResolver,
      providers: [
        Provider<ProjectRepository>.value(value: projectRepository),
        Provider<ProjectResolver>.value(value: projectResolver),
      ],
    );
  }
}
