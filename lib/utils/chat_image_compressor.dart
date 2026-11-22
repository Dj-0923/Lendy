import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const maxChatImageBytes = 400 * 1024;
const maxChatImageDataLength = 600000;

Uint8List compressChatImage(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('Choose a supported image file.');
  }

  final longestSide = math.max(decoded.width, decoded.height);
  for (
    var maxDimension = 1280;
    maxDimension >= 320;
    maxDimension = (maxDimension * 0.8).round()
  ) {
    final scale = math.min(1.0, maxDimension / longestSide);
    final width = math.max(1, (decoded.width * scale).round()).toInt();
    final height = math.max(1, (decoded.height * scale).round()).toInt();
    final resized = width == decoded.width && height == decoded.height
        ? decoded
        : img.copyResize(decoded, width: width, height: height);

    for (final quality in [85, 75, 65, 55, 45]) {
      final compressed = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
      if (compressed.length <= maxChatImageBytes) return compressed;
    }
  }

  throw const FormatException(
    'This image is too large to compress. Choose a smaller image.',
  );
}
