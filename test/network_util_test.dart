import 'package:flutter_test/flutter_test.dart';
import 'package:quickpingbycui707/utils/network_util.dart';

void main() {
  group('NetworkUtil.extractSubnetPrefix', () {
    test('extracts prefix from standard IPv4', () {
      expect(NetworkUtil.extractSubnetPrefix('192.168.1.100'), '192.168.1');
      expect(NetworkUtil.extractSubnetPrefix('10.0.0.1'), '10.0.0');
      expect(NetworkUtil.extractSubnetPrefix('172.16.0.255'), '172.16.0');
      expect(NetworkUtil.extractSubnetPrefix('0.0.0.0'), '0.0.0');
      expect(NetworkUtil.extractSubnetPrefix('255.255.255.255'), '255.255.255');
    });

    test('returns null for invalid input', () {
      expect(NetworkUtil.extractSubnetPrefix(''), isNull);
      expect(NetworkUtil.extractSubnetPrefix('not an ip'), isNull);
      expect(NetworkUtil.extractSubnetPrefix('192.168'), isNull);
      expect(NetworkUtil.extractSubnetPrefix('nodots'), isNull);
    });

    test('handles edge cases', () {
      expect(NetworkUtil.extractSubnetPrefix('192.168.1.100.extra'), '192.168.1');
      expect(NetworkUtil.extractSubnetPrefix('1.2.3'), '1.2.3');
    });
  });
}
