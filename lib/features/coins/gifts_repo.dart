import '../../core/supa.dart';

class GiftsRepo {
  Future<List<Map<String, dynamic>>> catalog() async {
    return await supa
        .from('gift_catalog')
        .select('id, name, price_coins, icon')
        .order('price_coins');
  }

  Future<Map<String, dynamic>> getUserBalance() async {
    final uid = supa.auth.currentUser!.id;
    return await supa
        .from('wallets')
        .select('balance')
        .eq('user_id', uid)
        .single();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    return await supa
        .from('profiles')
        .select('user_id, display_name, avatar_url')
        .ilike('display_name', '%$query%')
        .order('display_name');
  }

  Future<void> sendGift({
    required String receiver,
    required String giftId,
    required int giftPrice,
  }) async {
    final uid = supa.auth.currentUser!.id;
    await supa.rpc(
      'update_wallets_after_gift',
      params: {
        'p_sender_id': uid,
        'p_receiver_id': receiver,
        'p_gift_id': giftId,
        'p_gift_price': giftPrice,
      },
    );
  }
}
