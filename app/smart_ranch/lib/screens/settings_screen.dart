import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/demo_service.dart';

class _SonoraPreset {
  final String name;
  final String municipality;
  final double lat;
  final double lng;

  const _SonoraPreset({
    required this.name,
    required this.municipality,
    required this.lat,
    required this.lng,
  });
}

/// Configuración del Rancho, Parámetros THI, Geocercas y Sensores IoT
class SettingsScreen extends StatefulWidget {
  final DemoService? demoService;
  final void Function(int)? onNavigate;

  const SettingsScreen({super.key, this.demoService, this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Ranch Information
  late final TextEditingController _ranchNameCtrl;
  final _stateCtrl = TextEditingController(text: 'Sonora');
  final _municipalityCtrl = TextEditingController(text: 'Puerto Peñasco');
  final _latCtrl = TextEditingController(text: '31.3142');
  final _lngCtrl = TextEditingController(text: '-113.5321');
  final _headsCountCtrl = TextEditingController(text: '8');

  // Official Cattle Registry
  final _uppCodeCtrl = TextEditingController(text: '26-104-0012');
  final _aglCtrl = TextEditingController(text: 'AGL Puerto Peñasco');
  final _brandMarkCtrl = TextEditingController(text: 'RP-26');
  final _emergencyPhoneCtrl = TextEditingController(text: '638-102-3456');

  // Geofence & THI Thresholds
  double _geofenceRadiusMeters = 1500;
  double _thiAlertThreshold = 75.0;
  double _thiDangerThreshold = 79.0;
  double _thiEmergencyThreshold = 84.0;
  int _syncIntervalMinutes = 5;

  // Preferences
  String _tempUnit = '°C';
  String _weightUnit = 'kg';
  bool _pushNotifications = true;
  bool _soundAlerts = true;
  bool _whatsappEmergency = true;
  bool _offlineCache = true;

  static const List<_SonoraPreset> _sonoraPresets = [
    _SonoraPreset(name: 'Rancho Puerto Peñasco', municipality: 'Puerto Peñasco', lat: 31.3142, lng: -113.5321),
    _SonoraPreset(name: 'Rancho Cananea', municipality: 'Cananea', lat: 30.9845, lng: -110.2974),
    _SonoraPreset(name: 'Rancho Hermosillo', municipality: 'Hermosillo', lat: 29.0729, lng: -110.9559),
    _SonoraPreset(name: 'Rancho Caborca', municipality: 'Caborca', lat: 30.7167, lng: -112.1500),
    _SonoraPreset(name: 'Rancho Ures', municipality: 'Ures', lat: 29.4267, lng: -110.3881),
    _SonoraPreset(name: 'Rancho Cajeme', municipality: 'Cajeme (Cd. Obregón)', lat: 27.4828, lng: -109.9304),
    _SonoraPreset(name: 'Rancho Nogales', municipality: 'Nogales', lat: 31.3086, lng: -110.9422),
    _SonoraPreset(name: 'Rancho Álamos', municipality: 'Álamos', lat: 27.0264, lng: -108.9333),
  ];

  @override
  void initState() {
    super.initState();
    final initialName = AuthService.ranchName.isNotEmpty ? AuthService.ranchName : 'Rancho Puerto Peñasco';
    _ranchNameCtrl = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _ranchNameCtrl.dispose();
    _stateCtrl.dispose();
    _municipalityCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _headsCountCtrl.dispose();
    _uppCodeCtrl.dispose();
    _aglCtrl.dispose();
    _brandMarkCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(_SonoraPreset preset) {
    setState(() {
      _ranchNameCtrl.text = preset.name;
      _municipalityCtrl.text = preset.municipality;
      _latCtrl.text = preset.lat.toStringAsFixed(4);
      _lngCtrl.text = preset.lng.toStringAsFixed(4);
      _aglCtrl.text = 'AGL ${preset.municipality.split(' ').first}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Ubicación y coordenadas actualizadas a ${preset.municipality}, Sonora'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveSettings() {
    final newName = _ranchNameCtrl.text.trim();
    if (newName.isNotEmpty) {
      AuthService.ranchName = newName;
      if (AuthService.currentUser != null) {
        AuthService.currentUser!['ranch_name'] = newName;
      }
    }
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat != null && lng != null) {
      AuthService.ranchLocation = LatLng(lat, lng);
    }
    widget.demoService?.notifyStateChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Configuración ganadera y parámetros IoT guardados para "$newName"'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
              // Top Header Card
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
                      child: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configuración del Rancho & Sistema',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Personaliza parámetros geográficos de Sonora, umbrales THI, geocercas y hardware IoT.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Responsive 2-column or stacked layout
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Ranch identity & geography
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildRanchInfoCard(),
                          const SizedBox(height: 16),
                          _buildOfficialRegistryCard(),
                          const SizedBox(height: 16),
                          _buildGeofenceCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right Column: IoT parameters, THI & Preferences
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildThiThresholdsCard(),
                          const SizedBox(height: 16),
                          _buildAlertChannelsCard(),
                          const SizedBox(height: 16),
                          _buildPreferencesCard(),
                          const SizedBox(height: 16),
                          _buildAccountCard(),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildRanchInfoCard(),
                    const SizedBox(height: 16),
                    _buildOfficialRegistryCard(),
                    const SizedBox(height: 16),
                    _buildGeofenceCard(),
                    const SizedBox(height: 16),
                    _buildThiThresholdsCard(),
                    const SizedBox(height: 16),
                    _buildAlertChannelsCard(),
                    const SizedBox(height: 16),
                    _buildPreferencesCard(),
                    const SizedBox(height: 16),
                    _buildAccountCard(),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRanchInfoCard() {
    return _buildCard(
      title: 'Ubicación & Presets Ganaderos de Sonora',
      icon: Icons.place_rounded,
      iconColor: AppTheme.primary,
      children: [
        Text(
          'Selecciona un municipio para autocompletar coordenadas de referencia:',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),

        // Sonora quick presets chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _sonoraPresets.map((preset) {
            final isSelected = _municipalityCtrl.text.toLowerCase().contains(preset.municipality.toLowerCase());
            return InkWell(
              onTap: () => _applyPreset(preset),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      preset.municipality,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _ranchNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Predio / Rancho',
                  prefixIcon: Icon(Icons.business_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _headsCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Censo Hato',
                  prefixIcon: Icon(Icons.pets_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _stateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estado Federativo',
                  prefixIcon: Icon(Icons.map_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _municipalityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Municipio / Región',
                  prefixIcon: Icon(Icons.location_city_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Latitud GPS Centro',
                  prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lngCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Longitud GPS Centro',
                  prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfficialRegistryCard() {
    return _buildCard(
      title: 'Cédula Oficial Ganadera (SADER / UGRS)',
      icon: Icons.verified_user_rounded,
      iconColor: const Color(0xFF2E7D32),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _uppCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Clave UPP (Unidad Producción)',
                  prefixIcon: Icon(Icons.tag_rounded, size: 18),
                  hintText: '26-104-0012',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _brandMarkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fierro de Herrar Oficial',
                  prefixIcon: Icon(Icons.branding_watermark_rounded, size: 18),
                  hintText: 'RP-26',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _aglCtrl,
          decoration: const InputDecoration(
            labelText: 'Asociación Ganadera Local (AGL)',
            prefixIcon: Icon(Icons.groups_outlined, size: 18),
            hintText: 'AGL Puerto Peñasco, Sonora',
          ),
        ),
      ],
    );
  }

  Widget _buildGeofenceCard() {
    return _buildCard(
      title: 'Geocerca Virtual & Radio de Pastoreo',
      icon: Icons.radar_rounded,
      iconColor: const Color(0xFFE65100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Radio Perimetral del Rancho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Alerta satelital inmediata si un collar sale de este límite', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_geofenceRadiusMeters.toStringAsFixed(0)} metros',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFE65100),
            thumbColor: const Color(0xFFE65100),
            inactiveTrackColor: const Color(0xFFE65100).withAlpha(40),
            trackHeight: 3,
          ),
          child: Slider(
            value: _geofenceRadiusMeters,
            min: 500,
            max: 5000,
            divisions: 18,
            onChanged: (v) => setState(() => _geofenceRadiusMeters = v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('500 m (Corrales)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            Text('2,500 m (Potrero Medio)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            Text('5,000 m (Rango Extenso)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildThiThresholdsCard() {
    return _buildCard(
      title: 'Umbrales de Estrés Calórico THI (Sonora)',
      icon: Icons.thermostat_rounded,
      iconColor: AppTheme.thiDanger,
      children: [
        Text(
          'Ajusta los niveles donde se detonarán notificaciones sonoras y aspersores automáticos:',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 12),

        // Alerta
        _buildSliderTile(
          label: 'Umbral Alerta Moderada (THI)',
          value: _thiAlertThreshold,
          min: 68.0,
          max: 80.0,
          color: AppTheme.thiAlert,
          onChanged: (v) => setState(() => _thiAlertThreshold = v),
        ),
        const SizedBox(height: 8),

        // Peligro
        _buildSliderTile(
          label: 'Umbral Peligro Crítico (THI)',
          value: _thiDangerThreshold,
          min: 75.0,
          max: 85.0,
          color: AppTheme.thiDanger,
          onChanged: (v) => setState(() => _thiDangerThreshold = v),
        ),
        const SizedBox(height: 8),

        // Emergencia
        _buildSliderTile(
          label: 'Umbral Emergencia Extrema (THI)',
          value: _thiEmergencyThreshold,
          min: 80.0,
          max: 95.0,
          color: AppTheme.thiEmergency,
          onChanged: (v) => setState(() => _thiEmergencyThreshold = v),
        ),
        const SizedBox(height: 14),

        // Frecuencia Muestreo
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frecuencia de Muestreo de Collares', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Optimiza la autonomía de la batería LiFePO4 (LoRa / WiFi)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            DropdownButton<int>(
              value: _syncIntervalMinutes,
              dropdownColor: AppTheme.card,
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 min (Intensivo)')),
                DropdownMenuItem(value: 5, child: Text('5 min (Óptimo)')),
                DropdownMenuItem(value: 15, child: Text('15 min (Ahorro)')),
                DropdownMenuItem(value: 30, child: Text('30 min (Bajo)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _syncIntervalMinutes = v);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertChannelsCard() {
    return _buildCard(
      title: 'Canales de Alerta de Emergencia',
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFF1976D2),
      children: [
        TextField(
          controller: _emergencyPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono Mayordomo / Vaquero Encargado',
            prefixIcon: Icon(Icons.phone_rounded, size: 18),
            hintText: '638-102-3456',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notificaciones Push de Alertas Críticas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Avisos de celo, estrés THI y cercos virtuales', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: _pushNotifications,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) => setState(() => _pushNotifications = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notificaciones WhatsApp / SMS en Emergencias', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Enviar mensaje instantáneo si el THI supera 79 o hay fiebre > 39.5°C', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: _whatsappEmergency,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) => setState(() => _whatsappEmergency = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Alarmas Sonoras en Emergencias', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Emitir sonido en el móvil al dispararse alertas críticas', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: _soundAlerts,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) => setState(() => _soundAlerts = v),
        ),
      ],
    );
  }

  Widget _buildPreferencesCard() {
    return _buildCard(
      title: 'Unidades y Preferencias del Sistema',
      icon: Icons.tune_rounded,
      iconColor: AppTheme.primary,
      children: [
        const Text('Tema Visual de la Aplicación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 16), label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 16), label: Text('Oscuro')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded, size: 16), label: Text('Sistema')),
            ],
            selected: {AppTheme.currentThemeMode},
            onSelectionChanged: (modes) {
              setState(() => AppTheme.setThemeMode(modes.first));
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary.withAlpha(40);
                }
                return AppTheme.surface;
              }),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unidad de Temperatura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '°C', label: Text('Celsius (°C)')),
                      ButtonSegment(value: '°F', label: Text('Fahrenheit (°F)')),
                    ],
                    selected: {_tempUnit},
                    onSelectionChanged: (s) => setState(() => _tempUnit = s.first),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unidad de Peso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'kg', label: Text('Kilogramos (kg)')),
                      ButtonSegment(value: 'lb', label: Text('Libras (lb)')),
                    ],
                    selected: {_weightUnit},
                    onSelectionChanged: (s) => setState(() => _weightUnit = s.first),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Caché y Modo Offline Local', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Permitir registro de eventos cuando no haya señal de internet en el aguaje', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          value: _offlineCache,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) => setState(() => _offlineCache = v),
        ),
      ],
    );
  }

  Widget _buildAccountCard() {
    return _buildCard(
      title: 'Cuenta & Sesión Activa',
      icon: Icons.person_rounded,
      iconColor: AppTheme.primary,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withAlpha(30),
            child: Text(
              AuthService.userName.isNotEmpty ? AuthService.userName[0].toUpperCase() : 'U',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(AuthService.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Usuario autenticado • Administrador del Rancho', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('ACTIVO', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withAlpha(40),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
