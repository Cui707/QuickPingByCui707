import 'package:flutter/material.dart';
import '../models/ip_model.dart';
import '../services/ping_service.dart';
import '../utils/network_util.dart';
import '../utils/oui_db.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import '../utils/file_helper.dart';
import 'package:path/path.dart' as p;

class PingProvider with ChangeNotifier {
  List<IpTask> tasks = [];
  bool isScanning = false;
  bool _cancelRequested = false;
  int threadCount = 255;
  int timeout = 1000;
  bool detailedMode = false;
  String subnetPrefix = "192.168.1";
  String? localIp;

  PingProvider() {
    _generateTasks();
  }

  static bool isValidSubnetPrefix(String prefix) {
    final parts = prefix.split('.');
    if (parts.length != 3) return false;
    for (var part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// 初始化并自动探测网段
  Future<void> autoDiscover() async {
    try {
      String? prefix = await NetworkUtil.getLocalSubnetPrefix();
      localIp = await NetworkUtil.getLocalIP();

      if (prefix != null && prefix.isNotEmpty) {
        subnetPrefix = prefix;
      }
    } catch (_) {
      // keep default subnetPrefix
    }
    _generateTasks();
    notifyListeners();
  }

  /// 手动修改网段
  void changeSubnet(String newPrefix) {
    if (!isValidSubnetPrefix(newPrefix)) return;
    subnetPrefix = newPrefix;
    localIp = null;
    _generateTasks();
    notifyListeners();
  }

  /// 切换详细信息模式
  void toggleDetailedMode(bool value) {
    detailedMode = value;
    notifyListeners();
  }

  void _generateTasks() {
    tasks = List.generate(256, (i) {
      String currentIp = "$subnetPrefix.$i";
      return IpTask(
        ip: currentIp,
        lastOctet: i,
        status: (currentIp == localIp) ? IpStatus.local : IpStatus.idle,
      );
    });
  }

  /// 并发扫描（任务池模式）
  Future<void> startScan() async {
    if (isScanning) return;
    isScanning = true;
    _cancelRequested = false;
    notifyListeners();

    // 重置非本机状态
    for (var t in tasks) {
      if (t.status != IpStatus.local) t.status = IpStatus.idle;
    }

    final List<IpTask> queue = List.from(tasks.where((t) => t.status != IpStatus.local));
    int index = 0;

    Future<void> runNext() async {
      if (_cancelRequested || index >= queue.length) return;
      
      IpTask task = queue[index++];
      task.status = IpStatus.scanning;
      notifyListeners();

      await PingService.quickPing(task, timeout, resolveDetails: detailedMode);

      notifyListeners(); 
      
      await runNext();
    }

    // 启动初始线程池
    List<Future> threads = [];
    for (int i = 0; i < threadCount && i < queue.length; i++) {
      threads.add(runNext());
    }

    await Future.wait(threads);

    if (detailedMode && !_cancelRequested) {
      await _enrichTasks();
    }

    isScanning = false;
    notifyListeners();
  }

  /// 停止扫描
  void stopScan() {
    _cancelRequested = true;
    notifyListeners();
  }

  /// 扫描后通过 ARP / NetBIOS 丰富设备信息
  Future<void> _enrichTasks() async {
    final arpTable = await PingService.resolveArpTable();

    // 并行执行的 NetBIOS 查询
    final List<Future> nbtFutures = [];

    for (var task in tasks) {
      if (task.status != IpStatus.success && task.status != IpStatus.local) {
        continue;
      }

      // 从 ARP 表中获取 MAC 地址
      final mac = arpTable[task.ip];
      if (mac != null) {
        task.macAddress = mac;
        final vendor = lookupOui(mac);
        if (vendor != null) {
          task.deviceType = _refineDeviceType(task, vendor);
        }
      }

      // 没有主机名的 Windows 类设备，尝试 NetBIOS
      if (task.hostname == null && task.deviceType == 'Windows') {
        nbtFutures.add(_resolveAndSetNetBios(task));
      }
    }

    if (nbtFutures.isNotEmpty) {
      await Future.wait(nbtFutures);
    }

    notifyListeners();
  }

  Future<void> _resolveAndSetNetBios(IpTask task) async {
    final name = await PingService.resolveNetBiosName(task.ip);
    if (name != null && name.isNotEmpty) {
      task.hostname = name;
    }
  }

  String _refineDeviceType(IpTask task, String vendor) {
    final ttlHint = task.deviceType ?? '';
    if (vendor == 'Apple') return 'Apple';
    final cat = classifyVendor(vendor);
    if (cat == 'Android' && ttlHint.contains('Linux')) return 'Android ($vendor)';
    if (cat == 'Router') return 'Router ($vendor)';
    if (cat == 'IoT') return 'IoT ($vendor)';
    if (cat == 'PC' && ttlHint.contains('Linux')) return 'Linux ($vendor)';
    if (cat == 'PC' && ttlHint.contains('Windows')) return 'Windows ($vendor)';
    return ttlHint;
  }
    Future<String?> exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Ping结果'];
    
    // 1. 添加表头
    sheetObject.appendRow([
      TextCellValue('IP地址'),
      TextCellValue('状态'),
      TextCellValue('响应时间(ms)'),
      TextCellValue('MAC地址'),
      TextCellValue('设备信息'),
      TextCellValue('主机名'),
      TextCellValue('返回信息')
    ]);

    // 2. 填充数据
    for (var task in tasks) {
      sheetObject.appendRow([
        TextCellValue(task.ip),
        TextCellValue(task.status.name),
        IntCellValue(task.latency ?? 0),
        TextCellValue(task.macAddress ?? ""),
        TextCellValue(task.deviceType ?? ""),
        TextCellValue(task.hostname ?? ""),
        TextCellValue(task.message ?? ""),
      ]);
    }

    // 3. 保存文件
    try {
      String basePath = await FileHelper.getExportPath();
      String fileName = "Ping_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      String fullPath = p.join(basePath, fileName);
      
      var fileBytes = excel.save();
      if (fileBytes != null) {
        File(fullPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return fullPath; // 返回保存路径以提示用户
      }
    } catch (e) {
      debugPrint("导出失败: $e");
    }
    return null;
  }
}