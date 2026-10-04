import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/ranch_api_service.dart';
import '../widgets/nfc_scanner_dialog.dart';

/// Multi-step registration screen: User data, Ranch, Map/Geofencing in Puerto Peñasco, Equipment.
class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  const RegisterScreen({super.key, required this.onRegistered});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  bool _loading = false;

  // Step 1 — Responsable
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;

  // Step 2 — Rancho
  final _ranchNameCtrl = TextEditingController(text: 'Rancho Puerto Peñasco');
  final _stateCtrl = TextEditingController(text: 'Sonora');
  final _municipioCtrl = TextEditingController(text: 'Puerto Peñasco');
  final _headCountCtrl = TextEditingController();

  // Step 3 — Geofencing (Puerto Peñasco, Sonora)
  static const _puertoPenascoLocation = LatLng(31.3172, -113.5377);
  final List<LatLng> _polygonPoints = [];
  final MapController _mapController = MapController();

  // Step 4 — Equipos
  final List<String> _deviceIds = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _ranchNameCtrl.dispose();
    _stateCtrl.dispose();
    _municipioCtrl.dispose();
    _headCountCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary, size: 18) : null,
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

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty ||
            _phoneCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
          _showError('Llena todos los campos obligatorios');
          return false;
        }
        if (!_emailCtrl.text.contains('@')) {
          _showError('Ingresa un correo válido');
          return false;
        }
        if (_passCtrl.text.length < 6) {
          _showError('La contraseña debe tener al menos 6 caracteres');
          return false;
        }
        if (_passCtrl.text != _confirmPassCtrl.text) {
          _showError('Las contraseñas no coinciden');
          return false;
        }
        return true;
      case 1:
        if (_ranchNameCtrl.text.trim().isEmpty) {
          _showError('El nombre del rancho es obligatorio');
          return false;
        }
        return true;
      case 2:
        if (_polygonPoints.length < 3) {
          _showError('Delimita el rancho con al menos 3 puntos en el mapa');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.thiDanger),
    );
  }

  void _next() {
    if (_validateStep(_currentStep)) {
      setState(() => _currentStep++);
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _complete() async {
    setState(() => _loading = true);
    final ranchName = _ranchNameCtrl.text.trim().isNotEmpty ? _ranchNameCtrl.text.trim() : 'Rancho Puerto Peñasco';
    final email = _emailCtrl.text.trim();
    final fullName = _nameCtrl.text.trim();

    try {
      // Guardar configuración del rancho y geocerca real en Puerto Peñasco
      AuthService.ranchName = ranchName;
      AuthService.ranchLocation = _puertoPenascoLocation;
      if (_polygonPoints.length >= 3) {
        AuthService.geofencePolygon = List<LatLng>.from(_polygonPoints);
      }

      // Inicializar base de datos limpia con los collares reales escaneados
      RanchApiService.initNewAccountRanch(
        ranchName: ranchName,
        initialDeviceIds: _deviceIds,
      );

      AuthService.saveRegisteredName(email, fullName, ranchName: ranchName);

      // Registrar o autenticar usuario
      await AuthService.register(
        username: email.split('@').first,
        email: email,
        password: _passCtrl.text,
        fullName: fullName,
      ).timeout(const Duration(seconds: 3), onTimeout: () => null);

      AuthService.currentUser = {
        'username': email.split('@').first,
        'email': email,
        'full_name': fullName,
        'name': fullName,
        'ranch_name': ranchName,
        'phone': _phoneCtrl.text.trim(),
        'role': 'admin',
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Bienvenido a Smart Ranch, $fullName!'),
            backgroundColor: AppTheme.primary,
          ),
        );
        Navigator.of(context).pop(true);
        widget.onRegistered();
      }
    } catch (_) {
      AuthService.saveRegisteredName(email, fullName, ranchName: ranchName);
      AuthService.currentUser = {
        'username': email.split('@').first,
        'email': email,
        'full_name': fullName,
        'name': fullName,
        'ranch_name': ranchName,
        'phone': _phoneCtrl.text.trim(),
        'role': 'admin',
      };
      if (mounted) {
        Navigator.of(context).pop(true);
        widget.onRegistered();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanNfcDevice() async {
    final scannedId = await showDialog<String>(
      context: context,
      builder: (_) => const NfcScannerDialog(),
    );
    if (scannedId != null && mounted) {
      setState(() {
        if (!_deviceIds.contains(scannedId)) _deviceIds.add(scannedId);
      });
    }
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();
        final rows = const CsvToListConverter().convert(csvString);
        int added = 0;
        for (final row in rows) {
          for (final cell in row) {
            final id = cell.toString().trim();
            if (id.isNotEmpty && !_deviceIds.contains(id)) {
              _deviceIds.add(id);
              added++;
            }
          }
        }
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $added dispositivos importados'), backgroundColor: AppTheme.primary),
          );
        }
      }
    } catch (e) {
      _showError('Error al leer archivo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo_icon.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text(
              'Registro de Cuenta',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Step indicator without black box and without percentage
          _buildStepIndicator(),
          // Content
          Expanded(child: _buildStepContent()),
          // Bottom nav
          _buildBottomNav(),
        ],
      ),
    );
  }

  /// Step progress indicator without black container and without percentage tag
  Widget _buildStepIndicator() {
    final stepDetails = [
      {'title': 'Responsable', 'icon': Icons.person_outline},
      {'title': 'Rancho', 'icon': Icons.home_work_outlined},
      {'title': 'Ubicación', 'icon': Icons.map_outlined},
      {'title': 'Equipos', 'icon': Icons.memory_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso ${_currentStep + 1} de 4: ${stepDetails[_currentStep]['title']}',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          // Clean Progress Bars
          Row(
            children: List.generate(4, (i) {
              final isDone = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 6.0 : 0.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent
                          ? AppTheme.primary
                          : AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Clean Step Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stepDetails.asMap().entries.map((e) {
              final i = e.key;
              final title = e.value['title'] as String;
              final icon = e.value['icon'] as IconData;
              final isCurrent = i == _currentStep;
              final isDone = i < _currentStep;

              return InkWell(
                onTap: () {
                  if (i < _currentStep) {
                    setState(() => _currentStep = i);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : icon,
                        size: 14,
                        color: isCurrent || isDone
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                          color: isCurrent
                              ? AppTheme.primary
                              : (isDone ? AppTheme.textPrimary : AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1 — Datos del Responsable
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.person_pin_rounded, size: 48, color: AppTheme.primary)),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Datos del Responsable',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDeco('Nombre completo *', icon: Icons.person_outline),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDeco('Correo electrónico *', icon: Icons.email_outlined),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDeco('Número de celular *', icon: Icons.phone_outlined),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDeco('Contraseña *', icon: Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.textSecondary, size: 18),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassCtrl,
                obscureText: true,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDeco('Confirmar contraseña *', icon: Icons.lock_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step 2 — Datos del Rancho
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.agriculture_rounded, size: 48, color: AppTheme.primary)),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Datos del Rancho',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ranchNameCtrl,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDeco('Nombre del Rancho *', icon: Icons.home_work_outlined),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stateCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDeco('Estado', icon: Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _municipioCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDeco('Municipio'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _headCountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: _inputDeco('Número de cabezas (aprox.)', icon: Icons.pets),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step 3 — Ubicación y Geofencing (Puerto Peñasco, Sonora)
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delimitar Rancho — Puerto Peñasco, Sonora',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      'Toca el mapa para colocar los vértices del cerco virtual.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_polygonPoints.length} puntos',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _puertoPenascoLocation,
                      initialZoom: 13,
                      onTap: (_, point) {
                        setState(() => _polygonPoints.add(point));
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.smartranch.app',
                      ),
                      if (_polygonPoints.length >= 3)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _polygonPoints,
                              color: AppTheme.primary.withAlpha(45),
                              borderColor: AppTheme.primary,
                              borderStrokeWidth: 2.5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // Ranch center
                          Marker(
                            point: _puertoPenascoLocation,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          // Polygon Vertices
                          ..._polygonPoints.asMap().entries.map((e) => Marker(
                            point: e.value,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          )),
                        ],
                      ),
                    ],
                  ),
                  // Empty state guidance banner
                  if (_polygonPoints.isEmpty)
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.card.withAlpha(230),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withAlpha(100)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Toca en el mapa para marcar los vértices de tu rancho',
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Bottom Actions Toolbar
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.card.withAlpha(235),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: _polygonPoints.isNotEmpty
                                ? () => setState(() => _polygonPoints.clear())
                                : null,
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Borrar selección', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.thiEmergency,
                              disabledForegroundColor: AppTheme.textSecondary.withAlpha(80),
                            ),
                          ),
                          Container(height: 18, width: 1, color: AppTheme.divider),
                          TextButton.icon(
                            onPressed: _polygonPoints.isNotEmpty
                                ? () => setState(() => _polygonPoints.removeLast())
                                : null,
                            icon: const Icon(Icons.undo_rounded, size: 16),
                            label: const Text('Deshacer', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              disabledForegroundColor: AppTheme.textSecondary.withAlpha(80),
                            ),
                          ),
                          Container(height: 18, width: 1, color: AppTheme.divider),
                          IconButton(
                            onPressed: () => _mapController.move(_puertoPenascoLocation, 13.5),
                            icon: const Icon(Icons.my_location_rounded, size: 18),
                            color: AppTheme.primary,
                            tooltip: 'Centrar en Puerto Peñasco',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 4 — Registrar Equipos/Collares
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.nfc_rounded, size: 48, color: AppTheme.primary)),
              const SizedBox(height: 12),
              Center(
                child: Text('Registrar Equipos & Collares IoT',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Vincula los collares inteligentes o configura su WiFi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              const SizedBox(height: 20),

              // Scan NFC & Setup WiFi Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _scanNfcDevice,
                  icon: const Icon(Icons.nfc_rounded, size: 18),
                  label: const Text('Escanear y Configurar WiFi (NFC)', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Import CSV
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _importCsv,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Importar desde archivo CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withAlpha(100)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Registered devices count
              Text(
                'Collares Vinculados (${_deviceIds.length}):',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),

              if (_deviceIds.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Center(
                    child: Text(
                      'No hay collares vinculados aún. Puedes agregarlos ahora o más tarde desde la pantalla de Agregar Animal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _deviceIds.length,
                  itemBuilder: (context, index) {
                    final id = _deviceIds[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors_rounded, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(id, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.thiDanger),
                            onPressed: () => setState(() => _deviceIds.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Atrás'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(color: AppTheme.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton.icon(
            onPressed: _loading
                ? null
                : (_currentStep == 3 ? _complete : _next),
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_currentStep == 3 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 16),
            label: Text(_currentStep == 3 ? 'Completar Registro' : 'Siguiente', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}