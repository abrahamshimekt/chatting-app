import '../../core/supa.dart';

class GiftsRepo {
  Future<List<Map<String, dynamic>>> catalog() async {
    return await supa.from('gift_catalog').select('*').order('price_coins');
  }

  Future<void> sendGift({required String receiver, required int giftId}) async {
    final uid = supa.auth.currentUser!.id;
    // naive client-side flow (production: server function)
    final gift = await supa
        .from('gift_catalog')
        .select('price_coins')
        .eq('id', giftId)
        .single();
    final price = gift['price_coins'] as int;

    final w = await supa
        .from('wallets')
        .select('balance')
        .eq('user_id', uid)
        .single();
    final bal = w['balance'] as int;
    if (bal < price) throw Exception('Insufficient coins');

    // debit sender wallet & log txn
    await supa
        .from('wallets')
        .update({'balance': bal - price})
        .eq('user_id', uid);
    await supa.from('coin_txns').insert({
      'user_id': uid,
      'kind': 'gift_send',
      'amount': -price,
      'meta': {'gift_id': giftId, 'to': receiver},
    });

    // record gift; credit receiver (could be via trigger)
    await supa.from('sent_gifts').insert({
      'sender': uid,
      'receiver': receiver,
      'gift_id': giftId,
    });
    final rw = await supa
        .from('wallets')
        .select('balance')
        .eq('user_id', receiver)
        .single();
    final rbal = rw['balance'] as int;
    await supa
        .from('wallets')
        .update({'balance': rbal + price})
        .eq('user_id', receiver);
    await supa.from('coin_txns').insert({
      'user_id': receiver,
      'kind': 'gift_receive',
      'amount': price,
      'meta': {'gift_id': giftId, 'from': uid},
    });
  }
}
