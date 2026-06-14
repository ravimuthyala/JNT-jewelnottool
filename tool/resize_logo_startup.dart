import 'dart:io';
import 'package:image/image.dart' as img;

Future<void> main() async {
  const path = 'assets/images/JNTWhitelogo.png';
  final file = File(path);
  final before = await file.length();
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Decode failed: $path');
    exit(1);
  }

  const targetWidth = 1400;
  final resized = decoded.width <= targetWidth
      ? decoded
      : img.copyResize(decoded, width: targetWidth, interpolation: img.Interpolation.average);

  final encoded = img.encodePng(resized, level: 9, filter: img.PngFilter.paeth);
  await file.writeAsBytes(encoded, flush: true);
  final after = await file.length();
  final saved = before - after;
  final pct = before == 0 ? 0 : (saved * 100 / before);

  stdout.writeln('Logo resized: ${decoded.width}x${decoded.height} -> ${resized.width}x${resized.height}');
  stdout.writeln('Bytes: $before -> $after, saved $saved (${pct.toStringAsFixed(2)}%)');
}
