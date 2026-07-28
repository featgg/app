import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';

/// Where an art card's picture comes from.
///
/// One linked platform's art today. Deliberately a named source rather than the
/// widget's `platform` binding: an art card reads no data from an account, it
/// points at an image — and the image the owner uploads themselves, once that
/// lands, is a source with no platform behind it at all.
final class ArtSelection extends Equatable {
  const ArtSelection({this.source});

  /// The platform whose art the card shows, or null for a card the owner has
  /// added but not pointed anywhere yet.
  final Platform? source;

  static const empty = ArtSelection();

  bool get isEmpty => source == null;

  @override
  List<Object?> get props => [source];
}
