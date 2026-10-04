import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';
import '../services/demo_service.dart';
import '../services/auth_service.dart';

/// Centralized alerts screen — dynamically clears alerts when condition normalizes
/// and connects live IoT telemetry from smart collars.
class AlertsScreen extends StatefulWidget {
  final DemoService? demoService;
  final void Function(int index)? onNavigate;
  const AlertsScreen({super.key, this.demoService, this.onNavigate});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertLog> _alerts = [];
  bool _isLoading = true;
  bool _showOnlyUnacknowledged = true;
  String _selectedCategory = 'all'; // all, thi, health, geofence, estrus, battery
  String? _selectedSeverity; // null (all), critical, warning, info

  static final _demoAlerts = [
    AlertLog(
      id: 1,
      deviceId: 'vaca_001',
      alertType: 'thi_danger',
      severity: 'danger',
      message: 'PELIGRO: THI=82.5 en Lupita — Proveer sombra y agua fresca',
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    AlertLog(
      id: 2,
      deviceId: 'vaca_005',
      alertType: 'geofence_exit',
      severity: 'warning',
      message: 'Valentina salió de zona permitida: Potrero Sur',
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    AlertLog(
      id: 3,
      deviceId: 'vaca_003',
      alertType: 'estrus_detected',
      severity: 'info',
      message: 'Posible celo detectado en Canela (score=0.92, actividad +180%)',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AlertLog(
      id: 4,
      deviceId: 'vaca_004',
      alertType: 'health_fever',
      severity: 'danger',
      message: 'Fiebre detectada en Luna — temp corporal 40.3°C (MLX90614)',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AlertLog(
      id: 5,
      deviceId: 'vaca_002',
      alertType: 'vaccine_due',
      severity: 'info',
      message: 'Estrella necesita refuerzo de vacuna Pasturela en 3 días',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AlertLog(
      id: 6,
      deviceId: 'vaca_001',
      alertType: 'thi_emergency',
      severity: 'emergency',
      message: 'EMERGENCIA: THI=91.2 — Intervención inmediata requerida',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      acknowledged: true,
      acknowledgedBy: 'admin',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    widget.demoService?.addListener(_onDemoServiceUpdate);
  }

  @override
  void dispose() {
    widget.demoService?.removeListener(_onDemoServiceUpdate);
    super.dispose();
  }

  void _onDemoServiceUpdate() {
    if (!mounted) return;
    final ds = widget.demoService;
    if (ds == null) return;

    final readings = ds.latestReadings;
    final activeHealth = ds.activeHealthAlerts;
    final activeEstrus = ds.activeEstrusAlerts;

    setState(() {
      // 1. Dynamic auto-clearing logic:
      _alerts.removeWhere((a) {
        if (a.acknowledged) return false;

        // THI alerts auto-clear when cow's THI normalizes
        if (a.alertType == 'thi_danger' || a.alertType == 'thi_emergency') {
          if (a.deviceId != null && readings.containsKey(a.deviceId)) {
            final r = readings[a.deviceId]!;
            if (r.thi < 78.0) return true;
          }
        }

        // Health fever/lethargy alerts auto-clear when condition is no longer active
        if (a.alertType == 'health_fever' || a.alertType == 'health_lethargy' || a.alertType == 'health_sick') {
          if (a.deviceId != null && !activeHealth.containsKey(a.deviceId)) return true;
        }

        // Estrus alerts auto-clear when no longer in heat
        if (a.alertType == 'estrus_detected') {
          if (a.deviceId != null && !activeEstrus.containsKey(a.deviceId)) return true;
        }

        return false;
      });

      // 2. Dynamic IoT telemetry collar alert injection
      for (final r in readings.values) {
        if (r.thi >= 84.0) {
          if (!_alerts.any((a) => a.deviceId == r.deviceId && a.alertType == 'thi_emergency' && !a.acknowledged)) {
            _alerts.insert(0, AlertLog(
              id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000 + 10,
              deviceId: r.deviceId,
              alertType: 'thi_emergency',
              severity: 'emergency',
              message: 'EMERGENCIA THI: ${r.animalName.isNotEmpty ? r.animalName : r.deviceId} registra THI=${r.thi.toStringAsFixed(1)} (Estrés calórico severo).',
              createdAt: DateTime.now(),
            ));
          }
        } else if (r.thi >= 78.0) {
          if (!_alerts.any((a) => a.deviceId == r.deviceId && a.alertType == 'thi_danger' && !a.acknowledged)) {
            _alerts.insert(0, AlertLog(
              id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000 + 11,
              deviceId: r.deviceId,
              alertType: 'thi_danger',
              severity: 'danger',
              message: 'PELIGRO THI: ${r.animalName.isNotEmpty ? r.animalName : r.deviceId} con THI=${r.thi.toStringAsFixed(1)}. Proveer aspersión o sombra.',
              createdAt: DateTime.now(),
            ));
          }
        }

        if (r.batteryLevel <= 20) {
          if (!_alerts.any((a) => a.deviceId == r.deviceId && a.alertType == 'low_battery' && !a.acknowledged)) {
            _alerts.insert(0, AlertLog(
              id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000 + 12,
              deviceId: r.deviceId,
              alertType: 'low_battery',
              severity: 'warning',
              message: 'BATERÍA BAJA: Collar ${r.deviceId} al ${r.batteryLevel}%. Recarga requerida.',
              createdAt: DateTime.now(),
            ));
          }
        }
      }

      // 3. Dynamic IoT collar disconnection watchdog
      final isCollarDisconnected = ds.isCollarSimulatedDisconnected ||
          !ds.isCollarOnline('Collar-SmartRanch');
      if (isCollarDisconnected) {
        if (!_alerts.any((a) => a.alertType == 'collar_disconnected' && !a.acknowledged)) {
          final diffMin = ds.timeSinceLastCollarPacket('Collar-SmartRanch')?.inMinutes ?? 24;
          _alerts.insert(0, AlertLog(
            id: 99990,
            deviceId: 'Collar-SmartRanch',
            alertType: 'collar_disconnected',
            severity: 'danger',
            message: 'DESCONEXIÓN IOT: Collar-SmartRanch sin señal satelital desde hace $diffMin min. Última ubicación conocida (LKP) resguardada en Potrero Peñasco Norte.',
            createdAt: DateTime.now().subtract(Duration(minutes: diffMin)),
          ));
        }
      } else {
        _alerts.removeWhere((a) => a.alertType == 'collar_disconnected' && !a.acknowledged);
      }
    });
  }

  Future<void> _loadAlerts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final alerts = await RanchApiService.getAlerts(unacknowledged: _showOnlyUnacknowledged);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _alerts = _showOnlyUnacknowledged
            ? List<AlertLog>.from(_demoAlerts.where((a) => !a.acknowledged))
            : List<AlertLog>.from(_demoAlerts);
        _isLoading = false;
      });
    }
  }

  void _dismissAlert(AlertLog alert) async {
    setState(() {
      _alerts.removeWhere((a) => a.id == alert.id);
    });
    try {
      await RanchApiService.acknowledgeAlert(alert.id, AuthService.userName);
    } catch (e) {
      debugPrint('Error acknowledging alert on server: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Alerta atendida: ${_alertTypeLabel(alert.alertType)}'),
          action: SnackBarAction(
            label: 'DESHACER',
            textColor: AppTheme.primary,
            onPressed: () {
              setState(() => _alerts.insert(0, alert));
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _acknowledgeAll() {
    final active = _alerts.where((a) => !a.acknowledged).toList();
    if (active.isEmpty) return;

    setState(() {
      _alerts.removeWhere((a) => !a.acknowledged);
    });

    for (final a in active) {
      try {
        RanchApiService.acknowledgeAlert(a.id, AuthService.userName);
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${active.length} alertas marcadas como atendidas'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  List<AlertLog> get _filteredAlerts {
    return _alerts.where((a) {
      if (_showOnlyUnacknowledged && a.acknowledged) return false;

      // Severity Filter
      if (_selectedSeverity != null) {
        if (_selectedSeverity == 'critical' && a.severity != 'emergency' && a.severity != 'danger') {
          return false;
        }
        if (_selectedSeverity == 'warning' && a.severity != 'warning') {
          return false;
        }
        if (_selectedSeverity == 'info' && a.severity != 'info') {
          return false;
        }
      }

      // Category Filter
      if (_selectedCategory == 'disconnect' && a.alertType != 'collar_disconnected') {
        return false;
      }
      if (_selectedCategory == 'thi' && !a.alertType.startsWith('thi')) {
        return false;
      }
      if (_selectedCategory == 'health' && !a.alertType.startsWith('health') && a.alertType != 'vaccine_due') {
        return false;
      }
      if (_selectedCategory == 'geofence' && !a.alertType.startsWith('geofence')) {
        return false;
      }
      if (_selectedCategory == 'estrus' && a.alertType != 'estrus_detected' && a.alertType != 'birth_expected') {
        return false;
      }
      if (_selectedCategory == 'battery' && a.alertType != 'low_battery') {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unackCount = _alerts.where((a) => !a.acknowledged).length;
    final criticalCount = _alerts.where((a) => !a.acknowledged && (a.severity == 'emergency' || a.severity == 'danger')).length;
    final warningCount = _alerts.where((a) => !a.acknowledged && a.severity == 'warning').length;
    final infoCount = _alerts.where((a) => !a.acknowledged && a.severity == 'info').length;
    final ackCount = _alerts.where((a) => a.acknowledged).length;

    final filtered = _filteredAlerts;
    final emergencyAlerts = filtered.where((a) => a.severity == 'emergency' || a.severity == 'danger').toList();
    final otherAlerts = filtered.where((a) => a.severity != 'emergency' && a.severity != 'danger').toList();

    return Column(
      children: [
        // Top Action Bar + Severity KPIs
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: [
              // Header title and actions
              Row(
                children: [
                  Icon(
                    unackCount > 0 ? Icons.notifications_active_rounded : Icons.check_circle_rounded,
                    size: 20,
                    color: unackCount > 0 ? AppTheme.thiDanger : AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centro de Alertas y Telemetría Operativa',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Monitoreo activo de estrés calórico (THI), salud corporal y geocerca',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  if (unackCount > 0) ...[
                    OutlinedButton.icon(
                      onPressed: _acknowledgeAll,
                      icon: const Icon(Icons.done_all_rounded, size: 14),
                      label: const Text('Atender Todas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary.withAlpha(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilterChip(
                    avatar: Icon(Icons.filter_list_rounded, size: 13,
                        color: _showOnlyUnacknowledged ? AppTheme.primary : AppTheme.textSecondary),
                    label: Text(_showOnlyUnacknowledged ? 'Activas ($unackCount)' : 'Todas (${_alerts.length})',
                        style: const TextStyle(fontSize: 11)),
                    selected: _showOnlyUnacknowledged,
                    selectedColor: AppTheme.primary.withAlpha(25),
                    backgroundColor: AppTheme.surface,
                    onSelected: (_) {
                      setState(() => _showOnlyUnacknowledged = !_showOnlyUnacknowledged);
                      _loadAlerts();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 12),

              // KPI Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      label: 'Críticas',
                      count: criticalCount,
                      color: AppTheme.thiDanger,
                      icon: Icons.emergency_rounded,
                      isSelected: _selectedSeverity == 'critical',
                      onTap: () => setState(() => _selectedSeverity = _selectedSeverity == 'critical' ? null : 'critical'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      label: 'Advertencias',
                      count: warningCount,
                      color: AppTheme.thiAlert,
                      icon: Icons.warning_amber_rounded,
                      isSelected: _selectedSeverity == 'warning',
                      onTap: () => setState(() => _selectedSeverity = _selectedSeverity == 'warning' ? null : 'warning'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      label: 'Informativas',
                      count: infoCount,
                      color: AppTheme.primary,
                      icon: Icons.info_outline_rounded,
                      isSelected: _selectedSeverity == 'info',
                      onTap: () => setState(() => _selectedSeverity = _selectedSeverity == 'info' ? null : 'info'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      label: 'Atendidas',
                      count: ackCount,
                      color: AppTheme.textSecondary,
                      icon: Icons.check_circle_outline_rounded,
                      isSelected: !_showOnlyUnacknowledged,
                      onTap: () => setState(() {
                        _showOnlyUnacknowledged = !_showOnlyUnacknowledged;
                        _loadAlerts();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('all', 'Todas las categorías', Icons.apps_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryChip('thi', 'Estrés Térmico (THI)', Icons.thermostat_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryChip('health', 'Salud & Fiebre', Icons.medical_services_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryChip('geofence', 'Geocerca GPS', Icons.location_on_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryChip('estrus', 'Celo & Reprod.', Icons.favorite_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryChip('battery', 'Batería IoT', Icons.battery_alert_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryChip('disconnect', 'Desconexión IoT', Icons.sensors_off_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Alerts Layout (Responsive 2-Column on Desktop)
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 52, color: AppTheme.primary.withAlpha(90)),
                          const SizedBox(height: 12),
                          Text(
                            _selectedCategory != 'all' || _selectedSeverity != null
                                ? 'Sin alertas con ese filtro'
                                : 'Todo en orden en el rancho',
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No hay incidentes reportados para los criterios seleccionados.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          if (_selectedCategory != 'all' || _selectedSeverity != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _selectedCategory = 'all';
                                _selectedSeverity = null;
                              }),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Restablecer filtros'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 960;
                        if (isDesktop) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Critical
                                Expanded(
                                  child: _buildAlertList(
                                    'Alertas Críticas y Urgentes',
                                    emergencyAlerts,
                                    Icons.emergency_rounded,
                                    AppTheme.thiDanger,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Right Column: Operational / Info
                                Expanded(
                                  child: _buildAlertList(
                                    'Avisos de Manejo e Información',
                                    otherAlerts,
                                    Icons.info_outline_rounded,
                                    AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Mobile / Tablet: Vertical Stack
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAlertList(
                                'Alertas Críticas y Urgentes',
                                emergencyAlerts,
                                Icons.emergency_rounded,
                                AppTheme.thiDanger,
                              ),
                              const SizedBox(height: 14),
                              _buildAlertList(
                                'Avisos de Manejo e Información',
                                otherAlerts,
                                Icons.info_outline_rounded,
                                AppTheme.primary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : AppTheme.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label, IconData icon) {
    final isSelected = _selectedCategory == categoryKey;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = categoryKey),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertList(String title, List<AlertLog> alerts, IconData icon, Color titleColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: titleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: titleColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: titleColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: titleColor),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          alerts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(
                    child: Text(
                      'Sin incidentes en esta sección',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) => _buildAlertCard(alerts[index]),
                ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertLog alert) {
    final severityColors = {
      'emergency': AppTheme.thiEmergency,
      'danger': AppTheme.thiDanger,
      'warning': AppTheme.thiAlert,
      'info': AppTheme.primary,
    };
    final color = severityColors[alert.severity] ?? AppTheme.textSecondary;
    final severityIcon = switch (alert.severity) {
      'emergency' => Icons.crisis_alert_rounded,
      'danger' => Icons.warning_rounded,
      'warning' => Icons.warning_amber_rounded,
      'info' => Icons.info_outline_rounded,
      _ => Icons.circle,
    };
    final typeIcon = switch (alert.alertType) {
      'thi_danger' || 'thi_emergency' => Icons.thermostat_rounded,
      'health_fever' => Icons.local_hospital_rounded,
      'health_lethargy' => Icons.trending_down_rounded,
      'estrus_detected' => Icons.favorite_rounded,
      'geofence_exit' || 'geofence_enter' => Icons.location_off_rounded,
      'vaccine_due' => Icons.vaccines_rounded,
      'weight_loss' => Icons.trending_down_rounded,
      'low_battery' => Icons.battery_alert_rounded,
      'collar_disconnected' => Icons.sensors_off_rounded,
      _ => Icons.notifications_rounded,
    };

    return Dismissible(
      key: ValueKey('alert_${alert.id}_${alert.createdAt}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismissAlert(alert),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Atender', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 4),
            Icon(Icons.check_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: alert.acknowledged ? AppTheme.surface : color.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: alert.acknowledged ? AppTheme.divider : color.withAlpha(45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3.5,
              height: 48,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top alert badges row
                  Row(
                    children: [
                      Icon(severityIcon, size: 13, color: color),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _alertTypeLabel(alert.alertType),
                          style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(alert.createdAt),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 9.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Message
                  Text(
                    alert.message ?? alert.alertType,
                    style: TextStyle(
                      color: alert.acknowledged ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),

                  if (alert.acknowledged) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 11, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Atendida por ${alert.acknowledgedBy ?? "sistema"}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ],

                  // Action Button Strip
                  if (!alert.acknowledged) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (alert.deviceId != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 11, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  alert.deviceId!,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ] else ...[
                          const Spacer(),
                        ],

                        // Contextual Navigation Action: Collar Disconnected
                        if (alert.alertType == 'collar_disconnected') ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              if (widget.onNavigate != null) {
                                widget.onNavigate!(9);
                              }
                            },
                            icon: const Icon(Icons.radar_rounded, size: 12),
                            label: const Text('Rastrear LKP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () => _showFieldContingencyProtocolDialog(context, alert.deviceId ?? 'Collar-SmartRanch'),
                            icon: const Icon(Icons.checklist_rounded, size: 12),
                            label: const Text('Protocolo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE65100),
                              side: const BorderSide(color: Color(0xFFE65100)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // Contextual Navigation Action: GPS Map
                        if (widget.onNavigate != null && (alert.alertType.startsWith('geofence') || (alert.deviceId != null && alert.alertType != 'collar_disconnected'))) ...[
                          OutlinedButton.icon(
                            onPressed: () => widget.onNavigate!(9),
                            icon: const Icon(Icons.map_rounded, size: 12),
                            label: const Text('Ver GPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(color: AppTheme.primary.withAlpha(100)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // Contextual Navigation Action: Medical / Sanidad
                        if (widget.onNavigate != null && (alert.alertType.startsWith('health') || alert.alertType == 'vaccine_due')) ...[
                          OutlinedButton.icon(
                            onPressed: () => widget.onNavigate!(4),
                            icon: const Icon(Icons.medical_services_rounded, size: 12),
                            label: const Text('Sanidad', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.secondary,
                              side: BorderSide(color: AppTheme.secondary.withAlpha(100)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // Primary Dismiss / Acknowledge button
                        ElevatedButton.icon(
                          onPressed: () => _dismissAlert(alert),
                          icon: const Icon(Icons.check_rounded, size: 12),
                          label: const Text('Atender', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFieldContingencyProtocolDialog(BuildContext context, String deviceId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.divider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emergency_outlined, color: Color(0xFFE65100), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Protocolo de Contingencia IoT',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Procedimiento de búsqueda y campo para $deviceId',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE65100).withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFFE65100), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El collar no reporta datos recientes. Las coordenadas en pantalla corresponden a la Última Posición Conocida (LKP). Siga esta lista de verificación en campo.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildProtocolStep(
                  stepNumber: '1',
                  title: 'Localización del Punto LKP',
                  description: 'Diríjase al cuadrante GPS señalado en el mapa (Potrero Peñasco Norte). El radio de dispersión estimado del bovino es de 300m a 800m.',
                  icon: Icons.my_location_rounded,
                ),
                const SizedBox(height: 10),
                _buildProtocolStep(
                  stepNumber: '2',
                  title: 'Inspección Visual del Ejemplar',
                  description: 'Verifique si el animal se encuentra pastando normalmente, si sufrió algún percance en aguajes o cañadas, o si el collar se desprendió o atoró en mezquites.',
                  icon: Icons.pets_rounded,
                ),
                const SizedBox(height: 10),
                _buildProtocolStep(
                  stepNumber: '3',
                  title: 'Diagnóstico de Batería & Hardware',
                  description: 'Revise el indicador LED del collar ESP32. Si está apagado, la celda LiFePO4 / 18650 requiere recarga. Si parpadea pero no enlaza, el animal está en zona de sombra RF.',
                  icon: Icons.battery_alert_rounded,
                ),
                const SizedBox(height: 10),
                _buildProtocolStep(
                  stepNumber: '4',
                  title: 'Reconexión & Arreo Estratégico',
                  description: 'Si la falla se debe a cañadas o relieve sonorense, arree al grupo hacia mesetas despejadas para recuperar la señal con el Gateway LoRa/WiFi.',
                  icon: Icons.wifi_find_rounded,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (widget.onNavigate != null) {
                          widget.onNavigate!(9);
                        }
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('Ir al Mapa GPS (LKP)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolStep({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primary.withAlpha(30),
            child: Text(stepNumber, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(description, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _alertTypeLabel(String type) => switch (type) {
    'thi_danger' => 'THI Peligro',
    'thi_emergency' => 'THI Emergencia',
    'health_fever' => 'Fiebre',
    'health_lethargy' => 'Letargo',
    'health_sick' => 'Enfermedad',
    'estrus_detected' => 'Celo',
    'geofence_exit' => 'Fuera de zona',
    'geofence_enter' => 'Entró a zona',
    'vaccine_due' => 'Vacuna pendiente',
    'birth_expected' => 'Parto esperado',
    'weight_loss' => 'Pérdida de peso',
    'low_battery' => 'Batería baja',
    'collar_disconnected' => 'Desconexión IoT',
    _ => type,
  };

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }
}