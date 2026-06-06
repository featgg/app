/// Data layer of the connections feature: DTOs, data sources, repository
/// implementations, and DI builder functions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/observability/observability.dart';
import '../../../core/supabase/supabase.dart';
import '../domain/cards_repository.dart';
import '../domain/connections_repository.dart';
import 'cards_repository_impl.dart';
import 'connections_repository_impl.dart';
import 'supabase_cards_data_source.dart';
import 'supabase_connections_data_source.dart';

/// Builds the concrete connections repository. Called at the composition root
/// to override the domain seam.
ConnectionsRepository buildConnectionsRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ConnectionsRepositoryImpl(
    SupabaseConnectionsDataSource(client),
    () => client.auth.currentUser?.id,
    ref.watch(crashReporterProvider),
  );
}

/// Builds the concrete cards repository. Called at the composition root to
/// override the domain seam.
CardsRepository buildCardsRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return CardsRepositoryImpl(
    SupabaseCardsDataSource(client),
    () => client.auth.currentUser?.id,
    ref.watch(crashReporterProvider),
  );
}
