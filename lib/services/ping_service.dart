import 'dart:io';
import '../models/ip_model.dart';

class PingService {
  /// 使用系统原生进程执行 Ping，最稳健的方式
  static Future<void> quickPing(IpTask task, int timeoutMs) async {
    try {
      // Windows 下的具体命令：-n 1 (发1个包), -w (超时ms)
      // 使用 Process.run 直接获取结果，不处理复杂的流
      final result = await Process.run(
        'ping',
        ['-n', '1', '-w', timeoutMs.toString(), task.ip],
        runInShell: true,
      );

      // Windows ping 成功时，退出码为 0
      // 并且返回内容中包含 "TTL" (代表收到了回包)
      if (result.exitCode == 0 && result.stdout.toString().contains('TTL=')) {
        task.status = IpStatus.success;
        
        // 简单解析延迟（正则匹配 "时间=Xms" 或 "time=Xms"）
        final match = RegExp(r"(\d+)ms").firstMatch(result.stdout.toString());
        if (match != null) {
          task.latency = int.tryParse(match.group(1) ?? "0");
        } else {
          task.latency = 1; // 局域网可能小于 1ms，给个保底值
        }
        task.message = "回复成功";
      } else {
        task.status = IpStatus.failed;
        task.message = "请求超时";
      }
    } catch (e) {
      task.status = IpStatus.failed;
      task.message = "进程错误: $e";
    }
  }
}