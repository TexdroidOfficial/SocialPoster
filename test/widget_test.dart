import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_poster/app/app.dart';
import 'package:social_poster/core/config/environment.dart';
import 'package:social_poster/core/persistence/app_database.dart';
import 'package:social_poster/core/security/secret_store.dart';
import 'package:social_poster/features/accounts/application/account_controller.dart';

void main() {
  testWidgets('renders the publishing workspace', (tester) async {
    final database = AppDatabase.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          environmentProvider.overrideWithValue(const AppEnvironment()),
        ],
        child: const SocialPublisherApp(),
      ),
    );
    expect(find.text('Publish workspace'), findsOneWidget);
    expect(
      find.text('No accounts connected yet. Add them from Accounts.'),
      findsOneWidget,
    );
    database.close();
  });
}
