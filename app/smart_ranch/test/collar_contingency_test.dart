import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ranch/services/auth_service.dart';
import 'package:smart_ranch/services/demo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IoT Collar Disconnection Contingency & LKP Tests', () {
    late DemoService demoService;

    setUp(() {
      AuthService.enterDemoMode();
      demoService = DemoService();
      demoService.start();
    });

    tearDown(() {
      demoService.dispose();
    });

    test('Initial state: demo service initializes with active collar', () {
      expect(demoService.isCollarSimulatedDisconnected, isFalse);
      final readings = demoService.latestReadings;
      expect(readings.isNotEmpty, isTrue);

      final hasCollar = readings.keys.any((k) => k == 'Collar-SmartRanch' || k.toLowerCase().contains('collar'));
      expect(hasCollar, isTrue);
    });

    test('Simulating collar disconnection triggers contingency watchdog', () {
      const deviceId = 'Collar-SmartRanch';

      // 1. Initial online check
      expect(demoService.isCollarOnline(deviceId), isTrue);

      // 2. Simulate disconnection
      demoService.simulateCollarDisconnect(true);

      // 3. Verify disconnected state
      expect(demoService.isCollarSimulatedDisconnected, isTrue);
      expect(demoService.isCollarOnline(deviceId), isFalse);

      // 4. Verify elapsed time since last packet
      final elapsed = demoService.timeSinceLastCollarPacket(deviceId);
      expect(elapsed, isNotNull);
      expect(elapsed!.inMinutes, greaterThanOrEqualTo(15));

      // 5. Verify Last Known Position (LKP) is preserved
      final lkp = demoService.getLastKnownPosition(deviceId);
      expect(lkp, isNotNull);
      expect(lkp!.deviceId, equals(deviceId));
      expect(lkp.latitude, isNotNull);
      expect(lkp.longitude, isNotNull);
    });

    test('Reconnecting collar restores online telemetry and heartbeat', () {
      const deviceId = 'Collar-SmartRanch';

      demoService.simulateCollarDisconnect(true);
      expect(demoService.isCollarOnline(deviceId), isFalse);

      // Reconnect
      demoService.simulateCollarDisconnect(false);
      expect(demoService.isCollarSimulatedDisconnected, isFalse);
      expect(demoService.isCollarOnline(deviceId), isTrue);
      expect(demoService.lastCollarHeartbeat, isNotNull);
    });
  });
}
