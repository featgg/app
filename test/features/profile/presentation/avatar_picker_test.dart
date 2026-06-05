import 'dart:typed_data';

import 'package:featgg/src/features/profile/presentation/avatar_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Builds a minimal JPEG with a GPS EXIF tag via the `image` package.
/// Pure Dart — no native channels, no image_picker.
Uint8List _jpegWithGps() {
  final image = img.Image(width: 16, height: 16);
  // Paint a solid color so encodeJpg has something non-trivial to encode.
  img.fill(image, color: img.ColorRgb8(255, 0, 0));

  // Attach GPS data using the real IfdDirectory setters.
  image.exif.gpsIfd
    ..gpsLatitudeRef = 'N'
    ..gpsLatitude = 48.858
    ..gpsLongitudeRef = 'E'
    ..gpsLongitude = 2.294;

  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('transcodeToJpeg', () {
    test('strips EXIF/GPS from a tagged JPEG', () {
      final input = _jpegWithGps();

      // Confirm the input actually has GPS data before the transcode.
      final inputDecoded = img.decodeImage(input)!;
      expect(inputDecoded.exif.gpsIfd.hasGPSLatitude, isTrue);

      final output = transcodeToJpeg(input);

      // After transcode via encodeJpg the output has no GPS data.
      final outputDecoded = img.decodeImage(output)!;
      expect(outputDecoded.exif.gpsIfd.hasGPSLatitude, isFalse);
    });

    test('throws AvatarProcessingException on undecodable bytes', () {
      final garbage = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(
        () => transcodeToJpeg(garbage),
        throwsA(isA<AvatarProcessingException>()),
      );
    });

    test('output is within maxSide on a larger image', () {
      final large = img.Image(width: 1024, height: 800);
      img.fill(large, color: img.ColorRgb8(0, 255, 0));
      final input = Uint8List.fromList(img.encodeJpg(large));

      final output = transcodeToJpeg(input, maxSide: 512);

      final decoded = img.decodeImage(output)!;
      expect(decoded.width, lessThanOrEqualTo(512));
      expect(decoded.height, lessThanOrEqualTo(512));
    });
  });
}
