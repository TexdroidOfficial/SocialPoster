import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/accounts/presentation/accounts_page.dart';
import '../features/media/presentation/media_page.dart';
import '../features/publishing/presentation/publishing_page.dart';
import 'theme.dart';

class SocialPublisherApp extends ConsumerWidget {
  const SocialPublisherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Signal Post',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _pages = [PublishingPage(), MediaPage(), AccountsPage()];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            extended: wide,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 32),
              child: Icon(
                Icons.near_me_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.send_outlined),
                selectedIcon: Icon(Icons.send),
                label: Text('Publish'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.perm_media_outlined),
                selectedIcon: Icon(Icons.perm_media),
                label: Text('Media'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub),
                label: Text('Accounts'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.send_outlined),
                  selectedIcon: Icon(Icons.send),
                  label: 'Publish',
                ),
                NavigationDestination(
                  icon: Icon(Icons.perm_media_outlined),
                  selectedIcon: Icon(Icons.perm_media),
                  label: 'Media',
                ),
                NavigationDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub),
                  label: 'Accounts',
                ),
              ],
            ),
    );
  }
}
