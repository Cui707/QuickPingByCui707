import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'models/ip_model.dart';
import 'providers/ping_provider.dart';

void main() async {

// 1. 确保插件初始化
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // 2. 配置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 800),          // 设置启动时的默认大小
    minimumSize: Size(800, 600),   // 设置窗口缩小的下限，防止底部被遮挡
    center: true,                  // 居中显示
    title: "QuickPing - By Cui707",
  );

  // 3. 应用并显示窗口
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

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
   
  late TextEditingController _timeoutController;
  late TextEditingController _threadsController;
  late TextEditingController _subnetController;
  late PingProvider _provider;

  @override
  void initState() {
    super.initState();
    
    // 1. 获取 Provider 实例（不监听，仅读取）
    _provider = context.read<PingProvider>();

    // 2. 初始化控制器，设置你想看到的默认值
    _timeoutController = TextEditingController(text: "1000");
    _threadsController = TextEditingController(text: "255");
    _subnetController = TextEditingController(text: _provider.subnetPrefix);

    // 3. 关键：同步给 Provider，这样不用输入也能直接点扫描
    _provider.timeout = 1000;
    _provider.threadCount = 255;
    _provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (_subnetController.text != _provider.subnetPrefix) {
      _subnetController.text = _provider.subnetPrefix;
    }
  }

  @override
  void dispose() {
    // 记得销毁控制器释放内存
    _provider.removeListener(_onProviderChanged);
    _timeoutController.dispose();
    _threadsController.dispose();
    _subnetController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickPing - By Cui707'),

        actions: [
          IconButton(
            icon: Icon(isGridMode ? Icons.list : Icons.grid_view),

            onPressed: () => setState(() => isGridMode = !isGridMode),

            tooltip: isGridMode ? "切换到列表模式" : "切换到图形模式",
          ),
        ],
      ),

      body: Column(
        children: [
          // 1. 参数设置区
          _buildHeader(provider),

          // 2. 核心展示区 (根据模式切换)
          Expanded(
            child: isGridMode
                ? _buildGridView(provider)
                : _buildListView(provider),
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
          const Text("网段:"),

          SizedBox(
            width: 130,
            child: TextField(
              controller: _subnetController,
              decoration: InputDecoration(
                isDense: true,
                errorText: PingProvider.isValidSubnetPrefix(_subnetController.text)
                    ? null
                    : "格式: xxx.xxx.xxx",
              ),
              keyboardType: TextInputType.text,
              onChanged: (v) => p.changeSubnet(v),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => p.autoDiscover(),
            tooltip: "重新探测网段",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          const Text("超时(ms):"),

          SizedBox(width: 60, child: TextField(
            controller: _timeoutController, // 绑定控制器
            decoration: const InputDecoration(isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (v) => p.timeout = int.tryParse(v) ?? 500,
          )),

          const Text("线程:"),

          SizedBox(width: 60, child: TextField(
            controller: _threadsController, // 绑定控制器
            decoration: const InputDecoration(isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (v) => p.threadCount = int.tryParse(v) ?? 50,
          )),

          const Text("详细信息:"),

          SizedBox(
            height: 28,
            child: Switch(
              value: p.detailedMode,
              onChanged: (v) => p.toggleDetailedMode(v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(PingProvider p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 1. 定义行列数
        const int crossAxisCount = 16;
        const int rowCount = 16;

        // 2. 定义间距（需与下方 Delegate 中的 spacing 一致）
        const double spacing = 2.0;
        const double totalPadding = 10.0; // 左右总边距 (5+5)

        // 3. 计算可用宽高
        // 减去总边距和所有格子之间的间距
        double availableWidth = constraints.maxWidth - totalPadding - (spacing * (crossAxisCount - 1));
        double availableHeight = constraints.maxHeight - totalPadding - (spacing * (rowCount - 1));

        // 确保高度不为负数（防御性编程）
        if (availableHeight <= 0) availableHeight = 10;

        // 4. 计算单个格子的宽高，并求出比例
        double cellWidth = availableWidth / crossAxisCount;
        double cellHeight = availableHeight / rowCount;
        double dynamicAspectRatio = cellWidth / cellHeight;

        // 5. 根据单元格大小动态计算字号（取宽高中较小者的 22%，限制在 7~18 之间）
        double dynamicFontSize = (cellWidth < cellHeight ? cellWidth : cellHeight) * 0.22;
        if (dynamicFontSize < 7) dynamicFontSize = 7;
        if (dynamicFontSize > 18) dynamicFontSize = 18;

        return Container(
          padding: const EdgeInsets.all(5), // 这里的 5 对应上面的 totalPadding/2
          color: Colors.white, // 设置背景色方便观察边界
          child: GridView.builder(
            // 强制禁用滚动，确保格子在当前 Expanded 区域内缩放
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: dynamicAspectRatio, // 关键：应用精确比例
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
                      style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.bold),
                    ),
                ),
              );
            },
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

            DataColumn(label: Text('MAC地址')),

            DataColumn(label: Text('设备信息')),

            DataColumn(label: Text('返回信息')),
          ],

          rows: p.tasks
              .map(
                (task) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        task.ip,
                        style: TextStyle(
                          color: task.status == IpStatus.failed
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(task.latency != null ? "${task.latency}ms" : "-"),
                    ),

                    DataCell(Text(task.macAddress ?? "-")),

                    DataCell(Text(task.deviceType ?? "")),

                    DataCell(
                      Text(
                        task.message ?? "",
                        style: TextStyle(
                          fontSize: 12,
                          color: task.statusColor == Colors.red
                              ? Colors.red
                              : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFooter(PingProvider p) {
    return Container(
      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [
          ElevatedButton(
            onPressed: p.isScanning ? null : () => p.startScan(),

            child: const Text("开始扫描"),
          ),

          ElevatedButton(
            onPressed: !p.isScanning
                ? null
                : () => p.stopScan(),
            child: const Text("停止"),
          ),

          ElevatedButton(
            onPressed: p.isScanning
                ? null
                : () async {
                    String? path = await p.exportToExcel();

                    if (path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("导出成功！保存在: $path"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("导出失败"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },

            child: const Text("保存 Excel"),
          ),

          // 在 _buildFooter 的 Text 中
          Text(
            "响应数: ${p.tasks.where((t) => t.status == IpStatus.success || t.status == IpStatus.local).length}",
              style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}