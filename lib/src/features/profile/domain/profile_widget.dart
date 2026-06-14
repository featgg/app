import 'package:equatable/equatable.dart';

import '../../connections/domain/connection.dart';

/// Forward-compatible widget kinds. Only [platform] is implemented today; the
/// others are reserved for later personalization phases and degrade to
/// "unknown → omit" on read. The full set is listed up front so later phases
/// add no enum churn.
enum ProfileWidgetKind { platform, dataMenu, template, composed }

/// Grid footprint a widget occupies. Maps to staggered-grid spans in
/// presentation: small→1x1, wide→2x1, large→2x2. Unknown wire tokens degrade
/// to [small].
enum ProfileWidgetSize { small, wide, large }

/// Schema version of the `settings` JSON envelope. v1 from day one; the data
/// layer omits any row whose envelope is a different version. Mirrors the
/// `game_cards.widget_data` version gate.
const int kProfileWidgetSettingsVersion = 1;

/// A profile-layout widget read from `profile_widgets`. The widget row carries
/// the layout (position, size, enabled state) and the kind/identity; the card
/// content for a [ProfileWidgetKind.platform] widget still comes from the
/// `game_cards` surface.
final class ProfileWidget extends Equatable {
  const ProfileWidget({
    required this.id,
    required this.kind,
    required this.platform,
    required this.position,
    required this.isEnabled,
    required this.size,
  });

  final String id;
  final ProfileWidgetKind kind;

  /// Non-null for [ProfileWidgetKind.platform]; null otherwise.
  final Platform? platform;
  final int position;
  final bool isEnabled;
  final ProfileWidgetSize size;

  ProfileWidget copyWith({
    int? position,
    bool? isEnabled,
    ProfileWidgetSize? size,
  }) => ProfileWidget(
    id: id,
    kind: kind,
    platform: platform,
    position: position ?? this.position,
    isEnabled: isEnabled ?? this.isEnabled,
    size: size ?? this.size,
  );

  @override
  List<Object?> get props => [id, kind, platform, position, isEnabled, size];
}
