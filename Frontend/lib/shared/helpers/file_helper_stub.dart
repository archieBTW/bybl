import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportBackupFile(String fileName, String content) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json', name: fileName)],
    subject: 'Bybl Backup',
    text: 'My Bybl backup',
  );
}

Future<String?> readPickedFileString(PlatformFile file) async {
  if (file.bytes != null) {
    return utf8.decode(file.bytes!);
  }
  if (file.path != null) {
    final ioFile = File(file.path!);
    return await ioFile.readAsString();
  }
  return null;
}

