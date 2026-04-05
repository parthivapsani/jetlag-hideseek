import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (handles offline mode gracefully)
  await initializeSupabase();

  runApp(
    const ProviderScope(
      child: JetLagApp(),
    ),
  );
}
