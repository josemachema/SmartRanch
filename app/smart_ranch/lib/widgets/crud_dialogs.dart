import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/ranch_api_service.dart';
import 'nfc_scanner_dialog.dart';

/// Reusable CRUD dialog forms for ranch operations.
/// Each form submits to the PostgreSQL API and returns the result.

// ============================================================
//  STYLED INPUT HELPERS
// ============================================================

InputDecoration _inputDecoration(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
  prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary, size: 18) : null,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: AppTheme.divider),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
  ),
  filled: true,
  fillColor: AppTheme.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  isDense: true,
);

Widget _sectionTitle(String text) => Padding(
  padding: EdgeInsets.only(bottom: 6, top: 4),
  child: Text(text, style: TextStyle(
      color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
);


// ============================================================
//  ADD ANIMAL DIALOG
// ============================================================

Future<bool> showAddAnimalDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final earTagCtrl = TextEditingController();
  final breedCtrl = TextEditingController(text: 'Brangus');
  final weightCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final deviceIdCtrl = TextEditingController();
  String sex = 'female';
  String category = 'vaca';
  String status = 'active';
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 22),
                    SizedBox(width: 8),
                    Text('Registrar Animal', style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                _sectionTitle('IDENTIFICACIÓN'),
                TextField(controller: nameCtrl, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Nombre', icon: Icons.pets)),
                SizedBox(height: 10),
                TextField(controller: earTagCtrl, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Arete SINIIGA', icon: Icons.tag)),
                SizedBox(height: 10),
                TextField(controller: breedCtrl, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Raza', icon: Icons.category)),

                const SizedBox(height: 14),
                _sectionTitle('CLASIFICACIÓN'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sex,
                        dropdownColor: AppTheme.card,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Sexo'),
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('Hembra')),
                          DropdownMenuItem(value: 'male', child: Text('Macho')),
                        ],
                        onChanged: (v) => setState(() => sex = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        dropdownColor: AppTheme.card,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Categoría'),
                        items: const [
                          DropdownMenuItem(value: 'vaca', child: Text('Vaca')),
                          DropdownMenuItem(value: 'toro', child: Text('Toro')),
                          DropdownMenuItem(value: 'becerro', child: Text('Becerro')),
                          DropdownMenuItem(value: 'novilla', child: Text('Novilla')),
                        ],
                        onChanged: (v) => setState(() => category = v!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                _sectionTitle('DATOS'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration('Peso (kg)', icon: Icons.monitor_weight)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        dropdownColor: AppTheme.card,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Estado'),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Activo')),
                          DropdownMenuItem(value: 'sick', child: Text('Enfermo')),
                          DropdownMenuItem(value: 'pregnant', child: Text('Gestante')),
                        ],
                        onChanged: (v) => setState(() => status = v!),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),
                TextField(controller: notesCtrl, maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Notas')),
                
                const SizedBox(height: 14),
                _sectionTitle('COLLAR INTELIGENTE (IoT)'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: deviceIdCtrl,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('ID del Collar NFC', icon: Icons.nfc),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final scannedId = await showDialog<String>(
                          context: context,
                          builder: (ctx) => const NfcScannerDialog(),
                        );
                        if (scannedId != null) {
                          setState(() {
                            deviceIdCtrl.text = scannedId;
                          });
                        }
                      },
                      icon: const Icon(Icons.wifi_tethering, size: 16),
                      label: const Text('Escanear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.secondary,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setState(() => loading = true);
                      try {
                        await RanchApiService.createAnimal({
                          'name': nameCtrl.text.trim(),
                          'ear_tag': earTagCtrl.text.trim(),
                          'breed': breedCtrl.text.trim(),
                          'sex': sex,
                          'category': category,
                          'status': status,
                          'weight_kg': double.tryParse(weightCtrl.text) ?? 0,
                          'notes': notesCtrl.text.trim(),
                          'device_id': deviceIdCtrl.text.trim().isEmpty ? null : deviceIdCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() => loading = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Registrar Animal', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}


// ============================================================
//  ADD MEDICAL RECORD DIALOG
// ============================================================

Future<bool> showAddMedicalDialog(BuildContext context, {int? animalId, String? initialProduct, String? initialType}) async {
  String recordType = initialType ?? (initialProduct != null && initialProduct.toLowerCase().contains('ivermectina') ? 'deworming' : 'vaccine');
  final productCtrl = TextEditingController(text: initialProduct ?? (recordType == 'deworming' ? 'Ivermectina 1%' : 'Pasturela bovina'));
  final doseCtrl = TextEditingController(text: recordType == 'deworming' ? '10ml SC' : '5ml IM');
  final adminCtrl = TextEditingController(text: 'Dr. Ramírez');
  final costCtrl = TextEditingController(text: '180');
  final notesCtrl = TextEditingController();
  final animalIdCtrl = TextEditingController(text: animalId?.toString() ?? '1');
  final withdrawalCtrl = TextEditingController(text: '0');
  DateTime nextDueDate = DateTime.now().add(Duration(days: recordType == 'deworming' ? 90 : 180));
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.medical_services, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Registro Médico y Sanidad', style: TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    IconButton(icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                const SizedBox(height: 14),

                _sectionTitle('IDENTIFICACIÓN DEL ANIMAL'),
                if (animalId == null) ...[
                  TextField(controller: animalIdCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration('ID Animal (Ej. 1, 2, 3...)', icon: Icons.pets)),
                  const SizedBox(height: 10),
                ],

                _sectionTitle('TIPO DE TRATAMIENTO'),
                DropdownButtonFormField<String>(
                  initialValue: recordType,
                  dropdownColor: AppTheme.card,
                  isExpanded: true,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'vaccine', child: Text('Vacuna (Refuerzo 6 meses)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'deworming', child: Text('Desparasitación (Refuerzo 3 meses)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'treatment', child: Text('Tratamiento / Antibiótico', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'exam', child: Text('Examen / Análisis Clínico', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'surgery', child: Text('Cirugía', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    setState(() {
                      recordType = v!;
                      if (recordType == 'vaccine') {
                        productCtrl.text = 'Pasturela bovina';
                        doseCtrl.text = '5ml IM';
                        nextDueDate = DateTime.now().add(const Duration(days: 180));
                      } else if (recordType == 'deworming') {
                        productCtrl.text = 'Ivermectina 1%';
                        doseCtrl.text = '10ml SC';
                        nextDueDate = DateTime.now().add(const Duration(days: 90));
                      } else if (recordType == 'treatment') {
                        productCtrl.text = 'Penicilina + Estreptomicina';
                        doseCtrl.text = '15ml IM';
                        withdrawalCtrl.text = '30';
                        nextDueDate = DateTime.now().add(const Duration(days: 14));
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),

                TextField(controller: productCtrl,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Producto / Medicamento', icon: Icons.medication)),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: TextField(controller: doseCtrl,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Dosis'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: costCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Costo \$'))),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: adminCtrl,
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration('Médico / Aplicador', icon: Icons.person)),
                    ),
                    if (recordType == 'treatment') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(controller: withdrawalCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            decoration: _inputDecoration('Días Retiro', icon: Icons.warning_amber_rounded)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Auto Next Due Date Protocol Calculation
                _sectionTitle('RECORDATORIO / PRÓXIMA APLICACIÓN'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_rounded, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Próxima fecha: ${nextDueDate.day}/${nextDueDate.month}/${nextDueDate.year}',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: nextDueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (picked != null) {
                                setState(() => nextDueDate = picked);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Sugerencias de protocolo veterinario:',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _IntervalChip(
                            label: '+30 días',
                            selected: nextDueDate.difference(DateTime.now()).inDays.abs() == 30,
                            onTap: () => setState(() => nextDueDate = DateTime.now().add(const Duration(days: 30))),
                          ),
                          _IntervalChip(
                            label: '+90 días (3m)',
                            selected: nextDueDate.difference(DateTime.now()).inDays.abs() == 90,
                            onTap: () => setState(() => nextDueDate = DateTime.now().add(const Duration(days: 90))),
                          ),
                          _IntervalChip(
                            label: '+180 días (6m)',
                            selected: nextDueDate.difference(DateTime.now()).inDays.abs() == 180,
                            onTap: () => setState(() => nextDueDate = DateTime.now().add(const Duration(days: 180))),
                          ),
                          _IntervalChip(
                            label: '+1 año',
                            selected: nextDueDate.difference(DateTime.now()).inDays.abs() >= 360,
                            onTap: () => setState(() => nextDueDate = DateTime.now().add(const Duration(days: 365))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                TextField(controller: notesCtrl, maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Notas / Diagnóstico')),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      final aid = animalId ?? int.tryParse(animalIdCtrl.text);
                      if (aid == null || productCtrl.text.trim().isEmpty) return;
                      setState(() => loading = true);
                      try {
                        await RanchApiService.createMedicalRecord({
                          'animal_id': aid,
                          'record_type': recordType,
                          'product_name': productCtrl.text.trim(),
                          'dose': doseCtrl.text.trim(),
                          'administered_by': adminCtrl.text.trim(),
                          'cost': double.tryParse(costCtrl.text) ?? 0,
                          'withdrawal_days': int.tryParse(withdrawalCtrl.text) ?? 0,
                          'next_due_date': nextDueDate.toIso8601String(),
                          'notes': notesCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() => loading = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar y Programar Recordatorio', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  ADD REPRODUCTIVE EVENT DIALOG WITH GESTATION PREDICTOR
// ============================================================

Future<bool> showAddReproductiveDialog(BuildContext context, {int? animalId, String? defaultType}) async {
  final animalIdCtrl = TextEditingController(text: animalId?.toString() ?? '1');
  final bullCtrl = TextEditingController(text: 'Angus Black #4521');
  final calfTagCtrl = TextEditingController(text: 'MX-0026-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
  final weightCtrl = TextEditingController(text: '34');
  final notesCtrl = TextEditingController();

  String eventType = defaultType ?? 'artificial_insemination';
  // Bovine gestation = 283 days
  DateTime expectedDeliveryDate = DateTime.now().add(const Duration(days: 283));
  bool pregnancyConfirmed = true;
  String calfSex = 'macho';
  bool loading = false;

  void updateExpectedDelivery(DateTime date) {
    expectedDeliveryDate = date.add(const Duration(days: 283));
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: const Color(0xFFAB47BC), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Evento Reproductivo', style: TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    IconButton(icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                const SizedBox(height: 14),

                _sectionTitle('VACA / HEMBRA'),
                if (animalId == null) ...[
                  TextField(controller: animalIdCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration('ID de la Vaca (Ej. 1, 2, 3...)', icon: Icons.pets)),
                  const SizedBox(height: 10),
                ],

                _sectionTitle('TIPO DE EVENTO'),
                DropdownButtonFormField<String>(
                  initialValue: eventType,
                  dropdownColor: AppTheme.card,
                  isExpanded: true,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'artificial_insemination', child: Text('🧬 Inseminación Artificial (IA)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'mating', child: Text('🐂 Monta Natural', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'pregnancy_check', child: Text('🤰 Diagnóstico / Palpación', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'birth', child: Text('🐣 Registro de Parto', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'heat_detected', child: Text('🔥 Celo Observado', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    setState(() {
                      eventType = v!;
                      if (eventType == 'artificial_insemination' || eventType == 'mating') {
                        updateExpectedDelivery(DateTime.now());
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Insemination / Mating Fields
                if (eventType == 'artificial_insemination' || eventType == 'mating') ...[
                  TextField(controller: bullCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration(
                        eventType == 'artificial_insemination' ? 'Semen / Pajilla / Toro' : 'Toro Semental',
                        icon: Icons.science_rounded,
                      )),
                  const SizedBox(height: 12),

                  // Gestation calculation box
                  _sectionTitle('PREDICCIÓN BIOLÓGICA DE PARTO (283 DÍAS)'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFAB47BC).withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFAB47BC).withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: const Color(0xFFAB47BC), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha estimada de parto:',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                  ),
                                  Text(
                                    '${expectedDeliveryDate.day}/${expectedDeliveryDate.month}/${expectedDeliveryDate.year}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: expectedDeliveryDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 400)),
                                );
                                if (picked != null) {
                                  setState(() => expectedDeliveryDate = picked);
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Ajustar', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Palpación recomendada a 45-60 días post-servicio.',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Pregnancy Check Fields
                if (eventType == 'pregnancy_check') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<bool>(
                          initialValue: pregnancyConfirmed,
                          dropdownColor: AppTheme.card,
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration('Resultado Palpación'),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('✅ Gestante (Positivo)')),
                            DropdownMenuItem(value: false, child: Text('❌ Vacía (Negativo)')),
                          ],
                          onChanged: (v) => setState(() => pregnancyConfirmed = v!),
                        ),
                      ),
                    ],
                  ),
                  if (pregnancyConfirmed) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('FECHA ESTIMADA DE PARTO'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pregnant_woman_rounded, color: const Color(0xFFAB47BC), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Parto: ${expectedDeliveryDate.day}/${expectedDeliveryDate.month}/${expectedDeliveryDate.year}',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: expectedDeliveryDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 300)),
                              );
                              if (picked != null) {
                                setState(() => expectedDeliveryDate = picked);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Modificar', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                // Birth Fields
                if (eventType == 'birth') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: calfSex,
                          dropdownColor: AppTheme.card,
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration('Sexo de la Cría'),
                          items: const [
                            DropdownMenuItem(value: 'macho', child: Text('Becerro (Macho)')),
                            DropdownMenuItem(value: 'hembra', child: Text('Becerra (Hembra)')),
                          ],
                          onChanged: (v) => setState(() => calfSex = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(controller: weightCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            decoration: _inputDecoration('Peso al nacer (kg)', icon: Icons.monitor_weight)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: calfTagCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration('Arete de la Cría', icon: Icons.tag)),
                ],

                const SizedBox(height: 10),
                TextField(controller: notesCtrl, maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Observaciones')),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      final aid = animalId ?? int.tryParse(animalIdCtrl.text);
                      if (aid == null) return;
                      setState(() => loading = true);
                      try {
                        await RanchApiService.createReproductiveEvent({
                          'animal_id': aid,
                          'event_type': eventType,
                          'bull_or_semen': bullCtrl.text.trim(),
                          'pregnancy_confirmed': eventType == 'pregnancy_check' ? pregnancyConfirmed : (eventType == 'artificial_insemination' || eventType == 'mating'),
                          'expected_birth_date': (eventType == 'artificial_insemination' || eventType == 'mating' || (eventType == 'pregnancy_check' && pregnancyConfirmed))
                              ? expectedDeliveryDate.toIso8601String()
                              : null,
                          'notes': notesCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() => loading = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAB47BC), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Registrar Evento Reproductivo', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}


// ============================================================
//  ADD WEIGHT RECORD DIALOG
// ============================================================

Future<bool> showAddWeightDialog(BuildContext context, {int? animalId}) async {
  final weightCtrl = TextEditingController();
  final bcsCtrl = TextEditingController(text: '3.0');
  final notesCtrl = TextEditingController();
  final animalIdCtrl = TextEditingController(text: animalId?.toString() ?? '');
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_weight, color: AppTheme.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Registrar Peso', style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                  Spacer(),
                  IconButton(icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx, false)),
                ],
              ),
              const SizedBox(height: 16),

              if (animalId == null) ...[
                TextField(controller: animalIdCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('ID Animal', icon: Icons.pets)),
                const SizedBox(height: 10),
              ],

              TextField(controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Peso (kg)', icon: Icons.monitor_weight)),
              const SizedBox(height: 10),

              TextField(controller: bcsCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Condición Corporal (1-5)', icon: Icons.star_half)),
              SizedBox(height: 10),

              TextField(controller: notesCtrl, maxLines: 2,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Notas')),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 42,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    final aid = animalId ?? int.tryParse(animalIdCtrl.text);
                    final w = double.tryParse(weightCtrl.text);
                    if (aid == null || w == null) return;
                    setState(() => loading = true);
                    try {
                      await RanchApiService.createWeightRecord({
                        'animal_id': aid,
                        'weight_kg': w,
                        'body_condition_score': double.tryParse(bcsCtrl.text) ?? 3.0,
                        'notes': notesCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        setState(() => loading = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar Peso', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}


// ============================================================
//  ADD FINANCIAL EVENT DIALOG
// ============================================================

Future<bool> showAddFinancialDialog(BuildContext context) async {
  final amountCtrl = TextEditingController();
  final buyerSellerCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final animalIdCtrl = TextEditingController();
  String eventType = 'expense';
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 22),
                    SizedBox(width: 8),
                    Text('Movimiento Financiero', style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                    Spacer(),
                    IconButton(icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: eventType,
                  dropdownColor: AppTheme.card,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'sale', child: Text('Venta')),
                    DropdownMenuItem(value: 'purchase', child: Text('Compra')),
                    DropdownMenuItem(value: 'expense', child: Text('Gasto')),
                    DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                  ],
                  onChanged: (v) => setState(() => eventType = v!),
                ),
                const SizedBox(height: 10),

                TextField(controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Monto \$', icon: Icons.attach_money)),
                const SizedBox(height: 10),

                TextField(controller: animalIdCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('ID Animal (opcional)', icon: Icons.pets)),
                SizedBox(height: 10),

                TextField(controller: buyerSellerCtrl,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Comprador / Vendedor', icon: Icons.person)),
                const SizedBox(height: 10),

                TextField(controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Peso al evento (kg)', icon: Icons.monitor_weight)),
                SizedBox(height: 10),

                TextField(controller: notesCtrl, maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Notas')),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 42,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null) return;
                      setState(() => loading = true);
                      try {
                        await RanchApiService.createFinancialEvent({
                          'event_type': eventType,
                          'amount': amount,
                          'animal_id': int.tryParse(animalIdCtrl.text),
                          'buyer_seller': buyerSellerCtrl.text.trim(),
                          'weight_at_event': double.tryParse(weightCtrl.text),
                          'notes': notesCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() => loading = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar Movimiento', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}