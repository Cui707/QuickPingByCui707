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
    final info = NetworkInfo();
    String? ip = await info.getWifiIP();
    if (ip != null) {
      return extractSubnetPrefix(ip);
    }
    return null;
  }

  /// 获取本机完整 IP
  static Future<String?> getLocalIP() async {
    return await NetworkInfo().getWifiIP();
  }
}