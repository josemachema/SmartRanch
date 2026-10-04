import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/demo_service.dart';
import '../services/ranch_api_service.dart';
import '../widgets/nfc_scanner_dialog.dart';

/// Alta de ejemplar con Split-View: Formulario asistido + Ficha Ganadera SINIIGA en Vivo
class AddAnimalScreen extends StatefulWidget {
  final DemoService? demoService;
  final void Function(int)? onNavigate;

  const AddAnimalScreen({super.key, this.demoService, this.onNavigate});

  @override
  State<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends State<AddAnimalScreen> {
  final _nameCtrl = TextEditingController();
  final _earTagCtrl = TextEditingController();
  final _breedCtrl = TextEditingController(text: 'Brangus');
  final _weightCtrl = TextEditingController(text: '420');
  final _notesCtrl = TextEditingController();
  final _deviceIdCtrl = TextEditingController();

  String _sex = 'female';
  String _category = 'vaca';
  String _status = 'active';
  String _pasture = 'Potrero 1 - Mesteñas';
  bool _loading = false;

  static const List<String> _sonoraBreeds = [
    'Brangus',
    'Charolais',
    'Angus',
    'Beefmaster',
    'Brahman',
    'Simmental',
    'Suizo Europeo',
    'Hereford',
    'Criollo Sonorense',
  ];

  static const List<String> _pastures = [
    'Potrero 1 - Mesteñas',
    'Potrero 2 - El Aguaje',
    'Potrero 3 - Las Palmas',
    'Corral de Manejo',
    'Maternidad',
    'Cuarentena',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-generate initial Sonora SINIIGA tag if empty
    _earTagCtrl.text = _generateSiniigaTag();

    // Listen to changes to rebuild live preview
    _nameCtrl.addListener(_onFieldChanged);
    _earTagCtrl.addListener(_onFieldChanged);
    _breedCtrl.addListener(_onFieldChanged);
    _weightCtrl.addListener(_onFieldChanged);
    _deviceIdCtrl.addListener(_onFieldChanged);
    _notesCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFieldChanged);
    _earTagCtrl.removeListener(_onFieldChanged);
    _breedCtrl.removeListener(_onFieldChanged);
    _weightCtrl.removeListener(_onFieldChanged);
    _deviceIdCtrl.removeListener(_onFieldChanged);
    _notesCtrl.removeListener(_onFieldChanged);

    _nameCtrl.dispose();
    _earTagCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    _deviceIdCtrl.dispose();
    super.dispose();
  }

