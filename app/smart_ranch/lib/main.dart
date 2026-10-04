import 'dart:io';
import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/water_dashboard_screen.dart';
import 'screens/herd_screen.dart';
import 'screens/dashboard_home_screen.dart';
import 'screens/sanidad_screen.dart';
import 'screens/reproductive_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/gps_map_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/financial_screen.dart';
import 'screens/peso_screen.dart';
import 'screens/login_screen.dart';
import 'screens/report_screen.dart';
import 'screens/add_animal_screen.dart';
import 'screens/system_status_screen.dart';
import 'screens/settings_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/demo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase conectado exitosamente con smartranch-innova');
  } catch (e) {
    debugPrint('Firebase init: $e');
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop window — minimum size handled by framework
  }
  runApp(const SmartRanchApp());
}

class SmartRanchApp extends StatefulWidget {
  const SmartRanchApp({super.key});

  @override
  State<SmartRanchApp> createState() => _SmartRanchAppState();
}

class _SmartRanchAppState extends State<SmartRanchApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (AppTheme.currentThemeMode == ThemeMode.system) {
      setState(() {});
    }
    super.didChangePlatformBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Smart Ranch - Ganadería Inteligente',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Auth gate — shows login screen or main shell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _authenticated = false;

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return LoginScreen(
        onAuthenticated: () => setState(() => _authenticated = true),
      );
    }
    return MainShell(
      onLogout: () {
        AuthService.logout();
        setState(() => _authenticated = false);
      },
    );
  }
}

/// Desktop shell with NavigationRail sidebar.
class MainShell extends StatefulWidget {
  final VoidCallback? onLogout;
  const MainShell({super.key, this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _sidebarExtended = true;
  final DemoService _demoService = DemoService();

  static const _sections = [
    _Section(
      index: 0,
      label: 'Inicio',
      icon: Icons.dashboard_rounded,
      group: 'OPERACIONES & TELEMETRÍA',
    ),
    _Section(
      index: 1,
      label: 'Monitor THI',
      icon: Icons.thermostat_rounded,
      group: 'OPERACIONES & TELEMETRÍA',
    ),
    _Section(
      index: 2,
      label: 'Agua & Bebederos',
      icon: Icons.water_drop_rounded,
      group: 'OPERACIONES & TELEMETRÍA',
    ),
    _Section(
      index: 9,
      label: 'GPS / Mapa',
      icon: Icons.map_rounded,
      group: 'OPERACIONES & TELEMETRÍA',
    ),
    _Section(
      index: 6,
      label: 'Alertas',
      icon: Icons.notifications_active_rounded,
      group: 'OPERACIONES & TELEMETRÍA',
    ),

    _Section(
      index: 3,
      label: 'Inventario de Hato',
      icon: Icons.inventory_2_rounded,
      group: 'GESTIÓN GANADERA',
    ),
    _Section(
      index: 4,
      label: 'Sanidad & Vacunas',
      icon: Icons.medical_services_rounded,
      group: 'GESTIÓN GANADERA',
    ),
    _Section(
      index: 5,
      label: 'Reproducción & Celo',
      icon: Icons.favorite_rounded,
      group: 'GESTIÓN GANADERA',
    ),
    _Section(
      index: 7,
      label: 'Control de Peso',
      icon: Icons.monitor_weight_rounded,
      group: 'GESTIÓN GANADERA',
    ),
    _Section(
      index: 8,
      label: 'Alimentación',
      icon: Icons.restaurant_rounded,
      group: 'GESTIÓN GANADERA',
    ),
    _Section(
      index: 12,
      label: 'Registrar Animal',
      icon: Icons.add_circle_outline_rounded,
      group: 'GESTIÓN GANADERA',
      isHighlight: true,
    ),

    _Section(
      index: 10,
      label: 'Finanzas',
      icon: Icons.account_balance_rounded,
      group: 'SISTEMA & REPORTES',
    ),
    _Section(
      index: 11,
      label: 'Reportes',
      icon: Icons.analytics_rounded,
      group: 'SISTEMA & REPORTES',
    ),
    _Section(
      index: 13,
      label: 'Configuración',
      icon: Icons.settings_rounded,
      group: 'SISTEMA & REPORTES',
    ),
    _Section(
      index: 14,
      label: 'Estado Sistema',
      icon: Icons.dns_rounded,
      group: 'SISTEMA & REPORTES',
    ),
  ];

  _Section get _currentSection => _sections.firstWhere(
        (s) => s.index == _selectedIndex,
        orElse: () => _sections[0],
      );

  @override
  void initState() {
    super.initState();
    _demoService.start();
    _demoService.addListener(_onDemoUpdated);
  }

  void _onDemoUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _demoService.removeListener(_onDemoUpdated);
    _demoService.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    setState(() => _selectedIndex = index);
  }

  String? _getBadgeForSection(int index) {
    if (index == 6) {
      final count = _demoService.activeEstrusAlerts.length +
          _demoService.activeHealthAlerts.length;
      if (count > 0) return '$count';
    } else if (index == 1) {
      final hasDanger = _demoService.latestReadings.values.any(
        (r) => r.thiLevel == 'danger' || r.thiLevel == 'emergency',
      );
      if (hasDanger) return '!';
    } else if (index == 9) {
      final hasCollarDisconnected = _demoService.isCollarSimulatedDisconnected ||
          _demoService.latestReadings.values.any((r) => !_demoService.isCollarOnline(r.deviceId));
      if (hasCollarDisconnected) return 'LKP';
    }
    return null;
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return DashboardHomeScreen(
          onNavigate: _navigateTo,
          demoService: _demoService,
        );
      case 1:
        return DashboardScreen(demoService: _demoService);
      case 2:
        return WaterDashboardScreen(demoService: _demoService);
      case 3:
        return HerdScreen(demoService: _demoService, onNavigate: _navigateTo);
      case 4:
        return SanidadScreen(demoService: _demoService);
      case 5:
        return ReproductiveScreen(demoService: _demoService);
      case 6:
        return AlertsScreen(demoService: _demoService, onNavigate: _navigateTo);
      case 7:
        return const PesoScreen();
      case 8:
        return FeedScreen(demoService: _demoService, onNavigate: _navigateTo);
      case 9:
        return GpsMapScreen(demoService: _demoService);
      case 10:
        return FinancialScreen(demoService: _demoService, onNavigate: _navigateTo);
      case 11:
        return ReportScreen(demoService: _demoService, onNavigate: _navigateTo);
      case 12:
        return AddAnimalScreen(demoService: _demoService, onNavigate: _navigateTo);
      case 13:
        return SettingsScreen(demoService: _demoService, onNavigate: _navigateTo);
      case 14:
        return SystemStatusScreen(demoService: _demoService, onNavigate: _navigateTo);
      default:
        return const Center(child: Text('Pantalla no encontrada'));
    }
  }

