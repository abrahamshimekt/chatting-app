import '../../core/supa.dart';
import 'profile_model.dart';

class ProfileRepo {
  Future<Profile?> getMe() async {
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return null;
    final res = await supa
        .from('profiles')
        .select()
        .eq('user_id', uid)
        .single();
    return Profile.fromJson(res);
  }

  Future<void> updateMe({
    required String displayName,
    required String gender,
  }) async {
    final uid = supa.auth.currentUser!.id;
    await supa
        .from('profiles')
        .update({'display_name': displayName, 'gender': gender})
        .eq('user_id', uid);
  }
}
