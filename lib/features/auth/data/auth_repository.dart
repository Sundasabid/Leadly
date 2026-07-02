import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final _client = Supabase.instance.client;

  Future<void> signOut() => _client.auth.signOut();

  Future<void> updatePassword(String newPassword) =>
      _client.auth.updateUser(UserAttributes(password: newPassword));
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());
