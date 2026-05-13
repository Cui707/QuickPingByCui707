import 'package:flutter/material.dart';
import '../models/ip_model.dart';
import '../services/ping_service.dart';
import '../utils/network_util.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import '../utils/file_helper.dart';
import 'package:path/path.dart' as p;

class PingProvider with ChangeNotifier {
  List<IpTask> tasks = [];
  bool isScanning = false;
  int threadCount = 20;
  int timeout = 200;

  /// 初始化并自动探测网段
  Future<void> autoDiscover() async {
    String? prefix = await NetworkUtil.getLocalSubnetPrefix();
    String? localIp = await NetworkUtil.getLocalIP();
    
    prefix ??= "192.168.1"; // 默认 fallback
    
    tasks = List.generate(256, (i) {
      String currentIp = "$prefix.$i";
      return IpTask(
        ip: currentIp,
        lastOctet: i,
        status: (currentIp == localIp) ? IpStatus.local : IpStatus.idle,
      );
    });
    notifyListeners();
  }

  /// 并发扫描（任务池模式）
  Future<void> startScan() async {
    if (isScanning) return;
    isScanning = true;
    notifyListeners();

    // 重置非本机状态
    for (var t in tasks) {
      if (t.status != IpStatus.local) t.status = IpStatus.idle;
    }

    final List<IpTask> queue = List.from(tasks.where((t) => t.status != IpStatus.local));
    int activeThreads = 0;
    int index = 0;

    Future<void> runNext() async {
      if (index >= queue.length) return;
      
      IpTask task = queue[index++];
      task.status = IpStatus.scanning;
      notifyListeners(); // 界面变黄

      // 执行原生 Ping
      await PingService.quickPing(task, timeout);

      // 这里不需要再写逻辑，因为上面的 quickPing 已经修改了 task.status
      // 我们只需要通知 UI：已经从 scanning 变成成功或失败了
      notifyListeners(); 
      
      await runNext();
    }

    // 启动初始线程池
    List<Future> threads = [];
    for (int i = 0; i < threadCount && i < queue.length; i++) {
      threads.add(runNext());
    }

    await Future.wait(threads);
    isScanning = false;
    notifyListeners();
  }
    Future<String?> exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Ping结果'];
    
    // 1. 添加表头
    sheetObject.appendRow([
      TextCellValue('IP地址'),
      TextCellValue('状态'),
      TextCellValue('响应时间(ms)'),
      TextCellValue('主机名'),
      TextCellValue('返回信息')
    ]);

    // 2. 填充数据
    for (var task in tasks) {
      sheetObject.appendRow([
        TextCellValue(task.ip),
        TextCellValue(task.status.name),
        IntCellValue(task.latency ?? 0),
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