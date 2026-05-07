import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/ip_model.dart';
import 'providers/ping_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PingProvider()..autoDiscover(),
      child: const QuickPingApp(),
    ),
  );
}

class QuickPingApp extends StatelessWidget {
  const QuickPingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'quickpingbycui707',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isGridMode = true; // 切换图形/列表模式

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickPing (Flutter) - By Cui707'),
        actions: [
          IconButton(
            icon: Icon(isGridMode ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => isGridMode = !isGridMode),
            tooltip: isGridMode ? "切换到列表模式" : "切换到图形模式",
          )
        ],
      ),
      body: Column(
        children: [
          // 1. 参数设置区
          _buildHeader(provider),
          
          // 2. 核心展示区 (根据模式切换)
          Expanded(
            child: isGridMode ? _buildGridView(provider) : _buildListView(provider),
          ),
          
          // 3. 底部状态栏与按钮
          _buildFooter(provider),
        ],
      ),
    );
  }

  // --- UI 组件拆解 ---

  Widget _buildHeader(PingProvider p) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.grey[100],
      child: Wrap(
        spacing: 15,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text("超时(ms):"),
          SizedBox(width: 60, child: TextField(
            decoration: const InputDecoration(isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (v) => p.timeout = int.tryParse(v) ?? 200,
          )),
          const Text("线程:"),
          SizedBox(width: 60, child: TextField(
            decoration: const InputDecoration(isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (v) => p.threadCount = int.tryParse(v) ?? 20,
          )),
        ],
      ),
    );
  }

  Widget _buildGridView(PingProvider p) {
    return GridView.builder(
      padding: const EdgeInsets.all(5),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 16, // 复刻截图的 16x16
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: p.tasks.length,
      itemBuilder: (context, index) {
        final task = p.tasks[index];
        return Container(
          decoration: BoxDecoration(
            color: task.statusColor,
            border: Border.all(color: Colors.black12, width: 0.5),
          ),
          child: Center(
            child: Text(
              '${task.lastOctet}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(PingProvider p) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 35,
          dataRowMinHeight: 25,
          dataRowMaxHeight: 30,
          columns: const [
            DataColumn(label: Text('IP地址')),
            DataColumn(label: Text('响应时间')),
            DataColumn(label: Text('主机名')),
            DataColumn(label: Text('返回信息')),
          ],
          rows: p.tasks.map((task) => DataRow(
            cells: [
              DataCell(Text(task.ip, style: TextStyle(color: task.status == IpStatus.failed ? Colors.red : Colors.blue))),
              DataCell(Text(task.latency != null ? "${task.latency}ms" : "-")),
              DataCell(Text(task.hostname ?? "")),
              DataCell(Text(task.message ?? "", style: TextStyle(fontSize: 12, color: task.statusColor == Colors.red ? Colors.red : Colors.black))),
            ],
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildFooter(PingProvider p) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[300]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: p.isScanning ? null : () => p.startScan(),
            child: const Text("开始扫描"),
          ),
          ElevatedButton(
            onPressed: !p.isScanning ? null : () { /* 停止逻辑 */ },
            child: const Text("停止"),
          ),
          ElevatedButton(
            onPressed: p.isScanning ? null : () async {
              String? path = await p.exportToExcel();
              if (path != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("导出成功！保存在: $path"), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("导出失败"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("保存 Excel"),
          ),
          Text("响应数: ${p.tasks.where((t) => t.status == IpStatus.success).length}"),
        ],
      ),
    );
  }
}