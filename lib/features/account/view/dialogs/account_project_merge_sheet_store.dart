import 'package:flutter/foundation.dart';

import 'account_project_merge_sheet_data.dart';

class MergeProjectSheetStore extends ChangeNotifier {
  MergeProjectSheetStore({required this.groups});

  final List<MergeProjectSheetContactGroup> groups;
  final Set<String> _selectedProjectIds = <String>{};

  Set<String> get selectedProjectIds => Set.unmodifiable(_selectedProjectIds);
  Set<String> get selectedProjectKeys {
    final itemsById = _unmergedItemByProjectId;
    return {
      for (final projectId in _selectedProjectIds)
        if (itemsById[projectId] != null) itemsById[projectId]!.projectKey,
    };
  }

  String? _selectedContact;
  String? get selectedContact => _selectedContact;
  bool get canConfirm => _selectedProjectIds.length >= 2;

  void toggleProject(MergeProjectSheetItem item, String contact) {
    final normalizedContact = contact.trim();
    if (normalizedContact.isEmpty) return;

    final projectId = item.projectId.trim();
    if (projectId.isEmpty) return;

    final allowedContact = _contactByUnmergedProjectId[projectId];
    if (allowedContact == null || allowedContact != normalizedContact) return;
    if (_mergedProjectIds.contains(projectId)) return;

    if (_selectedContact != null && _selectedContact != normalizedContact) {
      _selectedProjectIds.clear();
    }
    _selectedContact = normalizedContact;

    if (!_selectedProjectIds.add(projectId)) {
      _selectedProjectIds.remove(projectId);
      if (_selectedProjectIds.isEmpty) {
        _selectedContact = null;
      }
    }

    notifyListeners();
  }

  Map<String, MergeProjectSheetItem> get _unmergedItemByProjectId {
    return {
      for (final group in groups)
        for (final item in group.unmergedItems) item.projectId: item,
    };
  }

  Map<String, String> get _contactByUnmergedProjectId {
    return {
      for (final group in groups)
        for (final item in group.unmergedItems) item.projectId: group.contact,
    };
  }

  Set<String> get _mergedProjectIds {
    return {
      for (final group in groups)
        for (final item in group.mergedItems) item.projectId,
    };
  }
}
