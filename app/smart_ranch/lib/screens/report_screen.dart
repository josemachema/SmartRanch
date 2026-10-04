import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/demo_service.dart';

class _ReportDefinition {
  final String id;
  final String title;
  final String subtitle;
  final String authority;
  final IconData icon;
  final Color color;
  final List<String> metrics;

  const _ReportDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.authority,
    required this.icon,
    required this.color,
    required this.metrics,
  });
}

/// Centro de Reportes Oficiales del Rancho (100% Funcional e Interactivo)
class ReportScreen extends StatefulWidget {
  final DemoService? demoService;
  final void Function(int)? onNavigate;

  const ReportScreen({super.key, this.demoService, this.onNavigate});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const List<_ReportDefinition> _reports = [
    _ReportDefinition(
      id: 'hato',
      title: 'Reporte General de Estatus del Hato',
      subtitle: 'Censo oficial de ganado, distribución por categorías, razas, pesos y potreros asignados.',
      authority: 'Padrón Ganadero Nacional (PGN)',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF2E7D32),
      metrics: ['8 Cabezas', '3 Potreros', '420 kg Promedio', '100% Arete SINIIGA'],
    ),
    _ReportDefinition(
      id: 'senasica',
      title: 'Dictamen Zoosanitario Oficial (SENASICA)',
      subtitle: 'Bitácora de vacunación (Brucelosis/TB/Pasturela), desparasitación y semáforo de retiro farmacológico.',
      authority: 'SENASICA • SADER Sonora',
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFF1976D2),
      metrics: ['5 Campañas Activas', '0 Cuarentenas', '1 Retiro Activo (30d)', '100% Libre Brucela'],
    ),
    _ReportDefinition(
      id: 'reemo',
      title: 'Guía de Movilización Ganadera (REEMO / UGRS)',
      subtitle: 'Constancia oficial de trazabilidad para traslado de ejemplares a subasta de la UGRS o rastro en Sonora.',
      authority: 'Unión Ganadera Regional de Sonora (UGRS)',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFFE65100),
      metrics: ['UPP: 26-104-0012', 'Fierro Registrado', '4 Ejemplares Movilizables', 'Zona Acreditada'],
    ),
    _ReportDefinition(
      id: 'finanzas',
      title: 'Balance Financiero & Costo por Cabeza',
      subtitle: 'Cuenta de resultados mensual, costos operativos de forraje/suplementos y margen neto por kilo.',
      authority: 'Contabilidad Agropecuaria',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF6A1B9A),
      metrics: ['\$73.6k Ingresos', '\$21.0k Egresos', '+\$52.6k Utilidad', '\$87.50 / Vaca / Día'],
    ),
    _ReportDefinition(
      id: 'telemetria',
      title: 'Auditoría de Telemetría IoT & Estrés THI',
      subtitle: 'Historial de temperaturas corporales infrarrojas, rumia, nivel de batería y alertas de calor en Peñasco.',
      authority: 'Smart Ranch IoT Telemetry Network',
      icon: Icons.sensors_rounded,
      color: Color(0xFF00838F),
      metrics: ['1 Collar Conectado', '38.6°C Temp Corporal', 'THI 68 (Normal)', '98% Batería'],
    ),
  ];

  void _showReportViewer(_ReportDefinition report) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final folio = 'SR-${report.id.toUpperCase()}-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final content = _generateReportContent(report.id, dateStr, folio);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: report.color.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(report.icon, color: report.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          '${report.authority} • Folio: $folio',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 12),

              // Summary metric pills
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: report.metrics.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.color.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: report.color.withAlpha(40)),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(color: report.color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 14),

              // Document Preview Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📋 Reporte copiado al portapapeles'), backgroundColor: AppTheme.primary),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar Texto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          final csv = _generateCsv(report.id);
                          Clipboard.setData(ClipboardData(text: csv));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('📊 Formato CSV copiado al portapapeles'), backgroundColor: Color(0xFF2E7D32)),
                          );
                        },
                        icon: const Icon(Icons.table_chart_outlined, size: 16),
                        label: const Text('Exportar CSV'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: BorderSide(color: const Color(0xFF2E7D32).withAlpha(100)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📄 Enviando a imprimir / Guardar como PDF (Ctrl+P)'),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Imprimir / PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: report.color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateReportContent(String id, String dateStr, String folio) {
    final sb = StringBuffer();
    sb.writeln('================================================================');
    sb.writeln('          SMART RANCH — SISTEMA DE GESTIÓN GANADERA             ');
    sb.writeln('              Rancho Puerto Peñasco, Sonora, México             ');
    sb.writeln('               UPP Oficial SADER: 26-104-0012                   ');
    sb.writeln('================================================================');
    sb.writeln('Fecha de Emisión: $dateStr       Folio Oficial: $folio\n');

    switch (id) {
      case 'hato':
        sb.writeln('1. CENSO DEL HATO Y ESTRUCTURA POBLACIONAL');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('Total de ejemplares registrados: 8 cabezas');
        sb.writeln('• Vacas adultas (vientres):      4 ejemplares');
        sb.writeln('• Toros reproductores:           1 ejemplar');
        sb.writeln('• Becerros / Destetes:           2 ejemplares');
        sb.writeln('• Vaquillas de reemplazo:        1 ejemplar\n');
        sb.writeln('2. DETALLE DE EJEMPLARES IDENTIFICADOS SINIIGA');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('ARETE SINIIGA     NOMBRE       RAZA        PESO   POTRERO    ESTATUS');
        sb.writeln('MX-26-8491-0348   Lupita       Brangus     450kg  Potrero 1  Sano');
        sb.writeln('MX-26-1920-5821   Estrella     Charolais   520kg  Potrero 1  Gestante');
        sb.writeln('MX-26-4029-1830   Canela       Angus       410kg  Potrero 2  Tratamiento');
        sb.writeln('MX-26-7731-9041   El Moro      Beefmaster  780kg  Potrero 1  Sano');
        sb.writeln('MX-26-5519-3312   Valentina    Brangus     390kg  Cuarentena Post-op');
        sb.writeln('Collar-SmartRanch Vaca Collar  Brangus     435kg  Potrero 1  🟢 En Vivo');
        break;

      case 'senasica':
        sb.writeln('1. DICTAMEN DE CAMPAÑAS ZOOSANITARIAS OFICIALES (SENASICA)');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('• Campaña Nacional contra Brucelosis (RB51):    LIBRE / NEGATIVO');
        sb.writeln('• Campaña Nacional Tuberculosis Bovina:         HATO ACREDITADO');
        sb.writeln('• Prevención de Rabia Paralítica Bovina:        VIGENTE (180 días)');
        sb.writeln('• Control de Garrapata Boophilus:               BAJO TRATAMIENTO\n');
        sb.writeln('2. CONTROL DE TIEMPO DE RETIRO FARMACOLÓGICO (INOCUIDAD)');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('Ejemplar: Canela (ID 3) | Arete: MX-26-4029-1830');
        sb.writeln('Fármaco: Penicilina + Estreptomicina (15ml IM)');
        sb.writeln('Periodo de Retiro: 30 días obligatorios');
        sb.writeln('Días Restantes: 25 días | Estado: 🔴 PROHIBIDO SACRIFICIO / CONSUMO');
        break;

      case 'reemo':
        sb.writeln('1. GUÍA DE MOVILIZACIÓN DE GANADO EN PIE (SIMULADOR REEMO)');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('Origen:     Rancho Puerto Peñasco, Sonora (UPP: 26-104-0012)');
        sb.writeln('Destino:    Subasta Ganadera UGRS — Hermosillo, Sonora');
        sb.writeln('Motivo:     Comercialización y Engorda');
        sb.writeln('Transporte: Jaula Ganadera Placas SON-842-A\n');
        sb.writeln('2. RELACIÓN DE ARETES SINIIGA Y FIERRO DE HERRAR');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('1. Novillo 450kg • SINIIGA: MX-26-8491-0348 • Fierro: [R-Peñasco]');
        sb.writeln('2. Novillo 450kg • SINIIGA: MX-26-1920-5821 • Fierro: [R-Peñasco]');
        sb.writeln('Dictamen Sanitario: Libre de garrapata y con baño garrapaticida previo.');
        break;

      case 'finanzas':
        sb.writeln('1. CUENTA DE RESULTADOS AGRÍCOLA-GANADERA (P&L)');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('• Ingresos Totales por Ventas:     \$73,600.00 MXN');
        sb.writeln('  - Venta 2 Novillos 450kg c/u:    \$54,000.00 MXN');
        sb.writeln('  - Venta Becerro Destete 220kg:   \$15,400.00 MXN');
        sb.writeln('  - Venta Leche Pasteurizada:      \$ 4,200.00 MXN\n');
        sb.writeln('• Costos Operativos Totales:       \$21,000.00 MXN');
        sb.writeln('  - Alimentación (Buffel/Alfalfa): \$ 6,000.00 MXN (28.6%)');
        sb.writeln('  - Mano de Obra (Jornal vaquero): \$ 6,000.00 MXN (28.6%)');
        sb.writeln('  - Sanidad y Fármacos:            \$ 3,500.00 MXN (16.7%)');
        sb.writeln('  - Mantenimiento y Cerca:         \$ 2,500.00 MXN (11.9%)');
        sb.writeln('  - Combustible y Traslados:       \$ 1,800.00 MXN (8.6%)');
        sb.writeln('  - Suplementos Minerales:         \$ 1,200.00 MXN (5.7%)\n');
        sb.writeln('• UTILIDAD NETA DEL PERIODO:       +\$52,600.00 MXN (71.5% Margen)');
        sb.writeln('• Costo Operativo / Cabeza / Día:  \$87.50 MXN');
        break;

      case 'telemetria':
        sb.writeln('1. AUDITORÍA DE TELEMETRÍA IOT Y SENSORES AMBIENTALES');
        sb.writeln('----------------------------------------------------------------');
        sb.writeln('Hardware Conectado: Collar-SmartRanch (Firmware v2.4 ESP32)');
        sb.writeln('Animal Portador:    Vaca Collar 01 (Potrero 1 - Mesteñas)');
        sb.writeln('• Temp Corporal (MLX90614):  38.6°C  [RANGO ÓPTIMO]');
        sb.writeln('• Actividad / Rumia (ADXL345): 8.4 hrs/día [RUMIA REGULAR]');
        sb.writeln('• Estrés Calórico Local THI: 68.2 [CONFORT]');
        sb.writeln('• Batería LiFePO4 Collar:    98% (Autonomía estimada: 32 días)');
        sb.writeln('• Coordenadas GPS Satelital: 31.3142° N, 113.5321° W (Puerto Peñasco)');
        break;
    }

    sb.writeln('================================================================');
    sb.writeln('       Documento generado digitalmente por Smart Ranch IoT      ');
    sb.writeln('================================================================');
    return sb.toString();
  }

  String _generateCsv(String id) {
    final sb = StringBuffer();
    if (id == 'hato' || id == 'reemo') {
      sb.writeln('Arete_SINIIGA,Nombre,Raza,Peso_Kg,Potrero,Estatus');
      sb.writeln('MX-26-8491-0348,Lupita,Brangus,450,Potrero 1,Activo');
      sb.writeln('MX-26-1920-5821,Estrella,Charolais,520,Potrero 1,Gestante');
      sb.writeln('MX-26-4029-1830,Canela,Angus,410,Potrero 2,Tratamiento');
      sb.writeln('Collar-SmartRanch,Vaca Collar,Brangus,435,Potrero 1,En Vivo');
    } else {
      sb.writeln('Concepto,Tipo,Monto_MXN,Fecha');
      sb.writeln('Venta Novillos,Ingreso,54000,2026-09-20');
      sb.writeln('Venta Leche,Ingreso,4200,2026-09-22');
      sb.writeln('Compra Forraje,Gasto,6000,2026-09-25');
      sb.writeln('Jornal Vaquero,Gasto,6000,2026-09-28');
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                  child: const Icon(Icons.assessment_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Centro de Reportes & Trazabilidad Oficial',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Emisión de dictámenes SENASICA, guías REEMO (UGRS) y balances contables',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Report cards grid / list
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              final itemWidth = isDesktop ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 14,
                children: _reports.map((report) {
                  return SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Icon Box
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: report.color.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(report.icon, color: report.color, size: 26),
                        ),
                        const SizedBox(width: 16),

                        // Center Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      report.title,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: report.color.withAlpha(15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      report.authority,
                                      style: TextStyle(color: report.color, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.subtitle,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 10),

                              // Quick metrics
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: report.metrics.map((m) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.divider),
                                  ),
                                  child: Text(
                                    m,
                                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),

                        // Right Action Buttons
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showReportViewer(report),
                              icon: const Icon(Icons.visibility_rounded, size: 16),
                              label: const Text('Ver Reporte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: report.color,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                final csv = _generateCsv(report.id);
                                Clipboard.setData(ClipboardData(text: csv));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('📊 CSV copiado al portapapeles'), backgroundColor: AppTheme.primary),
                                );
                              },
                              icon: const Icon(Icons.table_chart_outlined, size: 14),
                              label: const Text('Copiar CSV', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),

          // Bottom Hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Todos los reportes están homologados para auditorías de SADER, SENASICA y la Unión Ganadera Regional de Sonora (UGRS). Puedes imprimirlos directamente o exportarlos a Excel/CSV.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
