import 'package:flutter/material.dart';
import 'wallet_repo.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = WalletRepo();
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: Center(
        child: StreamBuilder<int>(
          stream: repo.balance(),
          builder: (context, snap) {
            final bal = snap.data ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Balance: $bal coins',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => repo.addCoins(50),
                      child: const Text('+50'),
                    ),
                    OutlinedButton(
                      onPressed: () => repo.addCoins(200),
                      child: const Text('+200'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
