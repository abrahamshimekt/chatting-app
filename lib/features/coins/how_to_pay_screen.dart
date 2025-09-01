import 'package:flutter/material.dart';

class HowToPayScreen extends StatelessWidget {
  final String method;
  final int price;
  final String cbeReceiver;
  final String telebirrReceiver;

  const HowToPayScreen({
    super.key,
    required this.method,
    required this.price,
    required this.cbeReceiver,
    required this.telebirrReceiver,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Pay'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: t.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth * 0.05;

          return Padding(
            padding: EdgeInsets.all(padding),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    method == 'CBE' ? 'How to Pay with CBE' : 'How to Pay with TeleBirr',
                    style: t.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: t.colorScheme.onSurface,
                      fontSize: isWide ? 24 : 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method == 'CBE'
                              ? '1. Open CBE Birr app\n2. Select "Send Money"\n3. Enter account $cbeReceiver\n4. Input $price ETB\n5. Confirm and note transaction ID'
                              : '1. Open TeleBirr app\n2. Select "Send Money"\n3. Enter phone $telebirrReceiver\n4. Input $price ETB\n5. Confirm and note transaction ID',
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}