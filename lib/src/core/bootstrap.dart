import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env/env.dart';

/// Initializes app-wide startup dependencies before `runApp`.
///
/// Order: bind the Flutter engine, validate compile-time config, initialize
/// the Supabase SDK. Throws [EnvException] (from [Env.requireValid]) when a
/// required define is missing; the throw is intentional and surfaces as a
/// loud, immediate boot failure. SDK init lives here as startup wiring, not in
/// the data layer that owns SDK calls.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.requireValid();
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
}
