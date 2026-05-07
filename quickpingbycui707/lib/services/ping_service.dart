import 'package:dart_ping/dart_ping.dart';
import '../models/ip_model.dart';

class PingService {
  /// 执行单次 Ping 操作
  static Future<void> quickPing(IpTask task, int timeoutMs) async {
    // 创建 Ping 对象，只发 1 个包
    final ping = Ping(task.ip, count: 1, timeout: timeoutMs);

    try {
      // 监听流结果
      await for (final response in ping.stream) {
        if (response.response != null && response.error == null) {
          task.status = IpStatus.success;
          task.latency = response.response!.time?.inMilliseconds;
          task.message = "来自 ${task.ip} 的回复";
        } else {
          task.status = IpStatus.failed;
          task.message = "超时";
        }
      }
    } catch (e) {
      task.status = IpStatus.failed;
      task.message = "错误: $e";
    }
  }
}