  Widget _buildSidebarHeader({required bool isExtended}) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isExtended ? 16 : 14),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          InkWell(
            onTap: !isExtended ? () => setState(() => _sidebarExtended = true) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withAlpha(40)),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          if (isExtended) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Ranch',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ganadería Inteligente',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.menu_open_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              tooltip: 'Colapsar barra lateral',
              onPressed: () => setState(() => _sidebarExtended = false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarFooter({required bool isExtended, required bool isMobile}) {
    final name = AuthService.displayName.isNotEmpty
        ? AuthService.displayName
        : 'Administrador';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final ranchName = AuthService.ranchName.isNotEmpty
        ? AuthService.ranchName
        : 'Rancho Puerto Peñasco';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: AppTheme.divider),

        // User Profile Capsule
        if (isExtended) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary.withAlpha(30),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          ranchName,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Connection Status & Logout
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: isMobile ? 8 : 6,
          ),
          child: Row(
            children: [
              // IoT Connection Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _demoService.isRunning
                        ? AppTheme.primary
                        : AppTheme.thiEmergency,
                    boxShadow: _demoService.isRunning
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withAlpha(120),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              if (isExtended) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _demoService.isRunning
                        ? 'IoT En línea'
                        : 'Desconectado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),

              // Logout Button
              _LogoutButton(
                extended: isExtended,
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  widget.onLogout?.call();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar({required bool isMobile}) {
    final width = isMobile ? 270.0 : (_sidebarExtended ? 240.0 : 72.0);
    final isExtended = isMobile || _sidebarExtended;

    // Group sections by category
    final Map<String, List<_Section>> grouped = {};
    for (final s in _sections) {
      grouped.putIfAbsent(s.group, () => []).add(s);
    }

    Widget sidebar = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: AppTheme.surface,
      child: Column(
        children: [
          // Brand Header
          _buildSidebarHeader(isExtended: isExtended),
          Divider(height: 1, color: AppTheme.divider),

          // Scrollable Nav Groups
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries.map((entry) {
                  final groupName = entry.key;
                  final items = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isExtended)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(
                            groupName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppTheme.textSecondary.withAlpha(160),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppTheme.divider,
                          ),
                        ),
                      ...items.map((section) {
                        final selected = section.index == _selectedIndex;
                        final badge = _getBadgeForSection(section.index);

                        return _NavItem(
                          icon: section.icon,
                          label: section.label,
                          selected: selected,
                          extended: isExtended,
                          badge: badge,
                          isHighlight: section.isHighlight,
                          onTap: () {
                            setState(() => _selectedIndex = section.index);
                            if (isMobile) {
                              Navigator.pop(context); // Close drawer
                            }
                          },
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Sidebar Footer
          _buildSidebarFooter(isExtended: isExtended, isMobile: isMobile),
        ],
      ),
    );

    if (isMobile) return SafeArea(child: sidebar);
    return sidebar;
  }

  Widget _buildDesktopTopBar() {
    final current = _currentSection;
    final alertCount = _demoService.activeEstrusAlerts.length +
        _demoService.activeHealthAlerts.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showSearch = constraints.maxWidth > 920;
        final bool showFullRanch = constraints.maxWidth > 650;

        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.divider, width: 1)),
          ),
          child: Row(
            children: [
              // Sidebar toggle if collapsed
              if (!_sidebarExtended) ...[
                IconButton(
                  icon: Icon(Icons.menu_rounded, size: 20, color: AppTheme.textPrimary),
                  tooltip: 'Expandir barra lateral',
                  onPressed: () => setState(() => _sidebarExtended = true),
                ),
                const SizedBox(width: 8),
              ],

              // Breadcrumb & Current Section
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(current.icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showFullRanch) ...[
                      Flexible(
                        child: Text(
                          AuthService.ranchName.isNotEmpty
                              ? AuthService.ranchName
                              : 'Rancho Puerto Peñasco',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '  /  ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary.withAlpha(120),
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        current.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (showSearch) ...[
                const SizedBox(width: 12),
                // Quick Jump / Search Box
                Container(
                  height: 36,
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Buscar...',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(
                          'Ctrl K',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 12),

              // Quick Action Button: + Registrar Animal
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Registrar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _navigateTo(12),
              ),
              const SizedBox(width: 8),

          // Notification Bell with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  alertCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: alertCount > 0 ? AppTheme.thiDanger : AppTheme.textSecondary,
                  size: 20,
                ),
                tooltip: 'Alertas del sistema',
                onPressed: () => _navigateTo(6),
              ),
              if (alertCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.thiDanger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                ),
            ],
          ),

          // Theme Quick Toggle
          IconButton(
            icon: Icon(
              AppTheme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            tooltip: AppTheme.isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
            onPressed: () {
              AppTheme.toggleTheme();
              setState(() {});
            },
          ),
        ],
      ),
    );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        final content = Column(
          children: [
            // Modern Desktop TopBar
            if (!isMobile) _buildDesktopTopBar(),

            // Screen Body
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: _buildScreen(_selectedIndex),
              ),
            ),
          ],
        );

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.textPrimary,
              iconTheme: IconThemeData(color: AppTheme.textPrimary),
              centerTitle: false,
              toolbarHeight: 56,
              elevation: 0,
              shape: Border(bottom: BorderSide(color: AppTheme.divider, width: 1)),
              titleSpacing: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _currentSection.icon,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currentSection.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Alertas',
                  onPressed: () => _navigateTo(6),
                ),
                IconButton(
                  icon: Icon(
                    AppTheme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  tooltip: AppTheme.isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                  onPressed: () {
                    AppTheme.toggleTheme();
                    setState(() {});
                  },
                ),
                const SizedBox(width: 6),
              ],
            ),
            drawer: Drawer(
              backgroundColor: AppTheme.surface,
              child: _buildSidebar(isMobile: true),
            ),
            body: content,
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _buildSidebar(isMobile: false),
              VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _Section {
  final int index;
  final String label;
  final IconData icon;
  final String group;
  final bool isHighlight;

  const _Section({
    required this.index,
    required this.label,
    required this.icon,
    required this.group,
    this.isHighlight = false,
  });
}

