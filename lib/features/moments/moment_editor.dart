import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'moments_repo.dart';
import 'moment_model.dart';

class MomentEditor extends StatefulWidget {
  final MomentsRepo repo;
  final String authorId;
  final Moment? existing;
  const MomentEditor({super.key, required this.repo, required this.authorId, this.existing});

  @override
  State<MomentEditor> createState() => _MomentEditorState();
}

class _MomentEditorState extends State<MomentEditor> {
  final _txt = TextEditingController();
  File? _picked;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _txt.text = widget.existing?.text ?? '';
  }

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isVideo) async {
    final picker = ImagePicker();
    final XFile? x = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x != null) setState(() => _picked = File(x.path));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (widget.existing == null) {
        await widget.repo.createMoment(
          authorId: widget.authorId,
          text: _txt.text.trim().isEmpty ? null : _txt.text.trim(),
          media: _picked,
        );
      } else {
        await widget.repo.updateMoment(
          id: widget.existing!.id,  // UUID now
          text: _txt.text,
          newMedia: _picked,
          authorId: widget.authorId,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEditing ? 'Edit moment' : 'New moment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _txt,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Say something…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(false),
                  icon: const Icon(Icons.photo),
                  label: const Text('Add photo'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(true),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Add video'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(isEditing ? 'Save' : 'Post'),
                ),
              ],
            ),
            if (_picked != null) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Selected: ${_picked!.path.split('/').last}')),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
