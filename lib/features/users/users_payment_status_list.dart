import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; // For clipboard functionality
import '../../core/supa.dart';
import '../profile/profile_model.dart';
import '../profile/profile_repo.dart';

class UsersPurchaseStatus extends StatefulWidget {
  const UsersPurchaseStatus({super.key});

  @override
  State<UsersPurchaseStatus> createState() => _UsersPurchaseStatusState();
}

class _UsersPurchaseStatusState extends State<UsersPurchaseStatus> {
  final ProfileRepo repo = ProfileRepo();
  List<Map<String, dynamic>> usersWithPayments = [];
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final response = await supa.rpc(
        'is_admin',
        params: {'user_id_param': supa.auth.currentUser!.id},
      );
      setState(() {
        _isAdmin = response as bool;
      });
      if (_isAdmin) {
        await _loadUsers();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print('Error checking admin status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check admin status: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await supa.rpc('get_users_purchase_status');
      print('Response: $response'); // Debug: Log the response

      setState(() {
        usersWithPayments = (response as List).map((json) {
          final profile = Profile(
            userId: json['user_id'],
            displayName: json['display_name'],
            gender: json['gender'] ?? '', // Adjust based on your Profile model
            country: '', // Add other required fields with defaults if needed
            region: '',
            dateOfBirth: DateTime(2000), // Placeholder
            city: '',
            role: '',
            // Map other Profile fields as necessary
          );
          final amount = json['amount'] is String
              ? int.parse(json['amount'])
              : json['amount'] as int? ?? 0;
          final totalPaid = json['total_paid'] is String
              ? num.parse(
                  json['total_paid'],
                ) // Use num to handle numeric values
              : json['total_paid'] as num? ?? 0;
          return {
            'profile': profile,
            'payments': [
              {
                'account_number': json['account_number'] ?? 'N/A',
                'transaction_id': json['transaction_id'] ?? 'N/A',
                'amount': amount, // e.g., coins for the pending transaction
                'status': json['status'] ?? 'N/A',
                'total_paid': totalPaid, // Total paid amount based on price
              },
            ],
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      print('Error loading users: $e'); // Debug: Log the error
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
      if (_isAdmin) await _loadUsers(); // Refresh only if admin
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve transaction: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Purchase Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 2,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isLargeScreen = screenWidth > 600;
          final padding = EdgeInsets.symmetric(
            horizontal: isLargeScreen ? 24.0 : 16.0,
            vertical: isLargeScreen ? 16.0 : 8.0,
          );
          final itemPadding = EdgeInsets.symmetric(
            horizontal: isLargeScreen ? 20.0 : 16.0,
            vertical: 8.0,
          );

          return _loading
              ? const Center(child: CircularProgressIndicator())
              : _isAdmin
              ? (usersWithPayments.isEmpty
                    ? Center(
                        child: Text(
                          'No users with pending transactions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.builder(
                        padding: padding,
                        itemCount: usersWithPayments.length,
                        itemBuilder: (context, index) {
                          final userData = usersWithPayments[index];
                          final profile = userData['profile'] as Profile;
                          final payments =
                              userData['payments']
                                  as List<Map<String, dynamic>>;

                          return Column(
                            children: payments.map((payment) {
                              final isPending = payment['status'] == 'pending';
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: ListTile(
                                  contentPadding: itemPadding,
                                  leading: CircleAvatar(
                                    radius: isLargeScreen ? 26.0 : 20.0,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.1),
                                    child: Text(
                                      profile.displayName.isNotEmpty
                                          ? profile.displayName[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        fontSize: isLargeScreen ? 18.0 : 16.0,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    profile.displayName,
                                    style: TextStyle(
                                      fontSize: isLargeScreen ? 16.0 : 14.0,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gender: ${profile.gender}',
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 14.0 : 12.0,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 4.0),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _copyToClipboard(
                                                payment['transaction_id'],
                                                'Transaction ID',
                                              ),
                                              child: Text(
                                                'Transaction ID: ${payment['transaction_id']}',
                                                style: TextStyle(
                                                  fontSize: isLargeScreen
                                                      ? 14.0
                                                      : 12.0,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy,
                                              size: isLargeScreen ? 18.0 : 16.0,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            onPressed: () => _copyToClipboard(
                                              payment['transaction_id'],
                                              'Transaction ID',
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _copyToClipboard(
                                                payment['account_number'],
                                                'Account Number',
                                              ),
                                              child: Text(
                                                'Account: ${payment['account_number']}',
                                                style: TextStyle(
                                                  fontSize: isLargeScreen
                                                      ? 14.0
                                                      : 12.0,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy,
                                              size: isLargeScreen ? 18.0 : 16.0,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            onPressed: () => _copyToClipboard(
                                              payment['account_number'],
                                              'Account Number',
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Paid Amount: ${payment['total_paid']} ETB',
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 14.0 : 12.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Total Coins: ${payment['amount']} coins',
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 14.0 : 12.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Status: ${payment['status']}',
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 14.0 : 12.0,
                                          color: isPending
                                              ? Colors.orange
                                              : Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: isPending
                                      ? ElevatedButton(
                                          onPressed: () => _approveTransaction(
                                            payment['transaction_id'],
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0,
                                              vertical: 6.0,
                                            ),
                                          ),
                                          child: const Text('Approve'),
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ))
              : Center(
                  child: Text(
                    'Access denied: Admin only',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
        },
      ),
    );
  }
}
