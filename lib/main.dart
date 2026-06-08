import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'state/auth.dart';
import 'theme.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _forceSignOutOnStart = bool.fromEnvironment(
  'FORCE_SIGN_OUT_ON_START',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var hasSupabase = _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;
  if (hasSupabase) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      if (_forceSignOutOnStart) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {
      // Supabase is best-effort — demo data keeps the app fully usable.
      hasSupabase = false;
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        supabaseConfiguredProvider.overrideWith((_) => hasSupabase),
      ],
      child: const MorePropertiesApp(),
    ),
  );
}

class MorePropertiesApp extends ConsumerStatefulWidget {
  const MorePropertiesApp({super.key});

  @override
  ConsumerState<MorePropertiesApp> createState() => _MorePropertiesAppState();
}

class _MorePropertiesAppState extends ConsumerState<MorePropertiesApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      hydrateLiveData(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(onboardingSeenProvider);
    final configured = ref.watch(supabaseConfiguredProvider);
    final isSignedIn = ref.watch(isSignedInProvider);

    final home = !seen
        ? const OnboardingScreen()
        : (configured && !isSignedIn)
            ? const AuthScreen(popOnSuccess: false)
            : const AppShell();

    return MaterialApp(
      title: 'More Properties',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      home: home,
    );
  }
}
