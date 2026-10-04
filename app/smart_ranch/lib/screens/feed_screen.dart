import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/demo_service.dart';

class _FeedItem {
  String name;
  String category;
  double stockKg;
  double unitCost;
  String unit;
  double dailyUsageKg;
  double minStockKg;

  _FeedItem({
    required this.name,
    required this.category,
    required this.stockKg,
    required this.unitCost,
    required this.unit,
    required this.dailyUsageKg,
    required this.minStockKg,
  });
}

class _RationPlan {
  String name;
  String target;
  List<String> items;
  double costPerDay;
  int heads;

  _RationPlan({
    required this.name,
    required this.target,
    required this.items,
    required this.costPerDay,
    required this.heads,
  });
}

/// Alimentación (Feed Management) screen — full CRUD for inventory and ration plans.
class FeedScreen extends StatefulWidget {
  final DemoService? demoService;
  final void Function(int)? onNavigate;

  const FeedScreen({super.key, this.demoService, this.onNavigate});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<_FeedItem> _feedInventory = [
    _FeedItem(name: 'Pasto Buffel (Seco)', category: 'Forraje', stockKg: 2500, unitCost: 3.5, unit: 'kg',
        dailyUsageKg: 80, minStockKg: 500),
    _FeedItem(name: 'Alfalfa Henificada', category: 'Forraje', stockKg: 1200, unitCost: 8.0, unit: 'kg',
        dailyUsageKg: 40, minStockKg: 300),
    _FeedItem(name: 'Maíz Molido', category: 'Concentrado', stockKg: 800, unitCost: 7.5, unit: 'kg',
        dailyUsageKg: 25, minStockKg: 200),
    _FeedItem(name: 'Melaza', category: 'Suplemento', stockKg: 350, unitCost: 5.0, unit: 'L',
        dailyUsageKg: 10, minStockKg: 100),
    _FeedItem(name: 'Bloque Mineral', category: 'Mineral', stockKg: 50, unitCost: 45.0, unit: 'pieza',
        dailyUsageKg: 0.5, minStockKg: 10),
    _FeedItem(name: 'Sal Mineral', category: 'Mineral', stockKg: 80, unitCost: 12.0, unit: 'kg',
        dailyUsageKg: 1, minStockKg: 20),
  ];

  final List<_RationPlan> _rations = [
    _RationPlan(name: 'Ración Mantenimiento', target: 'Vacas adultas', items: [
      'Pasto Buffel: 15 kg/día', 'Sal Mineral: 60g/día', 'Bloque Mineral: libre acceso'
    ], costPerDay: 58.0, heads: 5),
    _RationPlan(name: 'Ración Engorda', target: 'Becerros destete', items: [
      'Maíz Molido: 4 kg/día', 'Alfalfa: 6 kg/día', 'Melaza: 1 L/día', 'Mineral: 80g/día'
    ], costPerDay: 85.0, heads: 2),
    _RationPlan(name: 'Ración Gestación', target: 'Vacas gestantes', items: [
      'Alfalfa: 8 kg/día', 'Pasto: 10 kg/día', 'Concentrado: 2 kg/día', 'Mineral: 100g/día'
    ], costPerDay: 112.0, heads: 1),
  ];

