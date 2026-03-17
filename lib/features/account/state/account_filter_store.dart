import 'package:flutter/foundation.dart';

import '../model/account_view_model.dart';

class AccountFilterStore extends ChangeNotifier {
  String _projectFilterKeyword = '';

  String get projectFilterKeyword => _projectFilterKeyword;

  void setProjectFilterKeyword(String value) {
    final nextValue = value.trim();
    if (nextValue == _projectFilterKeyword) return;
    _projectFilterKeyword = nextValue;
    notifyListeners();
  }

  void clearProjectFilter() {
    if (_projectFilterKeyword.isEmpty) return;
    _projectFilterKeyword = '';
    notifyListeners();
  }

  List<AccountProjectVM> filterProjects(List<AccountProjectVM> projects) {
    final query = _projectFilterKeyword.toLowerCase();
    if (query.isEmpty) return projects;

    return projects
        .where((project) => project.displayName.toLowerCase().contains(query))
        .toList();
  }
}
