import 'package:chating_app/features/coins/payment_screen.dart';
import 'package:chating_app/features/coins/wallet_repo.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = WalletRepo();
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: t.colorScheme.surface,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth * 0.05; // Responsive padding

          return Center(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Balance Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: t.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<int>(
                            stream: repo.balance(),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }
                              if (snap.hasError) {
                                return Text(
                                  'Error: ${snap.error}',
                                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.error),
                                );
                              }
                              final bal = snap.data ?? 0;
                              return Text(
                                '$bal Coins',
                                style: t.textTheme.headlineSmall?.copyWith(
                                  color: t.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your current balance',
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Purchase Options
                  Text(
                    'Buy Coins with ETB',
                    style: t.textTheme.titleLarge?.copyWith(
                      color: t.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: purchaseOptions.length,
                      itemBuilder: (context, index) {
                        final option = purchaseOptions[index];
                        final coins = option['coins'] as int;
                        final price = option['price'] as int;
                        final basePrice = option['basePrice'] as int;
                        final discount = option['discount'] as int;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$coins Coins',
                                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (discount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: t.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$discount% OFF',
                                          style: t.textTheme.labelSmall?.copyWith(
                                            color: t.colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (discount > 0)
                                      Text(
                                        '$basePrice ETB',
                                        style: t.textTheme.bodyMedium?.copyWith(
                                          color: t.colorScheme.onSurfaceVariant,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    if (discount > 0) const SizedBox(width: 8),
                                    Text(
                                      '$price ETB',
                                      style: t.textTheme.bodyLarge?.copyWith(
                                        color: t.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      context.go('/wallet/payment', extra: {
                                        'coins': coins,
                                        'price': price,
                                        'repo': repo,
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      backgroundColor: t.colorScheme.primary,
                                      foregroundColor: t.colorScheme.onPrimary,
                                    ),
                                    child: const Text('Buy Now'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

const purchaseOptions = [
  {'coins': 50, 'price': 100, 'basePrice': 100, 'discount': 0},
  {'coins': 200, 'price': 350, 'basePrice': 400, 'discount': 12},
  {'coins': 500, 'price': 800, 'basePrice': 1000, 'discount': 20},
  {'coins': 1000, 'price': 1500, 'basePrice': 2000, 'discount': 25},
  {'coins': 2000, 'price': 2800, 'basePrice': 4000, 'discount': 30},
  {'coins': 5000, 'price': 6000, 'basePrice': 10000, 'discount': 40},
  {'coins': 10000, 'price': 10000, 'basePrice': 20000, 'discount': 50},
];