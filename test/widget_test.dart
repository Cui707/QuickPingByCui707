import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quickpingbycui707/main.dart';
import 'package:quickpingbycui707/models/ip_model.dart';
import 'package:quickpingbycui707/providers/ping_provider.dart';

void main() {
  Widget buildTestApp({PingProvider? provider}) {
    return MaterialApp(
      home: ChangeNotifierProvider<PingProvider>(
        create: (_) => provider ?? PingProvider(),
        child: const HomePage(),
      ),
    );
  }

  group('HomePage UI', () {
    testWidgets('shows subnet field with default value', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.text('192.168.1'), findsWidgets);
      expect(find.text('网段:'), findsOneWidget);
    });

    testWidgets('shows header controls', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.text('超时(ms):'), findsOneWidget);
      expect(find.text('线程:'), findsOneWidget);
      expect(find.text('详细信息:'), findsOneWidget);
      expect(find.text('开始扫描'), findsOneWidget);
      expect(find.text('保存 Excel'), findsOneWidget);
    });

    testWidgets('changing subnet regenerates grid', (tester) async {
      final provider = PingProvider();
      await tester.pumpWidget(buildTestApp(provider: provider));
      await tester.pump();

      provider.changeSubnet('10.0.0');

      expect(provider.subnetPrefix, '10.0.0');
      expect(provider.tasks.length, 256);
      expect(provider.tasks[0].ip, '10.0.0.0');
    });

    testWidgets('invalid subnet does not change tasks', (tester) async {
      final provider = PingProvider();
      await tester.pumpWidget(buildTestApp(provider: provider));
      await tester.pump();

      final tasksBefore = provider.tasks.map((t) => t.ip).toList();
      provider.changeSubnet('');
      provider.changeSubnet('bad.input');

      expect(provider.tasks.map((t) => t.ip).toList(), tasksBefore);
    });

    testWidgets('re-detect button is present', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('list view shows MAC and device info columns', (tester) async {
      final provider = PingProvider();
      provider.tasks[0]
        ..status = IpStatus.local
        ..latency = 0
        ..macAddress = 'AA-BB-CC-DD-EE-FF'
        ..deviceType = '本机';
      provider.tasks[1]
        ..status = IpStatus.success
        ..latency = 2
        ..macAddress = '11-22-33-44-55-66'
        ..deviceType = 'Router (TP-Link)';

      await tester.pumpWidget(buildTestApp(provider: provider));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.list));
      await tester.pump();

      expect(find.text('MAC地址'), findsOneWidget);
      expect(find.text('设备信息'), findsOneWidget);
      expect(find.text('AA-BB-CC-DD-EE-FF'), findsOneWidget);
      expect(find.text('本机'), findsOneWidget);
      expect(find.text('Router (TP-Link)'), findsOneWidget);
    });

    testWidgets('detailed mode switch defaults off', (tester) async {
      final provider = PingProvider();
      await tester.pumpWidget(buildTestApp(provider: provider));
      await tester.pump();

      expect(provider.detailedMode, false);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('toggling detailed mode updates provider', (tester) async {
      final provider = PingProvider();
      await tester.pumpWidget(buildTestApp(provider: provider));
      await tester.pump();

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(provider.detailedMode, true);
    });

    testWidgets('stop button is enabled when scanning', (tester) async {
      final provider = PingProvider();
      await tester.pumpWidget(buildTestApp(provider: provider));
      await tester.pump();

      final stopButton = find.text('停止');
      expect(stopButton, findsOneWidget);
      final stopWidget = tester.widget<ElevatedButton>(
        find.ancestor(of: stopButton, matching: find.byType(ElevatedButton)).last,
      );
      expect(stopWidget.onPressed, isNull);

      provider.isScanning = true;
      provider.notifyListeners();
      await tester.pump();

      final stopWidget2 = tester.widget<ElevatedButton>(
        find.ancestor(of: stopButton, matching: find.byType(ElevatedButton)).last,
      );
      expect(stopWidget2.onPressed, isNotNull);
    });
  });
}
