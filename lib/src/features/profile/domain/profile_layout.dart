import 'package:equatable/equatable.dart';

/// One row of the profile composition. The *row* — not the card — is the
/// persisted layout object: a [FullRow]
/// spans the column, a [PairRow] holds up to two side-by-side halves. Rendering
/// a row never inspects another row (no auto re-flow, no auto-pairing).
sealed class ProfileLayoutRow extends Equatable {
  const ProfileLayoutRow();
}

/// A row occupied by a single card that spans the full column width.
final class FullRow extends ProfileLayoutRow {
  const FullRow(this.cardId);

  final String cardId;

  @override
  List<Object?> get props => [cardId];
}

/// A pair row of up to two half cards. At least one slot is non-null (the
/// parser guarantees it); a single non-null slot renders a centered orphan
/// never an empty artifact.
final class PairRow extends ProfileLayoutRow {
  const PairRow({this.left, this.right});

  final String? left;
  final String? right;

  @override
  List<Object?> get props => [left, right];
}
