import 'package:sqflite/sqflite.dart';

import 'schema/account_merge_schema.dart';
import 'schema/account_schema.dart';
import 'schema/calculator_schema.dart';
import 'schema/fleet_schema.dart';
import 'schema/project_schema.dart';
import 'schema/timing_schema.dart';

/// 数据库首次创建（onCreate）所需的全量 schema。
///
/// 表结构按领域拆分为独立片段；本入口按外键依赖顺序执行：projects
/// 先于引用它的表，merge group 先于 member。SQL 语义与拆分前完全
/// 一致，数据库版本不变。
class DbSchema {
  static Future<void> create(Database db) async {
    await ProjectSchema.create(db);
    await FleetSchema.create(db);
    await TimingSchema.create(db);
    await CalculatorSchema.create(db);
    await AccountSchema.create(db);
    await AccountMergeSchema.create(db);
  }
}
