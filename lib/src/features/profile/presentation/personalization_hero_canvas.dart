import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import 'personalization_card_shell.dart';

/// Stable key for the contained 4:5 art box, so the conditional-fit behaviour is
/// assertable: on a tall viewport its width equals the column width (art fills,
/// blur hidden); on a short viewport it is narrower (art contained, blur sides
/// visible).
const Key kHeroArtKey = Key('personalizationHeroArt');

/// The header's art surface: a frame of [heroFrameHeight]; a 4:5 art box shown
/// fully contained and centered; and, filling the frame behind it, a blurred +
/// darkened copy of the same art so a short viewport never shows empty side
/// bars. [child] is drawn over a bottom-anchored scrim, which is what keeps it
/// legible over art of any brightness.
///
/// [imageUrl] is real art the profile resolved; a null url — or one that fails
/// to load — falls back to the theme's own gradient, the honest render for a
/// profile with nothing linked yet.
class PersonalizationHeroCanvas extends StatelessWidget {
  const PersonalizationHeroCanvas({
    super.key,
    required this.columnWidth,
    this.imageUrl,
    this.child,
  });

  /// The fixed column width the canvas sits in; the frame budget derives from it.
  final double columnWidth;

  /// The art to show, or null for the theme gradient.
  final String? imageUrl;

  /// Drawn over the art, bottom-anchored.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final frameHeight = heroFrameHeight(screenHeight, columnWidth);
    final overlay = child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(palette.radius),
      child: SizedBox(
        height: frameHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blur-extend fill: the same art, blurred + darkened, over-scanned so
            // its blurred edges never show a seam.
            Positioned(
              left: -PersonalizationLayout.heroBlurInset,
              right: -PersonalizationLayout.heroBlurInset,
              top: -PersonalizationLayout.heroBlurInset,
              bottom: -PersonalizationLayout.heroBlurInset,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: PersonalizationLayout.heroBlurSigma,
                  sigmaY: PersonalizationLayout.heroBlurSigma,
                ),
                child: _HeroArt(imageUrl: imageUrl, palette: palette),
              ),
            ),
            const ColoredBox(color: PersonalizationArtColors.heroBlurVeil),
            // Contained 4:5 art: on a tall frame it fills the column width; on a
            // short frame it is bounded by height and narrower than the frame.
            Center(
              child: AspectRatio(
                key: kHeroArtKey,
                aspectRatio: PersonalizationLayout.heroArtAspect,
                child: _HeroArt(imageUrl: imageUrl, palette: palette),
              ),
            ),
            if (overlay != null) _HeroOverlay(child: overlay),
          ],
        ),
      ),
    );
  }
}

/// The art itself: the resolved image, or the theme's own vertical gradient
/// while it loads, when it fails, and when there is none. The bottom paint is
/// the solid mid-tone, never a gradient that can fall to black.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.imageUrl, required this.palette});

  final String? imageUrl;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    return personalizationArtOrPlaceholder(
      imageUrl: imageUrl,
      placeholder: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.artC, palette.artA, palette.artB],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Bottom-anchored overlay: a scrim for legibility and the content over it.
class _HeroOverlay extends StatelessWidget {
  const _HeroOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            PersonalizationArtColors.heroScrim,
            PersonalizationArtColors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Align(alignment: Alignment.bottomLeft, child: child),
      ),
    );
  }
}
