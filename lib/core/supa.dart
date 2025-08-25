import 'package:supabase_flutter/supabase_flutter.dart';

final supa = Supabase.instance.client;

Future<void> initSupabase(String url, String anonKey) async {
  await Supabase.initialize(url: url, anonKey: anonKey);
}
