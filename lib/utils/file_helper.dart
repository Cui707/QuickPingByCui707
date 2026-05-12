import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileHelper {
  /// 获取导出目录
  static Future<String> getExportPath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      // Android 保存到外部存储的下载目录
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      // Windows 保存到桌面
      directory = await getDownloadsDirectory();
    }
    return directory?.path ?? "";
  }
}