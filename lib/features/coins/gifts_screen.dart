import 'package:flutter/material.dart';
import 'gifts_repo.dart';

class GiftsScreen extends StatefulWidget {
  final String receiverId;
  const GiftsScreen({super.key, required this.receiverId});
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  final repo = GiftsRepo();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = repo.catalog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send a gift')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final g = items[i];
              return ListTile(
                title: Text(g['name']),
                subtitle: Text('${g['price_coins']} coins'),
                trailing: FilledButton(
                  onPressed: () async {
                    await repo.sendGift(
                      receiver: widget.receiverId,
                      giftId: g['id'] as int,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Send'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
