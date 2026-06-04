import 'dart:typed_data';

import 'package:featgg/src/features/profile/presentation/avatar_crop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A real, decodable image so `crop_your_image`'s decode step does not fault
/// during the smoke test. We assert OUR wiring (the confirm/cancel actions and
/// the cancel→pop-null contract), not the third-party crop widget's internals.
Uint8List _validPng() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

void main() {
  testWidgets('renders the cancel and confirm actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AvatarCropScreen(sourceBytes: _validPng())),
    );
    await tester.pump();

    expect(find.byKey(const Key('avatarCropCancelButton')), findsOneWidget);
    expect(find.byKey(const Key('avatarCropConfirmButton')), findsOneWidget);
  });

  testWidgets('cancel pops the route with null', (tester) async {
    // Sentinel non-null so a missing pop is distinguishable from a null result.
    AvatarCropResult? result = const AvatarCropFailure();
    var popped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<AvatarCropResult?>(
                    MaterialPageRoute<AvatarCropResult?>(
                      builder: (_) =>
                          AvatarCropScreen(sourceBytes: _validPng()),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byKey(const Key('avatarCropCancelButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(popped, isTrue);
    expect(result, isNull);
  });
}
