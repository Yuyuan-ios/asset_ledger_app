import 'account_project_merge_group.dart';
import 'account_project_merge_member.dart';

class AccountProjectMergeGroupWithMembers {
  final AccountProjectMergeGroup group;
  final List<AccountProjectMergeMember> members;

  const AccountProjectMergeGroupWithMembers({
    required this.group,
    required this.members,
  });
}
