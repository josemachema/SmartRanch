import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/demo_service.dart';

class _Transaction {
  final String id;
  final String type; // 'income' or 'expense'
  final String category;
  final String description;
  final double amount;
  final DateTime date;

  _Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
  });
}

/// Pantalla Financiera y Flujo de Caja para Ranchos de Sonora
class FinancialScreen extends StatefulWidget {
  final DemoService? demoService;
  final void Function(int)? onNavigate;

  const FinancialScreen({super.key, this.demoService, this.onNavigate});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  String _selectedPeriod = 'Este Mes';
  String _txFilter = 'all'; // 'all', 'income', 'expense'

  final List<_Transaction> _transactions = [
    _Transaction(
      id: 'tx-1',
      type: 'income',
      category: 'Venta ganado',
      description: 'Venta 2 novillos 450kg c/u (Subasta UGRS)',
      amount: 54000,
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    _Transaction(
      id: 'tx-2',
      type: 'income',
      category: 'Venta ganado',
      description: 'Venta becerro destete 220kg',
      amount: 15400,
      date: DateTime.now().subtract(const Duration(days: 8)),
    ),
    _Transaction(
      id: 'tx-3',
      type: 'income',
      category: 'Venta leche',
      description: 'Producción semanal 280L a pasteurizadora',
      amount: 4200,
      date: DateTime.now().subtract(const Duration(days: 12)),
    ),
    _Transaction(
      id: 'tx-4',
      type: 'expense',
      category: 'Mano de obra',
      description: 'Jornal quincenal vaqueros (2 operarios)',
      amount: 6000,
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    _Transaction(
      id: 'tx-5',
      type: 'expense',
      category: 'Alimentación',
      description: 'Compra forraje: Alfalfa henificada 500kg',
      amount: 4000,
      date: DateTime.now().subtract(const Duration(days: 6)),
    ),
    _Transaction(
      id: 'tx-6',
      type: 'expense',
      category: 'Veterinario',
      description: 'Vacunación hato completo Brucelosis + Desparasitante',
      amount: 3500,
      date: DateTime.now().subtract(const Duration(days: 10)),
    ),
    _Transaction(
      id: 'tx-7',
      type: 'expense',
      category: 'Mantenimiento',
      description: 'Reparación motobomba de pozo y cerca eléctrica potrero 2',
      amount: 2500,
      date: DateTime.now().subtract(const Duration(days: 14)),
    ),
    _Transaction(
      id: 'tx-8',
      type: 'expense',
      category: 'Alimentación',
      description: 'Maíz molido 200kg + melaza a granel',
      amount: 2000,
      date: DateTime.now().subtract(const Duration(days: 16)),
    ),
    _Transaction(
      id: 'tx-9',
      type: 'expense',
      category: 'Combustible',
      description: 'Diesel camioneta rancho y tractor agrícola',
      amount: 1800,
      date: DateTime.now().subtract(const Duration(days: 19)),
    ),
    _Transaction(
      id: 'tx-10',
      type: 'expense',
      category: 'Suplementos',
      description: 'Bloques minerales con fósforo + sal marina',
      amount: 1200,
      date: DateTime.now().subtract(const Duration(days: 22)),
    ),
  ];

  void _showAddTransactionDialog() {
    String type = 'expense';
    String category = 'Alimentación';
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    final incomeCategories = ['Venta ganado', 'Venta leche', 'Servicio de maquila', 'Otro ingreso'];
    final expenseCategories = [
      'Alimentación',
      'Mano de obra',
      'Veterinario',
      'Combustible',
      'Mantenimiento',
      'Suplementos',
      'Otro gasto',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final categories = type == 'income' ? incomeCategories : expenseCategories;
          if (!categories.contains(category)) {
            category = categories.first;
          }

          return AlertDialog(
            backgroundColor: AppTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (type == 'income' ? const Color(0xFF2E7D32) : AppTheme.thiDanger).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    type == 'income' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: type == 'income' ? const Color(0xFF2E7D32) : AppTheme.thiDanger,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Registrar Transacción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type selector tabs
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDlgState(() {
                              type = 'income';
                              category = incomeCategories.first;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'income' ? const Color(0xFF2E7D32).withAlpha(25) : AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: type == 'income' ? const Color(0xFF2E7D32) : AppTheme.divider,
                                  width: type == 'income' ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '+ Ingreso (Venta)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: type == 'income' ? const Color(0xFF2E7D32) : AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDlgState(() {
                              type = 'expense';
                              category = expenseCategories.first;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'expense' ? AppTheme.thiDanger.withAlpha(25) : AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: type == 'expense' ? AppTheme.thiDanger : AppTheme.divider,
                                  width: type == 'expense' ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '- Gasto (Egreso)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: type == 'expense' ? AppTheme.thiDanger : AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: AppTheme.card,
                      decoration: const InputDecoration(labelText: 'Categoría Ganadera', prefixIcon: Icon(Icons.category_rounded, size: 18)),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setDlgState(() => category = v!),
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto (\$ MXN) *',
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
                        hintText: 'Ej. 4500',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Concepto / Proveedor / Lote',
                        prefixIcon: Icon(Icons.description_outlined, size: 18),
                        hintText: 'Ej. 500kg Alfalfa molida Rancho San José',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                  final desc = descCtrl.text.trim().isEmpty ? category : descCtrl.text.trim();

                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un monto válido mayor a 0'), backgroundColor: AppTheme.thiDanger),
                    );
                    return;
                  }

                  setState(() {
                    _transactions.insert(
                      0,
                      _Transaction(
                        id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
                        type: type,
                        category: category,
                        description: desc,
                        amount: amount,
                        date: DateTime.now(),
                      ),
                    );
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(type == 'income' ? '✅ Ingreso registrado con éxito' : '✅ Gasto registrado con éxito'),
                      backgroundColor: type == 'income' ? const Color(0xFF2E7D32) : AppTheme.primary,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: type == 'income' ? const Color(0xFF2E7D32) : AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Guardar Movimiento'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _exportCsv() {
    final sb = StringBuffer();
    sb.writeln('ID,Fecha,Tipo,Categoria,Concepto,Monto_MXN');
    for (final tx in _transactions) {
      final dateStr = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      sb.writeln('${tx.id},$dateStr,${tx.type},${tx.category},"${tx.description}",${tx.amount.toStringAsFixed(2)}');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Libro diario exportado al portapapeles en formato CSV'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalIncome = _transactions
        .where((t) => t.type == 'income')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpenses = _transactions
        .where((t) => t.type == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final netProfit = totalIncome - totalExpenses;
    final profitMargin = totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0.0;
    const totalHeads = 8; // Ranch herd size
    final costPerHeadPerDay = totalExpenses / (totalHeads * 30.0);

    // Filter transactions
    final filteredTxs = _transactions.where((t) {
      if (_txFilter == 'income') return t.type == 'income';
      if (_txFilter == 'expense') return t.type == 'expense';
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Period Selector & Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finanzas & Flujo de Caja Ganadero',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'P&L mensual, costos operativos de forraje y márgenes de comercialización',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Period Selector Dropdown
                DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.card,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'Este Mes', child: Text('Este Mes (Sep 2026)')),
                    DropdownMenuItem(value: 'Último Trimestre', child: Text('Último Trimestre')),
                    DropdownMenuItem(value: 'Año 2026', child: Text('Ejercicio 2026')),
                    DropdownMenuItem(value: 'Histórico', child: Text('Histórico')),
                  ],
                  onChanged: (v) => setState(() => _selectedPeriod = v!),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: const Text('Exportar CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),

                ElevatedButton.icon(
                  onPressed: _showAddTransactionDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nuevo Movimiento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 Executive Financial KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;
              final cards = [
                _buildKpiCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Ingresos Totales',
                  value: '\$${_formatMoney(totalIncome)} MXN',
                  subtitle: '+12.4% vs mes anterior',
                  color: const Color(0xFF2E7D32),
                ),
                _buildKpiCard(
                  icon: Icons.trending_down_rounded,
                  label: 'Costos Operativos',
                  value: '\$${_formatMoney(totalExpenses)} MXN',
                  subtitle: '${(totalIncome > 0 ? (totalExpenses / totalIncome * 100) : 0).toStringAsFixed(1)}% de ingresos',
                  color: AppTheme.thiDanger,
                ),
                _buildKpiCard(
                  icon: netProfit >= 0 ? Icons.monetization_on_rounded : Icons.warning_rounded,
                  label: 'Utilidad Neta',
                  value: '${netProfit >= 0 ? '+' : '-'}\$${_formatMoney(netProfit.abs())} MXN',
                  subtitle: '${profitMargin.toStringAsFixed(1)}% margen neto',
                  color: netProfit >= 0 ? const Color(0xFF2E7D32) : AppTheme.thiDanger,
                ),
                _buildKpiCard(
                  icon: Icons.pets_rounded,
                  label: 'Costo / Vaca / Día',
                  value: '\$${costPerHeadPerDay.toStringAsFixed(2)} MXN',
                  subtitle: 'Base: $totalHeads cabezas en rancho',
                  color: AppTheme.primary,
                ),
              ];

              if (isDesktop) {
                return Row(
                  children: cards.map((c) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: c,
                  ))).toList(),
                );
              } else {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cards.map((c) => SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: c,
                  )).toList(),
                );
              }
            },
          ),
          const SizedBox(height: 14),

          // Main 2-Column Responsive Body
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Breakdown & Profitability Analysis
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildPnLBalanceBar(totalIncome, totalExpenses, netProfit),
                          const SizedBox(height: 14),
                          _buildExpenseBreakdownPanel(totalExpenses),
                          const SizedBox(height: 14),
                          _buildIncomeBreakdownPanel(totalIncome),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Right Column: Ledger / Transaction Log
                    Expanded(
                      flex: 5,
                      child: _buildTransactionLedger(filteredTxs),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildPnLBalanceBar(totalIncome, totalExpenses, netProfit),
                    const SizedBox(height: 14),
                    _buildExpenseBreakdownPanel(totalExpenses),
                    const SizedBox(height: 14),
                    _buildIncomeBreakdownPanel(totalIncome),
                    const SizedBox(height: 14),
                    _buildTransactionLedger(filteredTxs),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnLBalanceBar(double income, double expenses, double profit) {
    final double expenseRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final double profitRatio = 1.0 - expenseRatio;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.balance_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Balance Operativo (P&L)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text(
                'Margen Neto: ${(profitRatio * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (profitRatio * 100).round().clamp(1, 100),
                    child: Container(color: const Color(0xFF2E7D32)),
                  ),
                  Expanded(
                    flex: (expenseRatio * 100).round().clamp(1, 100),
                    child: Container(color: AppTheme.thiDanger),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Utilidad: \$${_formatMoney(profit)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.thiDanger, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Gastos: \$${_formatMoney(expenses)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseBreakdownPanel(double totalExpenses) {
    final expensesByCategory = <String, double>{};
    for (final t in _transactions.where((t) => t.type == 'expense')) {
      expensesByCategory[t.category] = (expensesByCategory[t.category] ?? 0) + t.amount;
    }
    final sortedExpenses = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFFE53935),
      const Color(0xFFFB8C00),
      AppTheme.primary,
      const Color(0xFF8E24AA),
      const Color(0xFF1E88E5),
      const Color(0xFF00ACC1),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.thiDanger.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.pie_chart_rounded, size: 16, color: AppTheme.thiDanger),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Desglose de Gastos por Categoría', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Costos de alimentación, mano de obra y sanidad', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                Text(
                  '\$${_formatMoney(totalExpenses)} MXN',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.thiDanger, fontSize: 13),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...List.generate(sortedExpenses.length, (index) {
            final entry = sortedExpenses[index];
            final pct = totalExpenses > 0 ? entry.value / totalExpenses : 0.0;
            final color = colors[index % colors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                        child: Icon(_categoryIcon(entry.key), size: 14, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.key, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        '\$${_formatMoney(entry.value)} MXN',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppTheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildIncomeBreakdownPanel(double totalIncome) {
    final incomeByCategory = <String, double>{};
    for (final t in _transactions.where((t) => t.type == 'income')) {
      incomeByCategory[t.category] = (incomeByCategory[t.category] ?? 0) + t.amount;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.monetization_on_rounded, size: 16, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fuentes de Ingreso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Venta de ganado en pie, novillos y subastas', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                Text(
                  '\$${_formatMoney(totalIncome)} MXN',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E7D32), fontSize: 13),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...incomeByCategory.entries.map((e) {
            final pct = totalIncome > 0 ? e.value / totalIncome : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(_categoryIcon(e.key), size: 16, color: const Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.key, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Text('\$${_formatMoney(e.value)} MXN',
                      style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildTransactionLedger(List<_Transaction> txs) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Libro Diario de Transacciones (${txs.length})',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Historial de ventas y egresos comprobables', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quick Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Todos', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('+ Ingresos', 'income'),
                const SizedBox(width: 6),
                _buildFilterChip('- Egresos', 'expense'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppTheme.divider),

          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No hay transacciones en este filtro', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            )
          else
            ...txs.map((tx) {
              final isIncome = tx.type == 'income';
              final dateStr = '${tx.date.day}/${tx.date.month}/${tx.date.year}';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(70))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: (isIncome ? const Color(0xFF2E7D32) : AppTheme.thiDanger).withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 16,
                        color: isIncome ? const Color(0xFF2E7D32) : AppTheme.thiDanger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description,
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(tx.category, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              Text(dateStr, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'}\$${_formatMoney(tx.amount)}',
                      style: TextStyle(
                        color: isIncome ? const Color(0xFF2E7D32) : AppTheme.thiDanger,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      color: AppTheme.textSecondary,
                      tooltip: 'Eliminar movimiento',
                      onPressed: () {
                        setState(() => _transactions.removeWhere((t) => t.id == tx.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Movimiento eliminado'), backgroundColor: AppTheme.thiAlert),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _txFilter == value;
    return InkWell(
      onTap: () => setState(() => _txFilter = value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }

  IconData _categoryIcon(String cat) => switch (cat) {
    'Alimentación' => Icons.grass_rounded,
    'Veterinario' => Icons.vaccines_rounded,
    'Combustible' => Icons.local_gas_station_rounded,
    'Mano de obra' => Icons.engineering_rounded,
    'Suplementos' => Icons.diamond_rounded,
    'Mantenimiento' => Icons.build_rounded,
    'Venta ganado' => Icons.pets_rounded,
    'Venta leche' => Icons.water_drop_rounded,
    _ => Icons.attach_money_rounded,
  };
}