/// Custom sidebar navigation item with hover, active accent bar, and badge states.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final String? badge;
  final bool isHighlight;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    this.badge,
    this.isHighlight = false,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;

    Color bgColor = Colors.transparent;
    if (widget.selected) {
      bgColor = AppTheme.primary.withAlpha(isDark ? 35 : 22);
    } else if (_hovered) {
      bgColor = AppTheme.surfaceVariant;
    } else if (widget.isHighlight) {
      bgColor = AppTheme.primary.withAlpha(8);
    }

    Border? border;
    if (widget.selected) {
      border = Border.all(color: AppTheme.primary.withAlpha(60));
    } else if (widget.isHighlight) {
      border = Border.all(color: AppTheme.primary.withAlpha(35));
    }

    final iconColor = widget.selected
        ? AppTheme.primary
        : _hovered
            ? (isDark ? AppTheme.textPrimary : AppTheme.primary)
            : (widget.isHighlight ? AppTheme.primary : AppTheme.textSecondary);

    final textColor = widget.selected
        ? (isDark ? Colors.white : AppTheme.primary)
        : _hovered
            ? AppTheme.textPrimary
            : (widget.isHighlight ? AppTheme.primary : AppTheme.textPrimary.withAlpha(210));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Tooltip(
        message: !widget.extended ? widget.label : '',
        waitDuration: const Duration(milliseconds: 300),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 42,
              padding: EdgeInsets.symmetric(horizontal: widget.extended ? 10 : 0),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: border,
              ),
              child: Row(
                mainAxisAlignment: widget.extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (widget.selected && widget.extended)
                    Container(
                      width: 3.5,
                      height: 18,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Icon(widget.icon, size: 20, color: iconColor),
                  if (widget.extended) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : widget.isHighlight
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.badge == '!'
                              ? AppTheme.thiDanger
                              : AppTheme.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logout button styled cleanly for collapsed and expanded sidebar states.
class _LogoutButton extends StatefulWidget {
  final bool extended;
  final VoidCallback onTap;

  const _LogoutButton({required this.extended, required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const logoutColor = Color(0xFFFF5252);
    final bgColor = _hovered ? logoutColor.withAlpha(20) : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: widget.extended ? 10 : 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded, color: logoutColor, size: 18),
              if (widget.extended) ...[
                const SizedBox(width: 8),
                const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    color: logoutColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
