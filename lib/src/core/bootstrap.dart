import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env/env.dart';
import 'observability/observability.dart';

/// Initializes app-wide startup dependencies before `runApp`.
///
/// Order: bind the Flutter engine, validate compile-time config, initialize
/// the Supabase SDK, then run [appRunner] — wrapped in `SentryFlutter.init`
/// when a DSN is present, or called directly when no DSN is configured.
/// Throws [EnvException] (from [Env.requireValid]) when a required define is
/// missing; the throw surfaces as a loud, immediate boot failure.
Future<void> bootstrap(FutureOr<void> Function() appRunner) async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.requireValid();
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  if (Env.sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryDsn;
      options.beforeSend = filterExpectedFailures;
    }, appRunner: appRunner);
  } else {
    await appRunner();
  }
}
