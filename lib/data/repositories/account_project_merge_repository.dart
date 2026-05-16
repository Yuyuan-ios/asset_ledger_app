import '../db/database.dart';
import '../models/account_project_merge_group.dart';
import '../models/account_project_merge_group_with_members.dart';
import '../models/account_project_merge_member.dart';

abstract class AccountProjectMergeRepository {
  Future<AccountProjectMergeGroupWithMembers> createGroupWithMembers({
    required AccountProjectMergeGroup group,
    required List<AccountProjectMergeMember> members,
  });

  Future<List<AccountProjectMergeGroup>> listActiveGroups();

  Future<List<AccountProjectMergeMember>> listActiveMembers();

  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers();

  Future<AccountProjectMergeGroup?> getGroupById(int groupId);

  Future<List<AccountProjectMergeMember>> listMembersByGroupId(int groupId);

  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectKeys(
    List<String> projectKeys,
  );

  Future<void> dissolveGroup({
    required int groupId,
    required String dissolvedAt,
  });
}

class SqfliteAccountProjectMergeRepository
    implements AccountProjectMergeRepository {
  static const String groupTable = 'account_project_merge_groups';
  static const String memberTable = 'account_project_merge_members';

  @override
  Future<AccountProjectMergeGroupWithMembers> createGroupWithMembers({
    required AccountProjectMergeGroup group,
    required List<AccountProjectMergeMember> members,
  }) async {
    return AppDatabase.inTransaction((txn) async {
      final groupId = await txn.insert(groupTable, group.toMap());
      final savedMembers = <AccountProjectMergeMember>[];

      for (final member in members) {
        final next = member.copyWith(groupId: groupId);
        final memberId = await txn.insert(memberTable, next.toMap());
        savedMembers.add(next.copyWith(id: memberId));
      }

      return AccountProjectMergeGroupWithMembers(
        group: group.copyWith(id: groupId),
        members: savedMembers,
      );
    });
  }

  @override
  Future<List<AccountProjectMergeGroup>> listActiveGroups() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      groupTable,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(AccountProjectMergeGroup.fromMap).toList();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembers() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      memberTable,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'group_id ASC, sort_order ASC, id ASC',
    );
    return rows.map(AccountProjectMergeMember.fromMap).toList();
  }

  @override
  Future<List<AccountProjectMergeGroupWithMembers>>
  listActiveGroupsWithMembers() async {
    final groups = await listActiveGroups();
    if (groups.isEmpty) return const [];

    final members = await listActiveMembers();
    final membersByGroup = <int, List<AccountProjectMergeMember>>{};
    for (final member in members) {
      membersByGroup.putIfAbsent(member.groupId, () => []).add(member);
    }

    return groups.map((group) {
      return AccountProjectMergeGroupWithMembers(
        group: group,
        members: membersByGroup[group.id] ?? const [],
      );
    }).toList();
  }

  @override
  Future<AccountProjectMergeGroup?> getGroupById(int groupId) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      groupTable,
      where: 'id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AccountProjectMergeGroup.fromMap(rows.single);
  }

  @override
  Future<List<AccountProjectMergeMember>> listMembersByGroupId(
    int groupId,
  ) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      memberTable,
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(AccountProjectMergeMember.fromMap).toList();
  }

  @override
  Future<List<AccountProjectMergeMember>> listActiveMembersByProjectKeys(
    List<String> projectKeys,
  ) async {
    final keys = projectKeys.map((key) => key.trim()).where((key) {
      return key.isNotEmpty;
    }).toList();
    if (keys.isEmpty) return const [];

    final db = await AppDatabase.database;
    final placeholders = List.filled(keys.length, '?').join(', ');
    final rows = await db.query(
      memberTable,
      where: 'is_active = ? AND project_key IN ($placeholders)',
      whereArgs: [1, ...keys],
      orderBy: 'group_id ASC, sort_order ASC, id ASC',
    );
    return rows.map(AccountProjectMergeMember.fromMap).toList();
  }

  @override
  Future<void> dissolveGroup({
    required int groupId,
    required String dissolvedAt,
  }) async {
    await AppDatabase.inTransaction<void>((txn) async {
      await txn.update(
        groupTable,
        {
          'is_active': 0,
          'dissolved_at': dissolvedAt,
          'updated_at': dissolvedAt,
        },
        where: 'id = ? AND is_active = ?',
        whereArgs: [groupId, 1],
      );
      await txn.update(
        memberTable,
        {'is_active': 0},
        where: 'group_id = ? AND is_active = ?',
        whereArgs: [groupId, 1],
      );
    });
  }
}
