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

  Future<void> buyCoins(int coins, int priceInEtb, String paymentMethod, Map<String, String> paymentDetails) async {
    // Validate payment details
    if (paymentMethod == 'CBE') {
      if (paymentDetails['account_number']!.isEmpty) {
        throw Exception('Invalid CBE account number');
      }
      if (paymentDetails['receiver_account'] != '369390') {
        throw Exception('Invalid receiver account');
      }
    } else if (paymentMethod == 'TeleBirr') {
      if (paymentDetails['phone_number']!.isEmpty) {
        throw Exception('Invalid phone number');
      }
      if (paymentDetails['receiver_phone'] != '0901191234') {
        throw Exception('Invalid receiver phone number');
      }
    }
    if (paymentDetails['transaction_id']!.isEmpty) {
      throw Exception('Invalid transaction ID');
    }

    // Simulate payment processing delay
    await Future.delayed(const Duration(seconds: 2));

    // Record transaction as pending (balance update awaits admin approval)
    final uid = supa.auth.currentUser!.id;
    final accountNumber = paymentMethod == 'CBE' ? paymentDetails['account_number'] : paymentDetails['phone_number'];
    await supa.from('coin_txns').insert({
      'user_id': uid,
      'kind': 'purchase', // Adjust based on your txn_kind enum
      'amount': coins,
      'transaction_id': paymentDetails['transaction_id'],
      'account_number': accountNumber,
      'meta': {'price': priceInEtb, 'method': paymentMethod},
      'status': 'pending',
    });
  }

  Future<void> addCoins(int amount) async {
    final uid = supa.auth.currentUser!.id;
    await supa
        .rpc('increment_balance', params: {'p_user': uid, 'p_amount': amount})
        .onError((_, __) async {
          // Fallback if RPC not available
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

  Future<void> approveTransaction(String transactionId) async {
    try {
      await supa.rpc('approve_transaction', params: {'transaction_id_param': transactionId});
    } catch (e) {
      throw Exception('Failed to approve transaction: $e');
    }
  }
}