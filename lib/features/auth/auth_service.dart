import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supa.dart';

class AuthService {
  final _c = supa;

  Future<AuthResponse> signIn(String email, String password) {
    return _c.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(
    String email,
    String password, {
    required String displayName,
    required String gender,
    required bool genderVerified,
    required DateTime dateOfBirth, 
    required String country,       
    required String region,        
    required String city,          
    String? subcity='',               
  }) async {
    final data = <String, dynamic>{
      'display_name': displayName,
      'gender': gender,
      'is_verified_gender': genderVerified,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'country': country,
      'region': region,
      'city': city,
      "subcity":subcity,
    };
    // Supabase signUp will store this into auth.users.user_metadata
    final res = await _c.auth.signUp(
      email: email,
      password: password,
      data: data,
    );

    return res;
  }

  Future<void> signOut() => _c.auth.signOut();
}
