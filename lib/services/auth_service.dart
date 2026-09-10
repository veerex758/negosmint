import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import '../models/app_profile.dart';

/// Wraps Supabase Auth + the profiles table. Screens should go through
/// this rather than calling `supabase.auth` directly, so auth logic (and
/// any future changes to it) lives in one place.
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  User? get currentUser => supabase.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  /// Fires on sign-in, sign-out, and token refresh.
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String phone,
    String? referralCode,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'username': username,
        'phone': phone,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
      },
    );
    // The `handle_new_user` Postgres trigger (see supabase/schema.sql)
    // creates the profiles/streaks/levels rows server-side as soon as
    // the auth.users row lands — nothing else to do client-side here.
  }

  Future<void> signIn({required String email, required String password}) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => supabase.auth.signOut();

  Future<AppProfile?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return row == null ? null : AppProfile.fromMap(row);
  }
}
