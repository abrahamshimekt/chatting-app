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
          id: widget.existing!.id,
          text: _txt.text,
          newMedia: _picked,
          authorId: widget.authorId,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing == null ? 'Moment created!' : 'Moment updated!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: isSmallScreen ? 16 : screenWidth * 0.05,
        right: isSmallScreen ? 16 : screenWidth * 0.05,
        top: 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Edit Moment' : 'New Moment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _txt,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Say something…',
                hintText: 'What’s on your mind?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(false),
                    icon: const Icon(Icons.photo, size: 25),
                    label: const Text('Photo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: theme.colorScheme.primary),
                      textStyle: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(true),
                    icon: const Icon(Icons.videocam, size: 25),
                    label: const Text('Video'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: theme.colorScheme.primary),
                      textStyle: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check, size: 25),
                    label: Text(isEditing ? 'Save' : 'Post'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            if (_picked != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected: ${_picked!.path.split('/').last}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _picked = null),
                    icon: Icon(Icons.close, size: 20, color: theme.colorScheme.error),
                    tooltip: 'Remove media',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}