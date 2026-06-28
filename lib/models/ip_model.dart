import 'package:flutter/material.dart';

enum IpStatus { idle, scanning, success, failed, local }

class IpTask {
  final String ip;          // 完整IP地址，如 192.168.1.1
  final int lastOctet;      // IP最后一位，用于网格显示，如 1
  IpStatus status;
  int? latency;             // 响应延迟(ms)
  String? hostname;         // 主机名
  String? macAddress;       // 网卡地址
  String? message;          // 返回信息或错误提示
  String? deviceType;       // 设备类型 (Windows / Linux / Router 等)

  IpTask({
    required this.ip,
    required this.lastOctet,
    this.status = IpStatus.idle,
    this.latency,
    this.hostname,
    this.macAddress,
    this.message,
    this.deviceType,
  });

  // 获取状态对应的 UI 颜色
  Color get statusColor {
    switch (status) {
      case IpStatus.idle: return Colors.grey[300]!;
      case IpStatus.scanning: return Colors.yellow;
      case IpStatus.success: return Colors.cyanAccent;
      case IpStatus.failed: return Colors.red;
      case IpStatus.local: return Colors.greenAccent;
    }
  }
}