import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtil {
  /// 从完整 IP 地址提取网段前缀，例如 "192.168.1.100" => "192.168.1"
  static String? extractSubnetPrefix(String ip) {
    if (ip.contains('.')) {
      final parts = ip.split('.');
      if (parts.length >= 3) {
        return "${parts[0]}.${parts[1]}.${parts[2]}";
      }
    }
    return null;
  }

  /// 获取当前网段前缀，例如 "192.168.1"
  static Future<String?> getLocalSubnetPrefix() async {
    final ip = await getLocalIP();
    if (ip != null) {
      return extractSubnetPrefix(ip);
    }
    return null;
  }

  /// 获取本机完整 IP（WiFi优先，回退到 NetworkInterface）
  static Future<String?> getLocalIP() async {
    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}

    return null;
  }
}