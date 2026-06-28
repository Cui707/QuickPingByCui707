import 'package:flutter_test/flutter_test.dart';
import 'package:quickpingbycui707/models/ip_model.dart';
import 'package:quickpingbycui707/services/ping_service.dart';
import 'package:quickpingbycui707/utils/oui_db.dart';

// OUI functions are in oui_db.dart, test them here too

void main() {
  group('PingService.parsePingOutput', () {
    test('parses success reply with latency, hostname and device type', () {
      final task = IpTask(ip: '192.168.1.1', lastOctet: 1);
      const output = 'Pinging router.asus.com [192.168.1.1] with 32 bytes of data:\n'
          'Reply from 192.168.1.1: bytes=32 time=1ms TTL=64\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.status, IpStatus.success);
      expect(task.latency, 1);
      expect(task.hostname, 'router.asus.com');
      expect(task.deviceType, 'Linux/Android');
      expect(task.message, '回复成功');
    });

    test('parses success without hostname (no brackets)', () {
      final task = IpTask(ip: '192.168.1.100', lastOctet: 100);
      const output = 'Pinging 192.168.1.100 with 32 bytes of data:\n'
          'Reply from 192.168.1.100: bytes=32 time=3ms TTL=128\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.status, IpStatus.success);
      expect(task.latency, 3);
      expect(task.hostname, isNull);
      expect(task.deviceType, 'Windows');
    });

    test('classifies TTL 255 as Router/Gateway', () {
      final task = IpTask(ip: '192.168.1.254', lastOctet: 254);
      const output = 'Pinging 192.168.1.254 with 32 bytes of data:\n'
          'Reply from 192.168.1.254: bytes=32 time=2ms TTL=255\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.status, IpStatus.success);
      expect(task.deviceType, 'Router/Gateway');
    });

    test('classifies TTL 128 as Windows', () {
      final task = IpTask(ip: '192.168.1.50', lastOctet: 50);
      const output = 'Pinging 192.168.1.50 with 32 bytes of data:\n'
          'Reply from 192.168.1.50: bytes=32 time=5ms TTL=128\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.deviceType, 'Windows');
    });

    test('classifies TTL 64 as Linux/Android', () {
      final task = IpTask(ip: '192.168.1.30', lastOctet: 30);
      const output = 'Pinging 192.168.1.30 with 32 bytes of data:\n'
          'Reply from 192.168.1.30: bytes=32 time=10ms TTL=64\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.deviceType, 'Linux/Android');
    });

    test('classifies unknown TTL as Other', () {
      final task = IpTask(ip: '192.168.1.77', lastOctet: 77);
      const output = 'Pinging 192.168.1.77 with 32 bytes of data:\n'
          'Reply from 192.168.1.77: bytes=32 time=8ms TTL=100\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.deviceType, 'Other');
    });

    test('handles failed ping (no TTL)', () {
      final task = IpTask(ip: '192.168.1.200', lastOctet: 200);
      const output = 'Pinging 192.168.1.200 with 32 bytes of data:\n'
          'Request timed out.\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.status, IpStatus.failed);
      expect(task.message, '请求超时');
      expect(task.latency, isNull);
    });

    test('handles non-zero exit code', () {
      final task = IpTask(ip: '192.168.1.99', lastOctet: 99);
      const output = 'Ping request could not find host 192.168.1.99.\n';

      PingService.parsePingOutput(task, output, 1);

      expect(task.status, IpStatus.failed);
      expect(task.message, '请求超时');
    });

    test('Chinese locale ping output with hostname', () {
      final task = IpTask(ip: '192.168.1.10', lastOctet: 10);
      const output = '\u6b63\u5728 Ping my-nas.local [192.168.1.10] \u5177\u6709 32 \u5b57\u8282\u7684\u6570\u636e:\n'
          '\u6765\u81ea 192.168.1.10 \u7684\u56de\u590d: \u5b57\u8282=32 \u65f6\u95f4=2ms TTL=64\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.status, IpStatus.success);
      expect(task.hostname, 'my-nas.local');
      expect(task.deviceType, 'Linux/Android');
    });

    test('parses latency <1ms', () {
      final task = IpTask(ip: '192.168.1.5', lastOctet: 5);
      const output = 'Pinging 192.168.1.5 with 32 bytes of data:\n'
          'Reply from 192.168.1.5: bytes=32 time<1ms TTL=128\n';

      PingService.parsePingOutput(task, output, 0);

      expect(task.status, IpStatus.success);
      expect(task.latency, 1);
    });
  });

  group('PingService.classifyDeviceType', () {
    test('TTL 255-250', () {
      expect(PingService.classifyDeviceType(255), 'Router/Gateway');
      expect(PingService.classifyDeviceType(254), 'Router/Gateway');
      expect(PingService.classifyDeviceType(250), 'Router/Gateway');
    });

    test('TTL 128-120', () {
      expect(PingService.classifyDeviceType(128), 'Windows');
      expect(PingService.classifyDeviceType(127), 'Windows');
      expect(PingService.classifyDeviceType(120), 'Windows');
    });

    test('TTL 64-50', () {
      expect(PingService.classifyDeviceType(64), 'Linux/Android');
      expect(PingService.classifyDeviceType(60), 'Linux/Android');
      expect(PingService.classifyDeviceType(50), 'Linux/Android');
    });

    test('TTL other values', () {
      expect(PingService.classifyDeviceType(100), 'Other');
      expect(PingService.classifyDeviceType(80), 'Other');
      expect(PingService.classifyDeviceType(30), 'Other');
    });
  });

  group('PingService.classifyDeviceTypeWithVendor', () {
    test('TTL 64 + phone vendor -> Android', () {
      expect(PingService.classifyDeviceTypeWithVendor(64, vendor: 'Samsung'), 'Android');
      expect(PingService.classifyDeviceTypeWithVendor(64, vendor: 'Xiaomi'), 'Android');
      expect(PingService.classifyDeviceTypeWithVendor(64, vendor: 'Huawei'), 'Android');
    });

    test('TTL 64 + PC vendor -> Linux', () {
      expect(PingService.classifyDeviceTypeWithVendor(64, vendor: 'Intel'), 'Linux');
      expect(PingService.classifyDeviceTypeWithVendor(64, vendor: 'Realtek'), 'Linux');
    });

    test('Apple vendor -> Apple regardless of TTL', () {
      expect(PingService.classifyDeviceTypeWithVendor(64, vendor: 'Apple'), 'Apple');
      expect(PingService.classifyDeviceTypeWithVendor(128, vendor: 'Apple'), 'Apple');
    });

    test('Router vendor -> Router/Gateway', () {
      expect(PingService.classifyDeviceTypeWithVendor(255, vendor: 'TP-Link'), 'Router/Gateway');
      expect(PingService.classifyDeviceTypeWithVendor(64, vendor: 'TP-Link'), 'Router/Gateway');
    });
  });

  group('oui_db', () {
    test('lookupOui returns vendor for known MAC', () {
      expect(lookupOui('F4:31:C3:AA:BB:CC'), 'Samsung');
      expect(lookupOui('64:09:80:11:22:33'), 'Xiaomi');
      expect(lookupOui('00:02:B3:DD:EE:FF'), 'Intel');
      expect(lookupOui('00:1D:0F:00:00:01'), 'TP-Link');
      expect(lookupOui('B8:27:EB:12:34:56'), 'Raspberry Pi');
    });

    test('lookupOui handles dash format', () {
      expect(lookupOui('F4-31-C3-AA-BB-CC'), 'Samsung');
    });

    test('lookupOui returns null for unknown or null', () {
      expect(lookupOui(null), isNull);
      expect(lookupOui(''), isNull);
      expect(lookupOui('FF:FF:FF:FF:FF:FF'), isNull);
    });

    test('classifyVendor categorizes correctly', () {
      expect(classifyVendor('Samsung'), 'Android');
      expect(classifyVendor('Xiaomi'), 'Android');
      expect(classifyVendor('Huawei'), 'Android');
      expect(classifyVendor('Apple'), 'Apple');
      expect(classifyVendor('Intel'), 'PC');
      expect(classifyVendor('Realtek'), 'PC');
      expect(classifyVendor('TP-Link'), 'Router');
      expect(classifyVendor('Cisco'), 'Router');
      expect(classifyVendor('Espressif'), 'IoT');
      expect(classifyVendor('Raspberry Pi'), 'IoT');
      expect(classifyVendor(null), '');
      expect(classifyVendor('UnknownBrand'), 'PC');
    });
  });
}
