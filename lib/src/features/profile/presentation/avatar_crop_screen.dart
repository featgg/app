import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Result of an [AvatarCropScreen] session.
///
/// [success] carries the cropped bytes. [failure] signals that the underlying
/// cropper reported an error (distinct from a user cancel, which pops `null`).
sealed class AvatarCropResult {
  const AvatarCropResult();
}

/// The crop completed successfully; [bytes] are the cropped image bytes.
final class AvatarCropSuccess extends AvatarCropResult {
  const AvatarCropSuccess(this.bytes);

  final Uint8List bytes;
}

/// The cropper reported a failure (not a user cancel).
final class AvatarCropFailure extends AvatarCropResult {
  const AvatarCropFailure();
}

/// In-app crop screen pushed by [CropYourImageAvatarPicker].
///
/// The circular frame is fixed on screen; the user pans and pinches the image
/// beneath it to frame the desired area. Confirm triggers [CropController.crop]
/// (rectangular encode → opaque square output); [Crop.onCropped] pops the route
/// with an [AvatarCropResult]. Cancel pops with null. Not a router-declared
/// route — pushed imperatively from the picker.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.sourceBytes});

  final Uint8List sourceBytes;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _cropController = CropController();
  bool _cropping = false;

  void _confirm() {
    if (_cropping) return;
    setState(() => _cropping = true);
    _cropController.crop();
  }

  void _cancel() => Navigator.of(context).pop<AvatarCropResult?>(null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('avatarCropCancelButton'),
          icon: const Icon(Icons.close),
          onPressed: _cancel,
        ),
        actions: [
          IconButton(
            key: const Key('avatarCropConfirmButton'),
            icon: _cropping
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _cropping ? null : _confirm,
          ),
        ],
      ),
      body: Crop(
        image: widget.sourceBytes,
        controller: _cropController,
        withCircleUi: true,
        fixCropRect: true,
        interactive: true,
        aspectRatio: 1,
        onCropped: (result) {
          switch (result) {
            case CropSuccess(:final croppedImage):
              Navigator.of(
                context,
              ).pop<AvatarCropResult?>(AvatarCropSuccess(croppedImage));
            case CropFailure():
              Navigator.of(
                context,
              ).pop<AvatarCropResult?>(const AvatarCropFailure());
          }
        },
      ),
    );
  }
}
