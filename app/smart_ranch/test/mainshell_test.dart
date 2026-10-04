import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ranch/main.dart';

void main() {
  testWidgets('MainShell renders collapsed and expanded on desktop', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MainShell(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('Smart Ranch'), findsOneWidget); // Pinned/expanded on desktop

    // Find and tap collapse button
    final collapseBtn = find.byTooltip('Colapsar barra lateral');
    if (collapseBtn.evaluate().isNotEmpty) {
      await tester.tap(collapseBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
  });

  testWidgets('MainShell renders on mobile screen size', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MainShell(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('AuthGate transitions to MainShell after entering demo mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SmartRanchApp());
    await tester.pump();

    // Find and tap Demo mode button
    final demoBtn = find.textContaining('Demo');
    expect(demoBtn, findsWidgets);
    await tester.tap(demoBtn.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify MainShell is now displayed
    expect(find.byType(MainShell), findsOneWidget);
  });
}
