import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path/path.dart' as p;

/// Writes a small valid JPEG to [directory] and returns its path.
String writeTestJpeg(Directory directory, String name) {
  final image = img.Image(width: 20, height: 15);
  img.fill(image, color: img.ColorRgb8(30, 90, 150));
  final file = File(p.join(directory.path, name));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodeJpg(image));
  return file.path;
}

/// An [XFile] wrapping a freshly written valid test JPEG.
XFile writeTestXFile(Directory directory, String name) =>
    XFile(writeTestJpeg(directory, name));

/// Writes a present-but-undecodable file to [directory] and wraps it as an
/// [XFile], to exercise the corrupt-source-image failure path without
/// depending on a genuinely missing file (which involves a real
/// platform-level I/O error rather than a clean decode failure).
XFile writeCorruptXFile(Directory directory, String name) {
  final file = File(p.join(directory.path, name));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(List<int>.filled(200, 0));
  return XFile(file.path);
}
