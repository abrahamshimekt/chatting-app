import 'package:flutter/material.dart';
import '../../core/supa.dart';
import '../profile/profile_model.dart';
import '../profile/profile_repo.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ProfileRepo repo = ProfileRepo();
  List<Map<String, dynamic>> usersWithPayments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      // Join profiles with coin_txns to get payment information
      final response = await supa
          .from('profiles')
          .select(
            '*, coin_txns(account_number, transaction_id, amount, status)',
          )
          .eq(
            'coin_txns.status',
            'pending',
          ); // Optional: filter for pending transactions
      setState(() {
        usersWithPayments = (response as List).map((json) {
          final profile = Profile.fromJson(json);
          final payments =
              (json['coin_txns'] as List?)
                  ?.map(
                    (p) => {
                      'account_number': p['account_number'],
                      'transaction_id': p['transaction_id'],
                      'amount': p['amount'],
                      'status': p['status'],
                    },
                  )
                  .toList() ??
              [];
          return {'profile': profile, 'payments': payments};
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _approveTransaction(String transactionId) async {
    try {
      await supa.rpc(
        'approve_transaction',
        params: {'transaction_id_param': transactionId},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction approved')));
      _loadUsers(); // Refresh the list after approval
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: usersWithPayments.length,
              itemBuilder: (context, index) {
                final userData = usersWithPayments[index];
                final profile = userData['profile'] as Profile;
                final payments =
                    userData['payments'] as List<Map<String, dynamic>>;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      child: Text(
                        profile.displayName.isNotEmpty
                            ? profile.displayName[0].toUpperCase()
                            : 'U',
                      ),
                    ),
                    title: Text(profile.displayName),
                    subtitle: Text(profile.gender),
                    children: payments.map((payment) {
                      final isPending = payment['status'] == 'pending';
                      return ListTile(
                        title: Text(
                          'Transaction ID: ${payment['transaction_id']}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account: ${payment['account_number']}'),
                            Text('Amount: ${payment['amount']} coins'),
                            Text('Status: ${payment['status']}'),
                          ],
                        ),
                        trailing: isPending
                            ? ElevatedButton(
                                onPressed: () => _approveTransaction(
                                  payment['transaction_id'],
                                ),
                                child: const Text('Approve'),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
