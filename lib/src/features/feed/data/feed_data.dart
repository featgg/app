/// Data layer of the feed feature: DTOs, data sources, repository
/// implementation, and DI builder function.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/observability/observability.dart';
import '../../../core/supabase/supabase.dart';
import '../domain/feed_repository.dart';
import 'feed_repository_impl.dart';
import 'supabase_feed_data_source.dart';

/// Builds the concrete feed repository. Called at the composition root to
/// override the domain seam.
FeedRepository buildFeedRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return FeedRepositoryImpl(
    SupabaseFeedDataSource(client),
    () => client.auth.currentUser?.id,
    ref.watch(crashReporterProvider),
  );
}
