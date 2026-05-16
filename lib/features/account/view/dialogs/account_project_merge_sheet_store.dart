import 'package:flutter/foundation.dart';

import 'account_project_merge_sheet_data.dart';

class MergeProjectSheetStore extends ChangeNotifier {
  MergeProjectSheetStore({required this.groups});

  final List<MergeProjectSheetContactGroup> groups;
  final Set<String> _selectedProjectKeys = <String>{};

  Set<String> get selectedProjectKeys => Set.unmodifiable(_selectedProjectKeys);
  String? _selectedContact;
  String? get selectedContact => _selectedContact;
  bool get canConfirm => _selectedProjectKeys.length >= 2;

  void toggleProject(String projectKey, String contact) {
    final normalizedContact = contact.trim();
    if (normalizedContact.isEmpty) return;

    final allowedContact = _contactByUnmergedProjectKey[projectKey];
    if (allowedContact == null || allowedContact != normalizedContact) return;
    if (_mergedProjectKeys.contains(projectKey)) return;

    if (_selectedContact != null && _selectedContact != normalizedContact) {
      _selectedProjectKeys.clear();
    }
    _selectedContact = normalizedContact;

    if (!_selectedProjectKeys.add(projectKey)) {
      _selectedProjectKeys.remove(projectKey);
      if (_selectedProjectKeys.isEmpty) {
        _selectedContact = null;
      }
    }

    notifyListeners();
  }

  Map<String, String> get _contactByUnmergedProjectKey {
    return {
      for (final group in groups)
        for (final item in group.unmergedItems) item.projectKey: group.contact,
    };
  }

  Set<String> get _mergedProjectKeys {
    return {
      for (final group in groups)
        for (final item in group.mergedItems) item.projectKey,
    };
  }
}
