class StagedTimingCalculationHistory {
  const StagedTimingCalculationHistory({
    required this.createdAt,
    required this.expression,
    required this.result,
    required this.ticketCount,
  });

  final DateTime createdAt;
  final String expression;
  final double result;
  final int ticketCount;
}
