import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ranch/screens/gps_map_screen.dart';
import 'package:smart_ranch/services/demo_service.dart';

void main() {
  testWidgets('GpsMapScreen renders correctly and shows map controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GpsMapScreen(
            demoService: demoService,
            enableMqtt: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GpsMapScreen), findsOneWidget);
    expect(find.textContaining('Puerto Peñasco, Sonora'), findsOneWidget);
    expect(find.byTooltip('Mi ubicación GPS'), findsOneWidget);

    // Cleanly unmount GpsMapScreen to invoke dispose()
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    demoService.dispose();
  });
}
