import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.fromPlatform();
  runApp(
    ProviderScope(
      overrides: [appEnvironmentProvider.overrideWithValue(environment)],
      child: const SocialPublisherApp(),
    ),
  );
}
