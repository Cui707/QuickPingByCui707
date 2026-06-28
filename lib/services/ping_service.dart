import 'dart:io';
import '../models/ip_model.dart';
import '../utils/oui_db.dart';

class PingService {
  /// 使用系统原生进程执行 Ping，最稳健的方式
  /// [resolveDetails] 为 true 时启用 -a 反向 DNS 解析
  static Future<void> quickPing(IpTask task, int timeoutMs, {bool resolveDetails = false}) async {
    try {
      final args = <String>[];
      if (resolveDetails) args.add('-a');
      args.addAll(['-n', '1', '-w', timeoutMs.toString(), task.ip]);

      final result = await Process.run('ping', args, runInShell: true);

      parsePingOutput(task, result.stdout.toString(), result.exitCode, resolveDetails: resolveDetails);
    } catch (e) {
      task.status = IpStatus.failed;
      task.message = "进程错误: $e";
    }
  }

  /// 解析 ping 输出，提取延迟、主机名、设备类型等信息
  /// [resolveDetails] 为 false 时仅判断通断和延迟，不做主机名/设备类型解析
  static void parsePingOutput(IpTask task, String output, int exitCode, {bool resolveDetails = true}) {
    if (exitCode == 0 && output.contains('TTL=')) {
      task.status = IpStatus.success;

      final match = RegExp(r"(\d+)ms").firstMatch(output);
      if (match != null) {
        task.latency = int.tryParse(match.group(1) ?? "0");
      } else {
        task.latency = 1;
      }

      if (resolveDetails) {
        _parseHostname(task, output);
        _parseDeviceType(task, output);
      }

      task.message = "回复成功";
    } else {
      task.status = IpStatus.failed;
      task.message = "请求超时";
    }
  }

  /// 从 "hostname [ip]" 模式中提取主机名
  static void _parseHostname(IpTask task, String output) {
    final match =
        RegExp(r'(\S+)\s*\[' + RegExp.escape(task.ip) + r'\]').firstMatch(output);
    if (match != null) {
      final candidate = match.group(1) ?? '';
      if (candidate.isNotEmpty && candidate != task.ip) {
        task.hostname = candidate;
      }
    }
  }

  /// 从 TTL 值推断设备类型并解析
  static void _parseDeviceType(IpTask task, String output) {
    final ttlMatch = RegExp(r'TTL=(\d+)').firstMatch(output);
    if (ttlMatch != null) {
      final ttl = int.tryParse(ttlMatch.group(1) ?? '0') ?? 0;
      task.deviceType = classifyDeviceType(ttl);
    }
  }

  /// 根据 TTL 值分类设备类型（仅 TTL，不含 MAC 信息）
  static String classifyDeviceType(int ttl) {
    if (ttl >= 250) return 'Router/Gateway';
    if (ttl >= 120) return 'Windows';
    if (ttl >= 50 && ttl <= 70) return 'Linux/Android';
    return 'Other';
  }

  /// 根据 TTL + MAC Vendor 综合判断设备类型
  static String classifyDeviceTypeWithVendor(int ttl, {String? vendor}) {
    if (vendor == 'Apple') return 'Apple';
    final cat = classifyVendor(vendor);
    if (cat == 'Android' && ttl >= 50 && ttl <= 70) return 'Android';
    if (cat == 'Router') return 'Router/Gateway';
    if (cat == 'IoT') return 'IoT';
    if (cat == 'PC' && ttl >= 50 && ttl <= 70) return 'Linux';
    if (cat == 'PC' && ttl >= 120) return 'Windows';
    return classifyDeviceType(ttl);
  }

  /// 运行 arp -a 获取 IP->MAC 映射表
  static Future<Map<String, String>> resolveArpTable() async {
    final map = <String, String>{};
    try {
      final result = await Process.run('arp', ['-a'], runInShell: true);
      final output = result.stdout.toString();
      final regex = RegExp(
        r'^\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2})',
        multiLine: true,
      );
      for (final m in regex.allMatches(output)) {
        map[m.group(1)!] = m.group(2)!;
      }
    } catch (_) {
      // arp command may fail on non-Windows or without admin
    }
    return map;
  }

  /// NetBIOS 名称解析（仅 Windows 可用）
  static Future<String?> resolveNetBiosName(String ip) async {
    try {
      final result = await Process.run(
        'nbtstat',
        ['-A', ip],
        runInShell: true,
      );
      final match =
          RegExp(r'^\s*(\S+)\s+<00>\s+UNIQUE', multiLine: true)
              .firstMatch(result.stdout.toString());
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }
}