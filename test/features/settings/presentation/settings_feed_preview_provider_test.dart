import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/settings/presentation/settings_feed_preview_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedPreviewOptions.selectable', () {
    test('offers the linked platforms when nothing is pinned', () {
      const options = FeedPreviewOptions(
        selected: null,
        linked: [Platform.steam, Platform.chess],
      );

      expect(options.selectable, [Platform.steam, Platform.chess]);
    });

    test('keeps a pinned platform offered after it is unlinked', () {
      // Otherwise the control would read as "automatic" while the profile
      // still pins a platform — the owner could not see, or clear, what is
      // actually stored.
      const options = FeedPreviewOptions(
        selected: Platform.wowRetail,
        linked: [Platform.steam],
      );

      expect(options.selectable, [Platform.steam, Platform.wowRetail]);
    });

    test('does not duplicate a pinned platform that is still linked', () {
      const options = FeedPreviewOptions(
        selected: Platform.steam,
        linked: [Platform.steam, Platform.chess],
      );

      expect(options.selectable, [Platform.steam, Platform.chess]);
    });
  });
}
