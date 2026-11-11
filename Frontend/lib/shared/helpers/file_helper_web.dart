import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

Future<void> exportBackupFile(String fileName, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<String?> readPickedFileString(PlatformFile file) async {
  if (file.bytes != null) {
    return utf8.decode(file.bytes!);
  }
  return null;
}