  String _generateSiniigaTag() {
    final rng = Random();
    final hatoPart = (1000 + rng.nextInt(9000)).toString();
    final animalPart = (1000 + rng.nextInt(9000)).toString();
    // 26 is federal state code for Sonora, Mexico
    return 'MX-26-$hatoPart-$animalPart';
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre o identificador del animal es obligatorio'),
          backgroundColor: AppTheme.thiDanger,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final newAnimalData = {
        'name': _nameCtrl.text.trim(),
        'ear_tag': _earTagCtrl.text.trim(),
        'breed': _breedCtrl.text.trim(),
        'sex': _sex,
        'category': _category,
        'status': _status,
        'pasture': _pasture,
        'weight_kg': double.tryParse(_weightCtrl.text) ?? 400.0,
        'notes': _notesCtrl.text.trim(),
        'device_id': _deviceIdCtrl.text.trim().isEmpty ? null : _deviceIdCtrl.text.trim(),
      };

      await RanchApiService.createAnimal(newAnimalData);

      if (mounted) {
        final registeredName = _nameCtrl.text.trim();
        _clearForm();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $registeredName registrado en el hato exitosamente'),
            backgroundColor: AppTheme.primary,
            action: widget.onNavigate != null
                ? SnackBarAction(
                    label: 'VER EN HATO',
                    textColor: Colors.white,
                    onPressed: () => widget.onNavigate?.call(3),
                  )
                : null,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e'), backgroundColor: AppTheme.thiDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _earTagCtrl.text = _generateSiniigaTag();
    _breedCtrl.text = 'Brangus';
    _weightCtrl.text = '420';
    _notesCtrl.clear();
    _deviceIdCtrl.clear();
    setState(() {
      _sex = 'female';
      _category = 'vaca';
      _status = 'active';
      _pasture = 'Potrero 1 - Mesteñas';
    });
  }

  Future<void> _scanNfc() async {
    final scannedId = await showDialog<String>(
      context: context,
      builder: (_) => const NfcScannerDialog(),
    );
    if (scannedId != null && mounted) {
      setState(() => _deviceIdCtrl.text = scannedId);
    }
  }

  InputDecoration _inputDeco(String label, {IconData? icon, Widget? suffix}) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary, size: 18) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: AppTheme.surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _sectionTitle(String text, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 18),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Title Header
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
                      child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alta de Ejemplar & Vinculación de Collar',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Registro en el Padrón Ganadero de Sonora con trazabilidad SINIIGA e IoT',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onNavigate != null)
                      TextButton.icon(
                        onPressed: () => widget.onNavigate?.call(3),
                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: const Text('Ir al Hato', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Split View Desktop or Column Mobile
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Registration Form
                    Expanded(
                      flex: 6,
                      child: _buildFormCard(),
                    ),
                    const SizedBox(width: 16),
                    // Right: Live Cattle Pass Preview
                    Expanded(
                      flex: 4,
                      child: _buildLivePreviewCard(),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildLivePreviewCard(compact: true),
                    const SizedBox(height: 14),
                    _buildFormCard(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IDENTIFICACIÓN
          _sectionTitle('1. IDENTIFICACIÓN OFICIAL (SINIIGA)', icon: Icons.badge_rounded),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _nameCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Nombre / Número de Manejo *', icon: Icons.pets),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _earTagCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco(
                    'Arete SINIIGA',
                    icon: Icons.tag,
                    suffix: IconButton(
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      color: AppTheme.primary,
                      tooltip: 'Generar nuevo arete Sonora',
                      onPressed: () => setState(() => _earTagCtrl.text = _generateSiniigaTag()),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Breed input + Sonora chips
          TextField(
            controller: _breedCtrl,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: _inputDeco('Raza Seleccionada', icon: Icons.category),
          ),
          const SizedBox(height: 8),
          Text(
            'Razas predominantes en Sonora:',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _sonoraBreeds.map((breed) {
              final isSelected = _breedCtrl.text.trim().toLowerCase() == breed.toLowerCase();
              return InkWell(
                onTap: () => setState(() => _breedCtrl.text = breed),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    breed,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // CLASIFICACIÓN
          _sectionTitle('2. CLASIFICACIÓN & POTRERO', icon: Icons.straighten_rounded),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sex,
                  dropdownColor: AppTheme.card,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Sexo'),
                  items: const [
                    DropdownMenuItem(value: 'female', child: Text('Hembra ♀')),
                    DropdownMenuItem(value: 'male', child: Text('Macho ♂')),
                  ],
                  onChanged: (v) => setState(() => _sex = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: AppTheme.card,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Categoría'),
                  items: const [
                    DropdownMenuItem(value: 'vaca', child: Text('Vaca')),
                    DropdownMenuItem(value: 'toro', child: Text('Toro')),
                    DropdownMenuItem(value: 'becerro', child: Text('Becerro')),
                    DropdownMenuItem(value: 'novilla', child: Text('Novilla / Vaquilla')),
                    DropdownMenuItem(value: 'buey', child: Text('Novillo de Engorda')),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Peso Actual (kg)', icon: Icons.monitor_weight_outlined),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  dropdownColor: AppTheme.card,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Estatus Sanitario'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('🟢 Activo / Sano')),
                    DropdownMenuItem(value: 'pregnant', child: Text('🟣 Gestante')),
                    DropdownMenuItem(value: 'heat', child: Text('🔥 En Celo')),
                    DropdownMenuItem(value: 'quarantine', child: Text('🟡 Cuarentena')),
                    DropdownMenuItem(value: 'sick', child: Text('🔴 Enfermo')),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: _pasture,
            dropdownColor: AppTheme.card,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: _inputDeco('Potrero Asignado', icon: Icons.landscape_rounded),
            items: _pastures.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _pasture = v!),
          ),

          // COLLAR INTELIGENTE (IoT)
          _sectionTitle('3. TELEMETRÍA & HARDWARE (COLLAR IOT)', icon: Icons.sensors_rounded),

          // Smart auto-discovery badge
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E7D32).withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF2E7D32), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hardware IoT Detectado en Vivo',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 12),
                      ),
                      Text(
                        'Collar-SmartRanch transmitiendo en tiempo real (Batería: 98%)',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _deviceIdCtrl.text = 'Collar-SmartRanch'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Vincular', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deviceIdCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco(
                    'ID del Collar IoT (Opcional)',
                    icon: Icons.nfc_rounded,
                    suffix: _deviceIdCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() => _deviceIdCtrl.clear()),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _scanNfc,
                icon: const Icon(Icons.contactless_rounded, size: 18),
                label: const Text('Escanear NFC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary.withAlpha(20),
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          // NOTAS
          _sectionTitle('4. OBSERVACIONES & GENEALOGÍA', icon: Icons.notes_rounded),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: _inputDeco('Fierro de herrar, procedencia, o notas clínicas'),
          ),

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _loading ? 'Registrando en padrón...' : 'Guardar y Dar de Alta Animal',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard({bool compact = false}) {
    final animalName = _nameCtrl.text.trim().isEmpty ? 'Ejemplar sin nombre' : _nameCtrl.text.trim();
    final earTag = _earTagCtrl.text.trim().isEmpty ? 'MX-26-0000-0000' : _earTagCtrl.text.trim();
    final breed = _breedCtrl.text.trim().isEmpty ? 'Brangus' : _breedCtrl.text.trim();
    final weight = _weightCtrl.text.trim().isEmpty ? '420' : _weightCtrl.text.trim();
    final hasCollar = _deviceIdCtrl.text.trim().isNotEmpty;
    final collarId = _deviceIdCtrl.text.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.badge_rounded, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ficha Ganadera en Tiempo Real',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      'Previsualización de cédula oficial de hato',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('EN VIVO', style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SINIIGA Official Yellow Ear Tag Graphic
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFEA00), Color(0xFFFFD600)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF57F17), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD600).withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: Colors.black87, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'SINIIGA • MÉXICO',
                          style: TextStyle(color: Colors.black.withAlpha(200), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('SONORA (26)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  earTag,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                // Barcode simulation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    24,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: (i % 3 == 0) ? 3 : ((i % 2 == 0) ? 2 : 1),
                      height: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Animal Details Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
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
                            animalName,
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$breed • ${_category.toUpperCase()}',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _sex == 'female' ? Colors.pink.withAlpha(20) : Colors.blue.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _sex == 'female' ? 'Hembra ♀' : 'Macho ♂',
                        style: TextStyle(
                          color: _sex == 'female' ? Colors.pink : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: AppTheme.divider),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPreviewMetric('Peso', '$weight kg'),
                    _buildPreviewMetric('Estatus', _statusLabel(_status)),
                    _buildPreviewMetric('Potrero', _pasture.split(' - ').first),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // IoT Collar Telemetry Link Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasCollar ? const Color(0xFF2E7D32).withAlpha(15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasCollar ? const Color(0xFF2E7D32).withAlpha(50) : AppTheme.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasCollar ? Icons.wifi_tethering_rounded : Icons.sensors_off_rounded,
                  color: hasCollar ? const Color(0xFF2E7D32) : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCollar ? 'Collar Enlazado: $collarId' : 'Sin collar IoT vinculado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: hasCollar ? const Color(0xFF2E7D32) : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        hasCollar
                            ? '📡 GPS Activo • 🔋 98% • 🌡️ 38.6°C'
                            : 'El animal se registrará con arete visual tradicional',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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
  }

  Widget _buildPreviewMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
    'active' => '🟢 Sano',
    'pregnant' => '🟣 Gestante',
    'heat' => '🔥 Celo',
    'quarantine' => '🟡 Cuarentena',
    'sick' => '🔴 Enfermo',
    _ => 'Activo',
  };
}