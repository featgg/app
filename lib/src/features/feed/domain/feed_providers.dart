import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'feed_repository.dart';

part 'feed_providers.g.dart';

/// DI seam for the feed repository. The concrete implementation is
/// supplied as a composition-root override in `main.dart`.
@riverpod
FeedRepository feedRepository(Ref ref) =>
    throw UnimplementedError('feedRepositoryProvider must be overridden');
