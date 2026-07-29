import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/collection_selection.dart';
import '../domain/art_selection.dart';
import '../domain/profile_widget.dart';
import '../domain/profile_widgets_repository.dart';
import '../domain/showcase_selection.dart';
import 'profile_widget_dto.dart';
import 'profile_widgets_data_source.dart';

final class ProfileWidgetsRepositoryImpl implements ProfileWidgetsRepository {
  ProfileWidgetsRepositoryImpl(
    this._source,
    this._currentUserId,
    this._crashReporter,
  );

  final ProfileWidgetsDataSource _source;
  final String? Function() _currentUserId;
  final CrashReporter _crashReporter;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final dtos = await _source.fetchMyWidgets(userId);
      // Soft resolution: a row that maps to null (unknown kind, wrong envelope
      // version, or unknown platform) is dropped rather than failing the read.
      final widgets = dtos
          .map(profileWidgetFromDto)
          .whereType<ProfileWidget>()
          .toList();
      return right(widgets);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async {
    try {
      final dtos = await _source.fetchPublicWidgets(userId);
      // Same soft resolution as the owner read: a row that maps to null
      // (unknown kind, wrong envelope version, or unknown platform) is dropped
      // rather than failing the read.
      final widgets = dtos
          .map(profileWidgetFromDto)
          .whereType<ProfileWidget>()
          .toList();
      return right(widgets);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final wireValue =
          platformDescriptors[platform]?.wireValue ?? platform.name;
      final dto = await _source.insertWidget({
        'platform': wireValue,
        'type': profileWidgetKindToWire(ProfileWidgetKind.platform),
        'position': position,
        'is_enabled': true,
        'settings': {
          'schema_version': kProfileWidgetSettingsVersion,
          'size': profileWidgetSizeToWire(size),
        },
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final wireValue =
          platformDescriptors[platform]?.wireValue ?? platform.name;
      final dto = await _source.insertWidget({
        'platform': wireValue,
        'type': profileWidgetKindToWire(ProfileWidgetKind.showcase),
        'position': position,
        'is_enabled': true,
        'settings': mergeShowcaseSelectionIntoSettings(size, selection),
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final dto = await _source.insertWidget({
        'platform': null,
        'type': profileWidgetKindToWire(ProfileWidgetKind.collection),
        'position': position,
        'is_enabled': true,
        'settings': mergeCollectionSelectionIntoSettings(size, selection),
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final wireValue =
          platformDescriptors[platform]?.wireValue ?? platform.name;
      final dto = await _source.insertWidget({
        'platform': wireValue,
        'type': profileWidgetKindToWire(ProfileWidgetKind.gameCollector),
        'position': position,
        'is_enabled': true,
        // Size-only envelope: the collector aggregates the whole library, so it
        // carries no per-widget selection sub-object beyond size.
        'settings': {
          'schema_version': kProfileWidgetSettingsVersion,
          'size': profileWidgetSizeToWire(size),
        },
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final wireValue =
          platformDescriptors[platform]?.wireValue ?? platform.name;
      final dto = await _source.insertWidget({
        'platform': wireValue,
        'type': profileWidgetKindToWire(ProfileWidgetKind.completionist),
        'position': position,
        'is_enabled': true,
        // Size-only envelope: the completionist surfaces a whole-library count,
        // so it carries no per-widget selection sub-object beyond size.
        'settings': {
          'schema_version': kProfileWidgetSettingsVersion,
          'size': profileWidgetSizeToWire(size),
        },
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final dto = await _source.insertWidget({
        'platform': null,
        'type': profileWidgetKindToWire(ProfileWidgetKind.passport),
        'position': position,
        'is_enabled': true,
        // Size-only envelope: the passport aggregates every linked platform, so
        // it carries no per-widget selection sub-object beyond size.
        'settings': {
          'schema_version': kProfileWidgetSettingsVersion,
          'size': profileWidgetSizeToWire(size),
        },
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addArtWidget({
    Platform? source,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final dto = await _source.insertWidget({
        // Platform-less on the row; a pinned source lives in the envelope,
        // and the usual unpinned add writes a size-only envelope.
        'platform': null,
        'type': profileWidgetKindToWire(ProfileWidgetKind.art),
        'position': position,
        'is_enabled': true,
        'settings': mergeArtSelectionIntoSettings(
          size,
          ArtSelection(source: source),
        ),
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final wireValue =
          platformDescriptors[platform]?.wireValue ?? platform.name;
      final dto = await _source.insertWidget({
        'platform': wireValue,
        'type': profileWidgetKindToWire(ProfileWidgetKind.rank),
        'position': position,
        'is_enabled': true,
        // Size-only envelope: the rank card renders the platform's competitive
        // standing, so it carries no per-widget selection sub-object beyond size.
        'settings': {
          'schema_version': kProfileWidgetSettingsVersion,
          'size': profileWidgetSizeToWire(size),
        },
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final wireValue =
          platformDescriptors[platform]?.wireValue ?? platform.name;
      final dto = await _source.insertWidget({
        'platform': wireValue,
        'type': profileWidgetKindToWire(ProfileWidgetKind.main),
        'position': position,
        'is_enabled': true,
        // Size-only envelope: the main card renders the platform's primary
        // game/character/mode, so it carries no selection sub-object beyond size.
        'settings': {
          'schema_version': kProfileWidgetSettingsVersion,
          'size': profileWidgetSizeToWire(size),
        },
      });
      final widget = profileWidgetFromDto(dto);
      if (widget == null) {
        // The just-written row failed to map — a fault, not control flow.
        throw const FormatException('inserted widget row did not map');
      }
      return right(widget);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeWidget(String id) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      await _source.deleteWidget(id);
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> setSize(
    String id,
    ProfileWidgetSize size,
  ) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      await _source.updateWidget(id, {
        'settings': {
          'schema_version': kProfileWidgetSettingsVersion,
          'size': profileWidgetSizeToWire(size),
        },
      });
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  ) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      await _source.updateWidget(id, {
        'settings': mergeShowcaseSelectionIntoSettings(size, selection),
      });
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  ) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      await _source.updateWidget(id, {
        'settings': mergeCollectionSelectionIntoSettings(size, selection),
      });
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final updates = [
        for (var i = 0; i < orderedIds.length; i++)
          (id: orderedIds[i], position: i),
      ];
      await _source.updatePositions(updates);
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  Failure _handleError(Object error, StackTrace st) {
    final failure = _mapError(error);
    if (!failure.isExpected) _crashReporter.reportError(error, st);
    return failure;
  }

  Failure _mapError(Object error) {
    if (error is AuthException) {
      final status = error.statusCode;
      if (status == '401' || status == '403') return const AuthFailure();
      return UnexpectedFailure(message: error.message);
    }
    if (error is PostgrestException) {
      final code = error.code;
      // PostgREST surfaces access denials / auth-token problems as 401/403.
      if (code == '401' || code == '403' || code == 'PGRST301') {
        return const AuthFailure();
      }
      // Postgres integrity-violation class (23xxx): unique (position), check (the
      // per-user cap), and size/not-null violations are expected, user-driven
      // rejections — the backend constraint is authoritative and the client
      // surfaces the rejection as an InputFailure (not a crash-reported fault).
      if (code != null && code.startsWith('23')) {
        return InputFailure(message: error.message, code: code);
      }
      return UnexpectedFailure(message: error.message);
    }
    if (error is SocketException) return NetworkFailure(message: error.message);
    if (error is TimeoutException) {
      return NetworkFailure(message: error.message);
    }
    return UnexpectedFailure(message: error.toString());
  }
}
