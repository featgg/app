import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Stable key for the contained 4:5 art box, so the conditional-fit behaviour is
/// assertable: on a tall viewport its width equals the column width (art fills,
/// blur hidden); on a short viewport it is narrower (art contained, blur sides
/// visible).
const Key kHeroArtKey = Key('personalizationHeroArt');

/// The hero canvas (spec §4): a frame of [heroFrameHeight]; a 4:5 token-gradient
/// art box shown fully contained and centered; and, filling the frame behind it,
/// a blurred + darkened copy of the same art (blur-extend) so a short viewport
/// never shows empty side bars. The art is a theme gradient, not a bundled
/// asset — the public repo stays binary-free and the fit/blur behaviour is
/// deterministic.
class PersonalizationHeroCanvas extends StatelessWidget {
  const PersonalizationHeroCanvas({
    super.key,
    required this.word,
    required this.columnWidth,
  });

  /// The hero word overlaid on the art (the profile display name / handle).
  final String word;

  /// The fixed column width the hero sits in; the frame budget derives from it.
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final frameHeight = heroFrameHeight(screenHeight, columnWidth);

    return ClipRRect(
      borderRadius: BorderRadius.circular(palette.radius),
      child: SizedBox(
        height: frameHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blur-extend fill: the same art, blurred + darkened, over-scanned so
            // its blurred edges never show a seam (mockup inset:-30px).
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
                child: _HeroArt(palette: palette),
              ),
            ),
            const ColoredBox(color: PersonalizationArtColors.heroBlurVeil),
            // Contained 4:5 art: on a tall frame it fills the column width; on a
            // short frame it is bounded by height and narrower than the frame.
            Center(
              child: AspectRatio(
                key: kHeroArtKey,
                aspectRatio: PersonalizationLayout.heroArtAspect,
                child: _HeroArt(palette: palette),
              ),
            ),
            _HeroOverlay(
              word: word,
              columnWidth: columnWidth,
              style: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

/// The 4:5 token-gradient art. The bottom paint is the solid mid-tone
/// [PersonalizationPalette.artB] (spec §8: never a gradient that can fall to
/// black); the deep tone and accent glow sit above it.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.palette});

  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Three evenly-distributed stops: deep top, accent glow mid, solid
        // mid-tone [artB] at the bottom (spec §8: the bottom never falls to
        // black).
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.artC, palette.artA, palette.artB],
        ),
      ),
    );
  }
}

/// Bottom-anchored overlay: a scrim for legibility and the centered hero word.
class _HeroOverlay extends StatelessWidget {
  const _HeroOverlay({
    required this.word,
    required this.columnWidth,
    required this.style,
  });

  final String word;
  final double columnWidth;
  final TextTheme style;

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
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            word.toUpperCase(),
            key: const Key('personalizationHeroWord'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.headlineMedium?.copyWith(
              color: PersonalizationArtColors.onArt,
              fontWeight: AppTypography.bold,
              letterSpacing: PersonalizationLayout.heroWordTracking,
              fontSize: fluidByWidth(
                columnWidth,
                min: PersonalizationLayout.heroWordMinSize,
                max: PersonalizationLayout.heroWordMaxSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
