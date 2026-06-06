import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'cards_repository.dart';
import 'connections_repository.dart';

part 'connections_providers.g.dart';

/// DI seam for the connections repository. The concrete implementation is
/// supplied as a composition-root override in `main.dart`.
@riverpod
ConnectionsRepository connectionsRepository(Ref ref) =>
    throw UnimplementedError(
      'connectionsRepositoryProvider must be overridden',
    );

/// DI seam for the cards repository. The concrete implementation is supplied
/// as a composition-root override in `main.dart`.
///
/// Declares an (empty) `dependencies` list so it is a scopeable provider: the
/// keyed `cardProvider` family that reads it lists it as a dependency, which
/// Riverpod requires for the override to propagate into the family.
@Riverpod(dependencies: [])
CardsRepository cardsRepository(Ref ref) =>
    throw UnimplementedError('cardsRepositoryProvider must be overridden');
