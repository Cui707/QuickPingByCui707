import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtil {
  /// 获取当前网段前缀，例如 "192.168.1"
  static Future<String?> getLocalSubnetPrefix() async {
    final info = NetworkInfo();
    String? ip = await info.getWifiIP(); // 获取本机 IP

    if (ip != null && ip.contains('.')) {
      // 截取最后一位之前的字符串
      List<String> parts = ip.split('.');
      return "${parts[0]}.${parts[1]}.${parts[2]}";
    }
    return null;
  }

  /// 获取本机完整 IP
  static Future<String?> getLocalIP() async {
    return await NetworkInfo().getWifiIP();
  }
}