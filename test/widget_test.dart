import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quickpingbycui707/main.dart';
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
  });
}
