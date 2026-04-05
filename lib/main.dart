import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'app/app.dart';
import 'core/services/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs (e.g. /settings) instead of hash-based (/#/settings)
  usePathUrlStrategy();

  // Initialize Supabase (handles offline mode gracefully)
  await initializeSupabase();

  runApp(
    const ProviderScope(
      child: JetLagApp(),
    ),
  );
}
