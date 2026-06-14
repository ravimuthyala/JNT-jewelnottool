import 'dart:io';
import 'package:image/image.dart' as img;

Future<void> optimize(String path) async {
  final file = File(path);
  final before = await file.length();
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stdout.writeln('SKIP $path (decode failed)');
    return;
  }

  final backup = File('$path.bak');
  if (!await backup.exists()) {
    await backup.writeAsBytes(bytes, flush: true);
  }

  final encoded = img.encodePng(decoded, level: 9, filter: img.PngFilter.paeth);
  await file.writeAsBytes(encoded, flush: true);
  final after = await file.length();
  final saved = before - after;
  final pct = before == 0 ? 0 : (saved * 100 / before);
  stdout.writeln('$path: ${decoded.width}x${decoded.height}, $before -> $after bytes, saved $saved (${pct.toStringAsFixed(2)}%)');
}

Future<void> main() async {
  await optimize('assets/images/jnt_nails.png');
  await optimize('assets/images/JNTWhitelogo.png');
}
