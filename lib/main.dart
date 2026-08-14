import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/environment.dart';
import 'core/persistence/app_database.dart';
import 'core/security/secret_store.dart';
import 'features/accounts/application/account_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.fromPlatform();
  final database = await AppDatabase.open();
  final secrets = SecureSecretStore();
  runApp(
    ProviderScope(
      overrides: [
        environmentProvider.overrideWithValue(environment),
        databaseProvider.overrideWithValue(database),
        secretStoreProvider.overrideWithValue(secrets),
      ],
      child: const SocialPublisherApp(),
    ),
  );
}
