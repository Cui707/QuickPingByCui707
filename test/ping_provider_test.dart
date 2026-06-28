import 'package:flutter_test/flutter_test.dart';
import 'package:quickpingbycui707/providers/ping_provider.dart';
import 'package:quickpingbycui707/models/ip_model.dart';

void main() {
  group('PingProvider.isValidSubnetPrefix', () {
    test('valid prefixes', () {
      expect(PingProvider.isValidSubnetPrefix('192.168.1'), true);
      expect(PingProvider.isValidSubnetPrefix('10.0.0'), true);
      expect(PingProvider.isValidSubnetPrefix('172.16.0'), true);
      expect(PingProvider.isValidSubnetPrefix('0.0.0'), true);
      expect(PingProvider.isValidSubnetPrefix('255.255.255'), true);
    });

    test('invalid prefixes', () {
      expect(PingProvider.isValidSubnetPrefix(''), false);
      expect(PingProvider.isValidSubnetPrefix('192.168'), false);
      expect(PingProvider.isValidSubnetPrefix('192.168.1.1'), false);
      expect(PingProvider.isValidSubnetPrefix('192.168.1.'), false);
      expect(PingProvider.isValidSubnetPrefix('abc.def.ghi'), false);
      expect(PingProvider.isValidSubnetPrefix('256.0.0'), false);
      expect(PingProvider.isValidSubnetPrefix('192.-1.1'), false);
      expect(PingProvider.isValidSubnetPrefix('192.168'), false);
    });
  });

  group('PingProvider.changeSubnet', () {
    test('changes subnet and regenerates tasks', () {
      final provider = PingProvider();
      expect(provider.subnetPrefix, '192.168.1');
      expect(provider.tasks.length, 256);
      expect(provider.tasks[0].ip, '192.168.1.0');
      expect(provider.tasks[255].ip, '192.168.1.255');

      provider.changeSubnet('10.0.0');
      expect(provider.subnetPrefix, '10.0.0');
      expect(provider.tasks.length, 256);
      expect(provider.tasks[0].ip, '10.0.0.0');
      expect(provider.tasks[255].ip, '10.0.0.255');
    });

    test('rejects invalid prefix and keeps old tasks', () {
      final provider = PingProvider();
      provider.changeSubnet('10.0.0');
      final tasksBefore = provider.tasks.toList();

      provider.changeSubnet('invalid');
      expect(provider.subnetPrefix, '10.0.0');
      expect(provider.tasks.length, 256);
      for (int i = 0; i < 256; i++) {
        expect(provider.tasks[i].ip, tasksBefore[i].ip);
      }
    });

    test('rejects empty prefix', () {
      final provider = PingProvider();
      provider.changeSubnet('');
      expect(provider.subnetPrefix, '192.168.1');
    });

    test('resets localIp when changing subnet', () {
      final provider = PingProvider();
      provider.localIp = '192.168.1.100';
      provider.changeSubnet('172.16.0');
      expect(provider.localIp, isNull);
    });

    test('last octet values are correct', () {
      final provider = PingProvider();
      provider.changeSubnet('172.16.0');
      expect(provider.tasks[5].lastOctet, 5);
      expect(provider.tasks[255].lastOctet, 255);
    });
  });

  group('PingProvider initial state', () {
    test('has default subnet and 256 tasks on creation', () {
      final provider = PingProvider();
      expect(provider.subnetPrefix, '192.168.1');
      expect(provider.tasks.length, 256);
      expect(provider.isScanning, false);
      expect(provider.threadCount, 255);
      expect(provider.timeout, 1000);
    });

    test('all initial tasks are idle', () {
      final provider = PingProvider();
      for (var task in provider.tasks) {
        expect(task.status, IpStatus.idle);
      }
    });

    test('detailedMode defaults to false', () {
      final provider = PingProvider();
      expect(provider.detailedMode, false);
    });
  });

  group('PingProvider.toggleDetailedMode', () {
    test('toggles detailedMode on', () {
      final provider = PingProvider();
      provider.toggleDetailedMode(true);
      expect(provider.detailedMode, true);
    });

    test('toggles detailedMode off', () {
      final provider = PingProvider();
      provider.toggleDetailedMode(true);
      provider.toggleDetailedMode(false);
      expect(provider.detailedMode, false);
    });
  });

  group('PingProvider.stopScan', () {
    test('stopScan does not throw when not scanning', () {
      final provider = PingProvider();
      provider.stopScan();
      expect(provider.isScanning, false);
    });
  });
}
