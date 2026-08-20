import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_poster/app/app.dart';
import 'package:social_poster/core/config/environment.dart';
import 'package:social_poster/features/accounts/application/account_controller.dart';

void main() {
  testWidgets('renders the publishing workspace', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentProvider.overrideWithValue(const AppEnvironment()),
        ],
        child: const SocialPublisherApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Configure OAUTH_API_BASE_URL'), findsOneWidget);
  });
}
