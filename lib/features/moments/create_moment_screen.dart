import 'package:flutter/material.dart';
import 'moments_repo.dart';

class CreateMomentScreen extends StatefulWidget {
  const CreateMomentScreen({super.key});
  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> {
  final _url = TextEditingController();
  String type = 'image';
  final repo = MomentsRepo();
  final _caption = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Moment (link)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Media URL (Supabase Storage public/signed URL)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              value: type,
              items: const [
                DropdownMenuItem(value: 'image', child: Text('Image')),
                DropdownMenuItem(value: 'video', child: Text('Video')),
              ],
              onChanged: (v) => setState(() => type = (v ?? 'image')),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await repo.create(
                            mediaUrl: _url.text.trim(),
                            mediaType: type,
                            caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
                          );
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Failed: $e')));
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                             : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
