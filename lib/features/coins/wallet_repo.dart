import '../../core/supa.dart';

class WalletRepo {
  Stream<int> balance() {
    final uid = supa.auth.currentUser!.id;
    return supa
        .from('wallets')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map((rows) => rows.isEmpty ? 0 : (rows.first['balance'] as int));
  }

  Future<void> addCoins(int amount) async {
    // In real app, do via server-side function after payment
    final uid = supa.auth.currentUser!.id;
    await supa
        .rpc('increment_balance', params: {'p_user': uid, 'p_amount': amount})
        .onError((_, __) async {
          // fallback if RPC not available
          final row = await supa
              .from('wallets')
              .select('balance')
              .eq('user_id', uid)
              .single();
          final bal = (row['balance'] as int) + amount;
          await supa
              .from('wallets')
              .update({'balance': bal})
              .eq('user_id', uid);
          await supa.from('coin_txns').insert({
            'user_id': uid,
            'kind': 'bonus',
            'amount': amount,
          });
        });
  }
}
