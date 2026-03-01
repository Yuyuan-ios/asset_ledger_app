// =====================================================================
// ============================== SuggestService（联想建议纯规则） ==============================
// =====================================================================
//
// 设计目标：
// - 统一“输入框下拉联想”的候选生成规则（纯计算、可测试）
// - 不依赖 UI、不依赖 Store、不读 DB
// - Store/Page 只负责喂数据（历史字符串集合）
//
// 本期口径（你确认）：
// - 供应人/联系人/工地：来自历史记录的去重候选（按关键词过滤）
//
// =====================================================================

class SuggestService {
  const SuggestService._();

  // =====================================================================
  // ============================== 一、字符串建议（供应人/联系人/工地等） ==============================
  // =====================================================================

  static List<String> suggestStrings({
    required List<String> history,
    required String query,
    int limit = 12,
  }) {
    final q = query.trim().toLowerCase();

    // 1) 去重
    final uniq = uniqueHistory(history);

    // 2) query 为空：直接给前 limit 条
    if (q.isEmpty) {
      return uniq.take(limit).toList();
    }

    // 3) query 不为空：前缀优先，其次包含
    final prefix = <String>[];
    final contains = <String>[];

    for (final s in uniq) {
      final low = s.toLowerCase();
      if (low.startsWith(q)) {
        prefix.add(s);
      } else if (low.contains(q)) {
        contains.add(s);
      }
    }

    return [...prefix, ...contains].take(limit).toList();
  }

  // =====================================================================
  // ============================== 二、历史候选去重（通用） ==============================
  // =====================================================================

  static List<String> uniqueHistory(List<String> history) {
    final uniq = <String>[];
    final seen = <String>{};

    for (final x in history) {
      final s = x.trim();
      if (s.isEmpty) continue;

      final key = s.toLowerCase();
      if (seen.add(key)) uniq.add(s);
    }

    return uniq;
  }
}
