class AdminStats {
  final int activeUsers;
  final int createdEvents;
  final int pendingRequests;
  final int platformEarnings; // Balance de la cuenta de Tesorería (en tréboles)
  final double totalGrossIncome; // Ingresos totales por Stripe (en USD)

  const AdminStats({
    required this.activeUsers,
    required this.createdEvents,
    required this.pendingRequests,
    this.platformEarnings = 0,
    this.totalGrossIncome = 0.0,
  });
}
