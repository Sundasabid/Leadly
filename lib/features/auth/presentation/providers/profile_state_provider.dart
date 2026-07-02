import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/profile_repository.dart';
import '../../domain/models/profile_model.dart';
import 'auth_provider.dart';

/// Returns true if the current authenticated user has a profiles row.
/// Watches authStateProvider so it re-evaluates on login/logout.
/// Errors are caught and treated as "no profile" to avoid blocking the router.
final profileExistsProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;

  try {
    final result = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    return result != null;
  } catch (_) {
    return false;
  }
});

/// Fetches the full profile row for the current user.
/// Re-fetches on auth state change. Used by Settings header and Account Info.
final profileDataProvider = FutureProvider<ProfileModel?>((ref) {
  ref.watch(authStateProvider);
  return ref.read(profileRepositoryProvider).fetchProfile();
});
