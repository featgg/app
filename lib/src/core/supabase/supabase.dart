/// Supabase SDK client provider for the core layer. Shared by every feature
/// that needs access to the Supabase client; living in core avoids
/// cross-feature data-layer imports.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase.g.dart';

@riverpod
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;
