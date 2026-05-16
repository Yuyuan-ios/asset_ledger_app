import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/use_cases/compute_account_summary_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComputeAccountSummaryUseCase', () {
    test('builds project summaries with correct sorting and money totals', () {
      const useCase = ComputeAccountSummaryUseCase();

      final result = useCase.execute(
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260103,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 102,
            hours: 2,
            income: 0,
          ),
          TimingRecord(
            id: 2,
            deviceId: 2,
            startDate: 20260105,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 200,
            endMeter: 203,
            hours: 3,
            income: 0,
          ),
          TimingRecord(
            id: 3,
            deviceId: 2,
            startDate: 20260106,
            contact: '李洋',
            site: '万达',
            type: TimingType.rent,
            startMeter: 203,
            endMeter: 203,
            hours: 0,
            income: 500,
          ),
          TimingRecord(
            id: 4,
            deviceId: 3,
            startDate: 20260110,
            contact: '张扬',
            site: '修文水厂',
            type: TimingType.hours,
            startMeter: 50,
            endMeter: 51,
            hours: 1,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'HITACHI 1#',
            brand: 'HITACHI',
            defaultUnitPrice: 120,
            baseMeterHours: 0,
          ),
          Device(
            id: 3,
            name: 'SUNWARD 3#',
            brand: 'SUNWARD',
            defaultUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: const [
          ProjectDeviceRate(projectKey: '李洋||万达', deviceId: 2, rate: 150),
        ],
        payments: const [
          AccountPayment(
            id: 1,
            projectKey: '李洋||万达',
            ymd: 20260120,
            amount: 200,
          ),
          AccountPayment(
            id: 2,
            projectKey: '李洋||万达',
            ymd: 20260118,
            amount: 100,
          ),
          AccountPayment(
            id: 3,
            projectKey: '张扬||修文水厂',
            ymd: 20260112,
            amount: 50,
          ),
        ],
      );

      expect(result.projects, hasLength(2));
      expect(result.projects.first.displayName, '张扬 + 修文水厂');
      expect(result.projects.last.displayName, '李洋 + 万达');

      final wanda = result.projects.last;
      expect(wanda.receivable, 1150);
      expect(wanda.received, 300);
      expect(wanda.remaining, 850);
      expect(wanda.ratio, closeTo(300 / 1150, 0.000001));
      expect(wanda.minRate, 100);
      expect(wanda.isMultiDevice, isTrue);
      expect(wanda.payments.map((payment) => payment.ymd).toList(), [
        20260120,
        20260118,
      ]);

      expect(result.totalReceivable, 1350);
      expect(result.totalReceived, 350);
      expect(result.totalRemaining, 1000);
      expect(result.totalRatio, closeTo(350 / 1350, 0.000001));

      expect(
        result.deviceReceivables.any(
          (device) => device.deviceId == 2 && device.amount == 950,
        ),
        isTrue,
      );
      expect(
        result.deviceReceivables.any(
          (device) => device.deviceId == 3 && device.amount == 200,
        ),
        isTrue,
      );
    });

    test('includes rent income in total receivable and device receivables', () {
      const useCase = ComputeAccountSummaryUseCase();

      final result = useCase.execute(
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260516,
            contact: '周亮',
            site: '成都',
            type: TimingType.rent,
            startMeter: 6180.7,
            endMeter: 6180.7,
            hours: 0,
            income: 22000,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'HITACHI 1#',
            brand: 'HITACHI',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        payments: const [],
      );

      expect(result.totalReceivable, 22000);
      expect(result.projects.single.receivable, 22000);
      expect(result.projects.single.hoursByDevice, isEmpty);
      expect(result.deviceReceivables.single.deviceId, 1);
      expect(result.deviceReceivables.single.amount, 22000);
    });

    test(
      'uses breaking unit price on project cards when a project only has breaking hours',
      () {
        const useCase = ComputeAccountSummaryUseCase();

        final result = useCase.execute(
          timingRecords: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260317,
              contact: '赵六',
              site: '尚义',
              type: TimingType.hours,
              startMeter: 2096,
              endMeter: 2105,
              hours: 9,
              income: 0,
              isBreaking: true,
            ),
          ],
          devices: const [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 120,
              breakingUnitPrice: 200,
              baseMeterHours: 0,
            ),
          ],
          rates: const [],
          payments: const [
            AccountPayment(
              id: 1,
              projectKey: '赵六||尚义',
              ymd: 20260317,
              amount: 1000,
            ),
          ],
        );

        expect(result.projects, hasLength(1));
        expect(result.projects.first.displayName, '赵六 + 尚义');
        expect(result.projects.first.minRate, 200);
        expect(result.projects.first.isMultiMode, isFalse);
      },
    );

    test(
      'applies active merge groups by hiding members and adding a merged VM',
      () {
        const useCase = ComputeAccountSummaryUseCase();

        final result = useCase.execute(
          timingRecords: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260312,
              contact: '李杰',
              site: '尚义',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 64.9,
              hours: 64.9,
              income: 0,
            ),
            TimingRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260323,
              contact: '李杰',
              site: '鲜滩',
              type: TimingType.hours,
              startMeter: 64.9,
              endMeter: 303.9,
              hours: 239,
              income: 0,
            ),
            TimingRecord(
              id: 3,
              deviceId: 2,
              startDate: 20260324,
              contact: '李杰',
              site: '鲜滩',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 20,
              hours: 20,
              income: 0,
            ),
            TimingRecord(
              id: 4,
              deviceId: 1,
              startDate: 20260401,
              contact: '李杰',
              site: '新村',
              type: TimingType.hours,
              startMeter: 303.9,
              endMeter: 313.9,
              hours: 10,
              income: 0,
            ),
          ],
          devices: const [
            Device(
              id: 1,
              name: 'HITACHI 1#',
              brand: 'HITACHI',
              defaultUnitPrice: 100,
              baseMeterHours: 0,
            ),
            Device(
              id: 2,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 180,
              baseMeterHours: 0,
            ),
          ],
          rates: const [],
          payments: const [
            AccountPayment(
              id: 1,
              projectKey: '李杰||尚义',
              ymd: 20260501,
              amount: 1490,
            ),
            AccountPayment(
              id: 2,
              projectKey: '李杰||鲜滩',
              ymd: 20260502,
              amount: 3510,
            ),
          ],
          activeMergeGroups: const [
            AccountProjectMergeGroupWithMembers(
              group: AccountProjectMergeGroup(
                id: 1,
                contact: '李杰',
                createdAt: '2026-05-15T00:00:00.000Z',
              ),
              members: [
                AccountProjectMergeMember(
                  id: 1,
                  groupId: 1,
                  projectKey: '李杰||尚义',
                  contact: '李杰',
                  site: '尚义',
                  sortOrder: 0,
                  createdAt: '2026-05-15T00:00:00.000Z',
                ),
                AccountProjectMergeMember(
                  id: 2,
                  groupId: 1,
                  projectKey: '李杰||鲜滩',
                  contact: '李杰',
                  site: '鲜滩',
                  sortOrder: 1,
                  createdAt: '2026-05-15T00:00:00.000Z',
                ),
              ],
            ),
          ],
        );

        expect(result.projects.map((project) => project.projectKey).toList(), [
          '李杰||新村',
          'merge:1',
        ]);

        final merged = result.projects.last;
        expect(merged.kind, AccountProjectKind.merged);
        expect(merged.mergeGroupId, 1);
        expect(merged.displayName, '李杰 + 合并2项目');
        expect(merged.memberProjectKeys, ['李杰||尚义', '李杰||鲜滩']);
        expect(merged.includedSites, ['尚义', '鲜滩']);
        expect(merged.includedSitesText, '含：尚义、鲜滩');
        expect(merged.minYmd, 20260312);
        expect(merged.deviceIds, [1, 2]);
        expect(merged.hoursByDevice[1], closeTo(303.9, 0.000001));
        expect(merged.hoursByDevice[2], 20);
        expect(merged.receivable, closeTo(33990, 0.000001));
        expect(merged.received, 5000);
        expect(merged.remaining, closeTo(28990, 0.000001));
        expect(merged.ratio, closeTo(5000 / 33990, 0.000001));
        expect(merged.minRate, 100);
        expect(merged.isMultiDevice, isTrue);
        expect(merged.payments.map((payment) => payment.id).toList(), [2, 1]);
      },
    );

    test(
      'keeps merged project receivable consistent when a member is rent-only',
      () {
        const useCase = ComputeAccountSummaryUseCase();

        final result = useCase.execute(
          timingRecords: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260501,
              contact: '周亮',
              site: '成都',
              type: TimingType.rent,
              startMeter: 6180.7,
              endMeter: 6180.7,
              hours: 0,
              income: 22000,
            ),
            TimingRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260502,
              contact: '周亮',
              site: '绵阳',
              type: TimingType.hours,
              startMeter: 6180.7,
              endMeter: 6190.7,
              hours: 10,
              income: 0,
            ),
          ],
          devices: const [
            Device(
              id: 1,
              name: 'HITACHI 1#',
              brand: 'HITACHI',
              defaultUnitPrice: 100,
              baseMeterHours: 0,
            ),
          ],
          rates: const [],
          payments: const [],
          activeMergeGroups: const [
            AccountProjectMergeGroupWithMembers(
              group: AccountProjectMergeGroup(
                id: 7,
                contact: '周亮',
                createdAt: '2026-05-16T00:00:00.000Z',
              ),
              members: [
                AccountProjectMergeMember(
                  groupId: 7,
                  projectKey: '周亮||成都',
                  contact: '周亮',
                  site: '成都',
                  sortOrder: 0,
                  createdAt: '2026-05-16T00:00:00.000Z',
                ),
                AccountProjectMergeMember(
                  groupId: 7,
                  projectKey: '周亮||绵阳',
                  contact: '周亮',
                  site: '绵阳',
                  sortOrder: 1,
                  createdAt: '2026-05-16T00:00:00.000Z',
                ),
              ],
            ),
          ],
        );

        final merged = result.projects.single;
        expect(merged.kind, AccountProjectKind.merged);
        expect(merged.receivable, 23000);
        expect(merged.rentIncomeTotal, 22000);
        expect(merged.hoursByDevice[1], 10);
        expect(result.totalReceivable, 23000);
        expect(result.deviceReceivables.single.amount, 23000);
      },
    );

    test(
      'ignores dissolved and incomplete merge groups without hiding projects',
      () {
        const useCase = ComputeAccountSummaryUseCase();

        final result = useCase.execute(
          timingRecords: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260312,
              contact: '李杰',
              site: '尚义',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 10,
              hours: 10,
              income: 0,
            ),
            TimingRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260323,
              contact: '李杰',
              site: '鲜滩',
              type: TimingType.hours,
              startMeter: 10,
              endMeter: 20,
              hours: 10,
              income: 0,
            ),
          ],
          devices: const [
            Device(
              id: 1,
              name: 'HITACHI 1#',
              brand: 'HITACHI',
              defaultUnitPrice: 100,
              baseMeterHours: 0,
            ),
          ],
          rates: const [],
          payments: const [],
          activeMergeGroups: const [
            AccountProjectMergeGroupWithMembers(
              group: AccountProjectMergeGroup(
                id: 1,
                contact: '李杰',
                createdAt: '2026-05-15T00:00:00.000Z',
                isActive: false,
              ),
              members: [
                AccountProjectMergeMember(
                  groupId: 1,
                  projectKey: '李杰||尚义',
                  contact: '李杰',
                  site: '尚义',
                  sortOrder: 0,
                  createdAt: '2026-05-15T00:00:00.000Z',
                ),
                AccountProjectMergeMember(
                  groupId: 1,
                  projectKey: '李杰||鲜滩',
                  contact: '李杰',
                  site: '鲜滩',
                  sortOrder: 1,
                  createdAt: '2026-05-15T00:00:00.000Z',
                ),
              ],
            ),
            AccountProjectMergeGroupWithMembers(
              group: AccountProjectMergeGroup(
                id: 2,
                contact: '李杰',
                createdAt: '2026-05-15T00:00:00.000Z',
              ),
              members: [
                AccountProjectMergeMember(
                  groupId: 2,
                  projectKey: '李杰||尚义',
                  contact: '李杰',
                  site: '尚义',
                  sortOrder: 0,
                  createdAt: '2026-05-15T00:00:00.000Z',
                ),
                AccountProjectMergeMember(
                  groupId: 2,
                  projectKey: '李杰||不存在',
                  contact: '李杰',
                  site: '不存在',
                  sortOrder: 1,
                  createdAt: '2026-05-15T00:00:00.000Z',
                ),
              ],
            ),
          ],
        );

        expect(result.projects.map((project) => project.projectKey).toList(), [
          '李杰||鲜滩',
          '李杰||尚义',
        ]);
        expect(
          result.projects.every(
            (project) => project.kind == AccountProjectKind.normal,
          ),
          isTrue,
        );
      },
    );
  });
}
