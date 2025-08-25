import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supa.dart';

class Person {
  final String userId;
  final String displayName;
  final String gender;
  final String? avatarUrl;

  // NEW: location fields
  final String? country;
  final String? region;
  final String? city;
  final String? subcity;

  Person({
    required this.userId,
    required this.displayName,
    required this.gender,
    this.avatarUrl,
    this.country,
    this.region,
    this.city,
    this.subcity,
  });

  factory Person.fromRow(Map<String, dynamic> r) => Person(
        userId: r['user_id'] as String,
        displayName: (r['display_name'] as String?) ?? 'User',
        gender: (r['gender'] as String?)?.toLowerCase() ?? 'male',
        avatarUrl: r['avatar_url'] as String?,
        country: (r['country'] as String?)?.trim(),
        region: (r['region'] as String?)?.trim(),
        city: (r['city'] as String?)?.trim(),
        subcity: (r['subcity'] as String?)?.trim(),
      );
}

class PeopleRepo {
  final SupabaseClient _c = supa;

  /// Stream opposite-gender profiles. We still filter opposite-gender client-side
  /// to keep the stream() simple + compatible with realtime.
  Stream<List<Person>> oppositeGenderPeople() async* {
    final me = _c.auth.currentUser;
    if (me == null) {
      yield const <Person>[];
      return;
    }

    // find my gender
    final myProfile = await _c
        .from('profiles')
        .select('gender')
        .eq('user_id', me.id)
        .maybeSingle();

    final myGender = (myProfile?['gender'] as String?)?.toLowerCase() ?? 'male';
    final wantGender = myGender == 'male' ? 'female' : 'male';

    // stream all profiles (we'll filter in map)
    yield* _c
        .from('profiles')
        .stream(primaryKey: ['user_id'])
        .order('display_name')
        .map((rows) => rows
            .where((r) =>
                (r['gender'] as String?)?.toLowerCase() == wantGender &&
                r['user_id'] != me.id)
            .map(Person.fromRow)
            .toList());
  }

  /// 🔹 NEW: Fetch a single Person by userId
  Future<Person?> getById(String userId) async {
    final row = await _c
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return Person.fromRow(row);
  }
}
