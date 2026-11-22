import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lendy/utils/chat_image_compressor.dart';

void main() {
  test('compresses and resizes images below the Firestore-safe limit', () {
    final image = img.Image(width: 1800, height: 1200);
    img.fill(image, color: img.ColorRgb8(30, 120, 200));
    final source = Uint8List.fromList(img.encodePng(image));

    final compressed = compressChatImage(source);
    final decoded = img.decodeJpg(compressed);

    expect(compressed.length, lessThanOrEqualTo(maxChatImageBytes));
    expect(decoded?.width, 1280);
    expect(decoded?.height, 853);
  });

  test('rejects unsupported image data', () {
    expect(
      () => compressChatImage(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
