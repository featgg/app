import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'showcase_tint_provider.g.dart';

/// Derives one representative tint from a showcase card's art, used to color
/// the label and hero number so the typography reads as belonging to the
/// artwork. Extraction is the framework's own Material engine
/// (`ColorScheme.fromImageProvider`) rather than a third-party package: the
/// dark-brightness `primary` is a light, harmonized tone of the artwork's
/// scored seed color, which suits text sitting over the fade. Cached per URL
/// (keepAlive) so extraction runs once and is reused across the scrolling
/// column; the widget count per profile is bounded (≤ 50).
///
/// Any failure — a decode error or an unscorable image — yields null, so the
/// view falls back to a neutral color and never blocks on extraction.
@Riverpod(keepAlive: true)
Future<Color?> showcaseTint(Ref ref, String imageUrl) async {
  try {
    final scheme = await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(imageUrl),
      brightness: Brightness.dark,
    );
    return scheme.primary;
  } catch (_) {
    return null;
  }
}
