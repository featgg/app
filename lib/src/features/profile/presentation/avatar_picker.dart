import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'avatar_crop_screen.dart';

part 'avatar_picker.g.dart';

/// Thrown by [CropYourImageAvatarPicker.pickAndCrop] when a picked or cropped
/// image cannot be decoded or the in-app cropper reports a failure. Distinct
/// from a user cancel, which returns null. The controller maps it to
/// [MediaProcessingFailure].
final class AvatarProcessingException implements Exception {
  const AvatarProcessingException([this.message]);

  final String? message;

  @override
  String toString() =>
      'AvatarProcessingException${message != null ? ': $message' : ''}';
}

/// Pure-Dart: decode → square-fit resize (max [maxSide] px) → JPEG re-encode.
///
/// Throws [AvatarProcessingException] if [bytes] cannot be decoded.
/// Re-encoding via `encodeJpg` strips EXIF/GPS — this is where the app owns
/// the EXIF privacy mitigation. No Flutter, no image_picker — directly testable.
Uint8List transcodeToJpeg(
  Uint8List bytes, {
  int maxSide = 512,
  int quality = 80,
}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Malformed input can make the decoder throw (e.g. a RangeError) instead
    // of returning null; treat any decode fault as a processing failure.
    throw const AvatarProcessingException('image could not be decoded');
  }
  if (decoded == null) {
    throw const AvatarProcessingException('image could not be decoded');
  }

  final img.Image resized;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(decoded, width: maxSide);
    } else {
      resized = img.copyResize(decoded, height: maxSide);
    }
  } else {
    resized = decoded;
  }

  // Strip EXIF/GPS: encodeJpg re-writes image.exif, so clearing it first is
  // what actually removes location/metadata. This is the app's EXIF privacy
  // mitigation — the backend does not strip metadata server-side.
  resized.exif = img.ExifData();

  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}

/// Result of a successful pick-and-crop operation.
final class AvatarPick {
  const AvatarPick({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Seam for the pick → crop → compress pipeline.
///
/// Abstracted so the controller and edit-screen tests can inject a fake
/// without touching native channels or navigation.
abstract interface class AvatarPicker {
  /// Pick from gallery → interactive square-locked in-app crop →
  /// resize+compress (max 512 px, jpeg quality ~80, target ≤~200 KB).
  /// Returns null if the user cancels at either the pick or the crop step.
  /// Throws [AvatarProcessingException] on a decode or crop failure.
  /// Takes a [BuildContext] because the crop step pushes an in-app screen.
  Future<AvatarPick?> pickAndCrop(BuildContext context);
}

/// Concrete implementation using `image_picker`, `AvatarCropScreen`, and
/// the pure-Dart `image` package. Gallery-only (no camera) per operator decision.
final class CropYourImageAvatarPicker implements AvatarPicker {
  const CropYourImageAvatarPicker();

  @override
  Future<AvatarPick?> pickAndCrop(BuildContext context) async {
    // Step 1: gallery pick via image_picker (gallery-only; desktop uses the
    // file_selector-backed impl automatically).
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null) return null;

    final sourceBytes = await xfile.readAsBytes();

    // Step 2: push the in-app square-crop screen and await the result.
    if (!context.mounted) return null;
    final cropResult = await Navigator.of(context).push<AvatarCropResult?>(
      MaterialPageRoute<AvatarCropResult?>(
        builder: (_) => AvatarCropScreen(sourceBytes: sourceBytes),
      ),
    );

    // null → user cancelled the crop screen.
    if (cropResult == null) return null;

    switch (cropResult) {
      case AvatarCropSuccess(:final bytes):
        // Step 3: resize + JPEG-compress (strips EXIF/GPS via encodeJpg).
        final jpgBytes = transcodeToJpeg(bytes);
        return AvatarPick(bytes: jpgBytes, contentType: 'image/jpeg');
      case AvatarCropFailure():
        throw const AvatarProcessingException('crop step reported a failure');
    }
  }
}

/// DI seam for the avatar picker. Overridden at the composition root with
/// [CropYourImageAvatarPicker]; tests inject a fake.
@riverpod
AvatarPicker avatarPicker(Ref ref) =>
    throw UnimplementedError('avatarPickerProvider must be overridden');
