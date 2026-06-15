import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/observability/observability.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/data_menu_selection.dart';
import '../domain/profile_widget.dart';
import '../domain/profile_widgets_repository.dart';
import '../domain/template_catalog.dart';
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
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      final dto = await _source.insertWidget({
        'platform': null,
        'type': profileWidgetKindToWire(ProfileWidgetKind.template),
        'position': position,
        'is_enabled': true,
        'settings': mergeTemplateFillIntoSettings(
          size,
          TemplateFill(templateId, const {}),
        ),
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
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  ) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      await _source.updateWidget(id, {
        'settings': mergeDataMenuSelectionIntoSettings(size, selection),
      });
      return right(unit);
    } catch (e, st) {
      return left(_handleError(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  ) async {
    try {
      final userId = _currentUserId();
      if (userId == null) return left(const AuthFailure());
      await _source.updateWidget(id, {
        'settings': mergeTemplateFillIntoSettings(size, fill),
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
