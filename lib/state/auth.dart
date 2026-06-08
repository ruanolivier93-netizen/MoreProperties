import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repository.dart';
import '../models/models.dart';

/// True when Supabase URL + anon key were provided at build time.
final supabaseConfiguredProvider = StateProvider<bool>((_) => false);

/// Lazy access to the Supabase client.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return Supabase.instance.client;
});

/// Repository that exposes typed reads/writes against Supabase. Null when the
/// app is running in demo mode.
final repositoryProvider = Provider<SupabaseRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabaseRepository(client);
});

/// Live Supabase auth state. Emits on every sign-in / sign-out / refresh.
final authStateChangesProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const Stream.empty();
  return client.auth.onAuthStateChange;
});

/// Current Supabase user (or null when signed out / demo mode).
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider)?.auth.currentUser;
});

/// True when a user is signed into Supabase.
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider) != null,
);

/// Async profile fetch keyed off the current user.
final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repo == null || user == null) return null;
  try {
    return await repo.fetchProfile(user.id);
  } catch (_) {
    return null;
  }
});

/// Agent record linked to the signed-in user (null for buyers/guests).
final myAgentProvider = FutureProvider<Agent?>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repo == null || user == null) return null;
  try {
    return await repo.fetchAgentForUser(user.id);
  } catch (_) {
    return null;
  }
});

/// True when the signed-in user is linked to an agent row, exposing Studio.
final isAgentProvider = Provider<bool>(
  (ref) => ref.watch(myAgentProvider).valueOrNull != null,
);

class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  Future<void> signIn({required String email, required String password}) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> verifySignUpCode({
    required String email,
    required String token,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  Future<void> resendSignUpCode(String email) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.resend(
      email: email,
      type: OtpType.signup,
    );
  }

  Future<void> sendMagicLink(String email) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.signInWithOtp(email: email);
  }

  Future<void> resetPassword(String email) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.resetPasswordForEmail(email);
  }

  Future<void> signInWithGoogle() async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signInWithApple() async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client.auth.signInWithOAuth(OAuthProvider.apple);
  }

  Future<void> signOut() async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) return;
    await client.auth.signOut();
  }
}

final authControllerProvider = Provider<AuthController>(AuthController.new);