  void _showFeedItemDialog({_FeedItem? item, int? index}) {
    final isEditing = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final stockCtrl = TextEditingController(text: item != null ? item.stockKg.toStringAsFixed(0) : '');
    final minStockCtrl = TextEditingController(text: item != null ? item.minStockKg.toStringAsFixed(0) : '100');
    final costCtrl = TextEditingController(text: item != null ? item.unitCost.toStringAsFixed(1) : '5.0');
    final usageCtrl = TextEditingController(text: item != null ? item.dailyUsageKg.toStringAsFixed(1) : '10');
    String unit = item?.unit ?? 'kg';
    String category = item?.category ?? 'Forraje';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(isEditing ? 'Editar Insumo' : 'Agregar Insumo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Insumo *', hintText: 'Ej. Alfalfa, Maíz...'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: const [
                          DropdownMenuItem(value: 'Forraje', child: Text('Forraje')),
                          DropdownMenuItem(value: 'Concentrado', child: Text('Concentrado')),
                          DropdownMenuItem(value: 'Suplemento', child: Text('Suplemento')),
                          DropdownMenuItem(value: 'Mineral', child: Text('Mineral')),
                          DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                        ],
                        onChanged: (v) => setDialogState(() => category = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: unit,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Unidad'),
                        items: const [
                          DropdownMenuItem(value: 'kg', child: Text('Kilogramo (kg)')),
                          DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                          DropdownMenuItem(value: 'pieza', child: Text('Pieza')),
                          DropdownMenuItem(value: 'ton', child: Text('Tonelada')),
                        ],
                        onChanged: (v) => setDialogState(() => unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Stock Actual ($unit) *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minStockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Mínimo Alerta ($unit)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Costo Unitario (\$/$unit)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: usageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Uso Diario ($unit/día)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  setState(() => _feedInventory.removeAt(index!));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insumo eliminado'), backgroundColor: AppTheme.thiDanger),
                  );
                },
                child: const Text('Eliminar', style: TextStyle(color: AppTheme.thiDanger)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final stock = double.tryParse(stockCtrl.text) ?? 0.0;
                final minStock = double.tryParse(minStockCtrl.text) ?? 50.0;
                final cost = double.tryParse(costCtrl.text) ?? 5.0;
                final usage = double.tryParse(usageCtrl.text) ?? 0.0;

                if (name.isEmpty) return;

                setState(() {
                  if (isEditing && index != null) {
                    _feedInventory[index] = _FeedItem(
                      name: name,
                      category: category,
                      stockKg: stock,
                      unitCost: cost,
                      unit: unit,
                      dailyUsageKg: usage,
                      minStockKg: minStock,
                    );
                  } else {
                    _feedInventory.add(_FeedItem(
                      name: name,
                      category: category,
                      stockKg: stock,
                      unitCost: cost,
                      unit: unit,
                      dailyUsageKg: usage,
                      minStockKg: minStock,
                    ));
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing ? '✅ Insumo actualizado' : '✅ Insumo agregado al inventario'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Guardar' : 'Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRationDialog({_RationPlan? ration, int? index}) {
    final isEditing = ration != null;
    final nameCtrl = TextEditingController(text: ration?.name ?? '');
    final targetCtrl = TextEditingController(text: ration?.target ?? 'Vacas adultas');
    final costCtrl = TextEditingController(text: ration != null ? ration.costPerDay.toStringAsFixed(0) : '60');
    final headsCtrl = TextEditingController(text: ration != null ? ration.heads.toString() : '5');
    final itemsCtrl = TextEditingController(text: ration?.items.join('\n') ?? 'Pasto Buffel: 15 kg/día\nSal Mineral: 60g/día');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEditing ? Icons.edit_note_rounded : Icons.receipt_long_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(isEditing ? 'Editar Plan de Ración' : 'Crear Plan de Ración', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de la Ración *', hintText: 'Ej. Ración Engorda'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                decoration: const InputDecoration(labelText: 'Etapa / Lote Destino *', hintText: 'Ej. Becerros destete, Gestantes'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Costo/día/cabeza (\$)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: headsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cabezas asignadas'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ingredientes / Dosis (uno por línea)',
                  hintText: 'Maíz: 4 kg/día\nAlfalfa: 6 kg/día\nMineral: 80g/día',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () {
                setState(() => _rations.removeAt(index!));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan de ración eliminado'), backgroundColor: AppTheme.thiDanger),
                );
              },
              child: const Text('Eliminar', style: TextStyle(color: AppTheme.thiDanger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final target = targetCtrl.text.trim();
              final cost = double.tryParse(costCtrl.text) ?? 50.0;
              final heads = int.tryParse(headsCtrl.text) ?? 0;
              final items = itemsCtrl.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

              if (name.isEmpty) return;

              setState(() {
                if (isEditing && index != null) {
                  _rations[index] = _RationPlan(
                    name: name,
                    target: target,
                    items: items,
                    costPerDay: cost,
                    heads: heads,
                  );
                } else {
                  _rations.add(_RationPlan(
                    name: name,
                    target: target,
                    items: items,
                    costPerDay: cost,
                    heads: heads,
                  ));
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEditing ? '✅ Ración actualizada' : '✅ Plan de ración creado y asignado'),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            child: Text(isEditing ? 'Guardar' : 'Crear'),
          ),
        ],
      ),
    );
  }

  void _showShareDocumentDialog() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final totalDailyCost = _rations.fold<double>(0, (sum, r) => sum + (r.costPerDay * r.heads));
    final totalMonthlyCost = totalDailyCost * 30;
    final totalHeadsAssigned = _rations.fold<int>(0, (sum, r) => sum + r.heads);

    final docText = StringBuffer();
    docText.writeln('========================================');
    docText.writeln('  SMART RANCH — REPORTE DE NUTRICIÓN');
    docText.writeln('  Fecha: $dateStr');
    docText.writeln('========================================\n');

    docText.writeln('--- 1. INVENTARIO DE INSUMOS ---');
    for (final item in _feedInventory) {
      final days = item.dailyUsageKg > 0 ? (item.stockKg / item.dailyUsageKg).toStringAsFixed(0) : 'N/A';
      final status = item.stockKg <= item.minStockKg ? '[ALERTA: STOCK BAJO]' : '[OK]';
      docText.writeln('• ${item.name} (${item.category}):');
      docText.writeln('  Stock: ${item.stockKg.toStringAsFixed(0)} ${item.unit} | Costo: \$${item.unitCost}/${item.unit}');
      docText.writeln('  Uso diario: ${item.dailyUsageKg} ${item.unit}/día | Autonomía: $days días $status\n');
    }

    docText.writeln('--- 2. PLANES DE RACIÓN Y ASIGNACIÓN ---');
    for (final ration in _rations) {
      final subtotal = ration.costPerDay * ration.heads;
      docText.writeln('• ${ration.name} (Destino: ${ration.target}):');
      docText.writeln('  Ingredientes: ${ration.items.join(", ")}');
      docText.writeln('  Costo/vaca/día: \$${ration.costPerDay.toStringAsFixed(2)} MXN');
      docText.writeln('  Cabezas asignadas: ${ration.heads} cabezas');
      docText.writeln('  Subtotal diario: \$${subtotal.toStringAsFixed(2)} MXN\n');
    }

    docText.writeln('--- 3. RESUMEN FINANCIERO NUTRICIONAL ---');
    docText.writeln('• Total cabezas bajo racionamiento: $totalHeadsAssigned cabezas');
    docText.writeln('• Inversión diaria total en alimento: \$${totalDailyCost.toStringAsFixed(2)} MXN');
    docText.writeln('• Proyección mensual estimada (30 días): \$${totalMonthlyCost.toStringAsFixed(2)} MXN');
    docText.writeln('========================================');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Documento de Nutrición & Raciones',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Generado para exportar y compartir',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 12),

              // Preview container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      docText.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: docText.toString()));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Documento copiado al portapapeles'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar Texto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📤 Documento PDF generado y listo para enviar / imprimir'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Compartir / Enviar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedSimulatorDialog() {
    int heads = _rations.fold<int>(0, (sum, r) => sum + r.heads);
    if (heads == 0) heads = 8;
    double avgWeight = 450;
    double dryMatterPercent = 2.5;

    final headsCtrl = TextEditingController(text: heads.toString());
    final weightCtrl = TextEditingController(text: avgWeight.toStringAsFixed(0));
    final dmCtrl = TextEditingController(text: dryMatterPercent.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final curHeads = int.tryParse(headsCtrl.text) ?? 1;
          final curWeight = double.tryParse(weightCtrl.text) ?? 400.0;
          final curDm = double.tryParse(dmCtrl.text) ?? 2.5;

          final dailyKgPerHead = (curWeight * (curDm / 100.0));
          final dailyHerdKg = dailyKgPerHead * curHeads;
          final monthlyTons = (dailyHerdKg * 30.0) / 1000.0;
          final estimatedCostMonthly = monthlyTons * 1000.0 * 4.2;

          return AlertDialog(
            backgroundColor: AppTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calculate_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Simulador de Materia Seca (MS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Cálculo de forraje según peso vivo en Sonora', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: headsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cabezas a alimentar', prefixIcon: Icon(Icons.pets, size: 18)),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Peso prom. (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined, size: 18)),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '% Peso Vivo en MS (Estándar: 2.2% a 2.8%)',
                      prefixIcon: Icon(Icons.grass_rounded, size: 18),
                      suffixText: '%',
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Requerimientos Estimados:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Consumo / Vaca / Día:', style: TextStyle(fontSize: 12)),
                            Text('${dailyKgPerHead.toStringAsFixed(1)} kg MS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Demanda Diaria Hato:', style: TextStyle(fontSize: 12)),
                            Text('${dailyHerdKg.toStringAsFixed(0)} kg / día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Demanda Mensual (30 d):', style: TextStyle(fontSize: 12)),
                            Text('${monthlyTons.toStringAsFixed(2)} Toneladas', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
                          ],
                        ),
                        Divider(height: 16, color: AppTheme.divider),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Costo Est. Mes (Buffel/Alfalfa):', style: TextStyle(fontSize: 12)),
                            Text('\$${estimatedCostMonthly.toStringAsFixed(0)} MXN', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E7D32), fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDailyCost = _rations.fold<double>(0, (sum, r) => sum + (r.costPerDay * r.heads));
    final totalHeadsAssigned = _rations.fold<int>(0, (sum, r) => sum + r.heads);
    final lowStockItems = _feedInventory.where((f) => f.stockKg <= f.minStockKg).toList();

    // Find lowest autonomy item
    _FeedItem? mostCriticalItem;
    double lowestDays = 9999;
    for (final f in _feedInventory) {
      if (f.dailyUsageKg > 0) {
        final d = f.stockKg / f.dailyUsageKg;
        if (d < lowestDays) {
          lowestDays = d;
          mostCriticalItem = f;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
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
                  child: const Icon(Icons.restaurant_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control Nutricional, Bodega & Raciones',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inventario forrajero para temporada seca y optimización de costos en Sonora',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _showFeedSimulatorDialog,
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: const Text('Simulador MS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withAlpha(120)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showShareDocumentDialog,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Compartir Reporte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),

          // 4 Top KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;
              final cards = [
                _buildKpiCard(
                  icon: Icons.attach_money_rounded,
                  label: 'Inversión Diaria',
                  value: '\$${totalDailyCost.toStringAsFixed(0)} MXN',
                  subtitle: 'Proy. mes: \$${(totalDailyCost * 30).toStringAsFixed(0)}',
                  color: const Color(0xFF2E7D32),
                ),
                _buildKpiCard(
                  icon: Icons.groups_rounded,
                  label: 'Cabezas Racionadas',
                  value: '$totalHeadsAssigned cabezas',
                  subtitle: '${_rations.length} lotes activos',
                  color: AppTheme.primary,
                ),
                _buildKpiCard(
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Autonomía Crítica',
                  value: mostCriticalItem != null ? '${lowestDays.toStringAsFixed(0)} días' : 'N/A',
                  subtitle: mostCriticalItem?.name ?? 'Sin datos',
                  color: lowestDays < 15 ? AppTheme.thiAlert : const Color(0xFF2E7D32),
                ),
                _buildKpiCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Insumos en Alerta',
                  value: '${lowStockItems.length} insumos',
                  subtitle: lowStockItems.isNotEmpty ? 'Reabastecer pronto' : 'Bodega estable',
                  color: lowStockItems.isNotEmpty ? AppTheme.thiDanger : AppTheme.textSecondary,
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

          // Critical Stock Warning Banner
          if (lowStockItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.thiDanger.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.thiDanger.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notification_important_rounded, color: AppTheme.thiDanger, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atención: ${lowStockItems.length} insumo(s) por debajo del stock de seguridad',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.thiDanger, fontSize: 13),
                        ),
                        Text(
                          lowStockItems.map((e) => '${e.name} (${e.stockKg.toStringAsFixed(0)} ${e.unit})').join(', '),
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Responsive 2-Column or Stacked Panels
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildInventoryPanel(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: _buildRationsPanel(),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildInventoryPanel(),
                  const SizedBox(height: 14),
                  _buildRationsPanel(),
                ],
              );
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

  Widget _buildInventoryPanel() {
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
                    color: AppTheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.warehouse_rounded, size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventario de Insumos & Bodega',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Monitoreo de existencias y autonomía forrajera',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showFeedItemDialog(),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Agregar Insumo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...List.generate(_feedInventory.length, (index) {
            final feed = _feedInventory[index];
            final daysLeft = feed.dailyUsageKg > 0 ? (feed.stockKg / feed.dailyUsageKg).round() : 999;
            final isLow = feed.stockKg <= feed.minStockKg;
            final valuation = feed.stockKg * feed.unitCost;

            // Health color & label
            final Color autonomyColor = isLow
                ? AppTheme.thiDanger
                : (daysLeft < 15 ? AppTheme.thiAlert : const Color(0xFF2E7D32));
            final String autonomyLabel = daysLeft >= 999
                ? '🟢 Abundante'
                : (daysLeft < 10
                    ? '🔴 $daysLeft d (Crítico)'
                    : (daysLeft < 20 ? '🟡 $daysLeft días' : '🟢 $daysLeft días'));

            // Progress towards capacity
            final double ratio = (feed.stockKg / (feed.minStockKg * 4)).clamp(0.05, 1.0);

            return InkWell(
              onTap: () => _showFeedItemDialog(item: feed, index: index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(70))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _categoryColor(feed.category).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_categoryIcon(feed.category), size: 20, color: _categoryColor(feed.category)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(feed.name,
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _categoryColor(feed.category).withAlpha(15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      feed.category,
                                      style: TextStyle(
                                          color: _categoryColor(feed.category), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${feed.unitCost.toStringAsFixed(2)} / ${feed.unit}',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• Uso: ${feed.dailyUsageKg.toStringAsFixed(0)} ${feed.unit}/d',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${feed.stockKg.toStringAsFixed(0)} ${feed.unit}',
                              style: TextStyle(
                                color: isLow ? AppTheme.thiDanger : AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: autonomyColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                autonomyLabel,
                                style: TextStyle(color: autonomyColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          color: AppTheme.textSecondary,
                          onPressed: () => _showFeedItemDialog(item: feed, index: index),
                          tooltip: 'Editar insumo',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress & valuation footer
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: AppTheme.divider.withAlpha(80),
                              valueColor: AlwaysStoppedAnimation<Color>(autonomyColor),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Valor en bodega: \$${valuation.toStringAsFixed(0)} MXN',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRationsPanel() {
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
                    color: AppTheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Planes de Ración y Asignación',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Distribución de ingredientes y costos por lote',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showRationDialog(),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Nueva Ración', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...List.generate(_rations.length, (index) {
            final ration = _rations[index];
            final dailyTotal = ration.costPerDay * ration.heads;
            final monthlyTotal = dailyTotal * 30;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(70))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ration.name,
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded, size: 12, color: AppTheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  'Lote / Destino: ${ration.target}',
                                  style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppTheme.primary,
                        tooltip: 'Editar ración',
                        onPressed: () => _showRationDialog(ration: ration, index: index),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Ingredients chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: ration.items.map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Text(item, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Stepper & costs
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${ration.costPerDay.toStringAsFixed(0)} /cabeza/día',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            Text(
                              'Total: \$${dailyTotal.toStringAsFixed(0)}/día  (\$${monthlyTotal.toStringAsFixed(0)}/mes)',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                color: ration.heads > 0 ? AppTheme.primary : AppTheme.textSecondary,
                                onPressed: ration.heads > 0 ? () => setState(() => ration.heads--) : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${ration.heads} cabezas',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                color: AppTheme.primary,
                                onPressed: () => setState(() => ration.heads++),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _categoryColor(String category) => switch (category) {
    'Forraje' => const Color(0xFF66BB6A),
    'Concentrado' => const Color(0xFFFFA726),
    'Suplemento' => const Color(0xFFAB47BC),
    'Mineral' => const Color(0xFF42A5F5),
    _ => AppTheme.textSecondary,
  };

  IconData _categoryIcon(String category) => switch (category) {
    'Forraje' => Icons.grass_rounded,
    'Concentrado' => Icons.grain_rounded,
    'Suplemento' => Icons.water_drop_rounded,
    'Mineral' => Icons.diamond_rounded,
    _ => Icons.inventory_2_rounded,
  };
}