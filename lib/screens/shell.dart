import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth.dart';
import '../theme.dart';
import 'account.dart';
import 'auth.dart';
import 'favourites.dart';
import 'home.dart';
import 'saved_searches.dart';
import 'search.dart';
import 'studio.dart';
import 'tools.dart';

/// Main bottom-navigation shell. Adds an Agent Studio tab for users whose
/// profile is linked to an `agents` row in Supabase.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAgent = ref.watch(isAgentProvider);
    final isSignedIn = ref.watch(isSignedInProvider);
    final configured = ref.watch(supabaseConfiguredProvider);

    final pages = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const ToolsScreen(),
      const FavouritesScreen(),
      if (isAgent) const StudioScreen(),
      const AccountScreen(),
    ];

    // Keep selected index in range when Studio toggles on/off.
    final safeIndex = _index.clamp(0, pages.length - 1);

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(safeIndex),
          child: pages[safeIndex],
        ),
      ),
      floatingActionButton: safeIndex == 3
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              onPressed: () async {
                if (!configured) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sign-in is unavailable in demo mode. Add Supabase keys first.',
                      ),
                    ),
                  );
                  return;
                }

                if (!isSignedIn) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                  if (!context.mounted) return;
                  if (!ref.read(isSignedInProvider)) return;
                }

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SavedSearchesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bookmark_added_outlined),
              label: const Text('Alerts'),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.outline, width: 0.6),
          ),
        ),
        child: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Discover',
            ),
            const NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'Tools',
            ),
            const NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Saved',
            ),
            if (isAgent)
              const NavigationDestination(
                icon: Icon(Icons.work_outline),
                selectedIcon: Icon(Icons.work),
                label: 'Studio',
              ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
