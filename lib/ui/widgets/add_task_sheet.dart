import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/tasks/task_bloc.dart';
import '../../blocs/tasks/task_event.dart';
import '../../core/folio_theme.dart';
import '../../models/task_model.dart';
import '../../services/scanner_service.dart';
import '../../services/voice_note_service.dart';
import 'deadline_notify_field.dart';
import 'clay_widgets.dart';
import 'image_viewer.dart';

class AddTaskSheet extends StatefulWidget {
  /// Pass an existing task to edit it in place; omit to create a new one.
  final TaskItem? existing;
  const AddTaskSheet({super.key, this.existing});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _controller = TextEditingController();
  final _detailsController = TextEditingController();
  final _voice = VoiceNoteService();
  final List<String> _images = [];
  bool _listening = false;
  String _baseText = '';
  DateTime? _deadline;
  Timer? _micWatch;
  bool _isDaily = false;
  bool _notifyEnabled = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _controller.text = existing.description;
      _detailsController.text = existing.details;
      _images.addAll(existing.imagePaths);
      _deadline = existing.deadline;
      _isDaily = existing.isDaily;
      _notifyEnabled = existing.notifyEnabled;
    }
  }

  void _toggleDaily(bool value) {
    setState(() {
      _isDaily = value;
      if (value) {
        _deadline = null;
      }
    });
  }

  void _onDeadlineFieldChanged(DateTime? deadline, bool notify) {
    setState(() {
      _deadline = deadline;
      _notifyEnabled = notify;
    });
  }

  @override
  void dispose() {
    _micWatch?.cancel();
    _voice.stop();
    _controller.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      _micWatch?.cancel();
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _voice.init(onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && mounted) {
        setState(() => _listening = false);
      }
    });
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_voice.lastError ??
              'Speech recognition unavailable. Check mic permission.')));
      return;
    }
    _baseText = _controller.text.trim();
    setState(() => _listening = true);
    // The phone's recogniser switches itself off after silence / a time limit.
    // Watch for that and flip the mic button back, instead of trusting a
    // status callback that goes stale once the first sheet is closed.
    final startedAt = DateTime.now();
    _micWatch?.cancel();
    _micWatch = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final grace = DateTime.now().difference(startedAt).inMilliseconds < 2500;
      if (_listening && !grace && !_voice.isListening) {
        t.cancel();
        setState(() => _listening = false);
      }
    });
    await _voice.start((words, isFinal) {
      if (!mounted) return;
      final joined = _baseText.isEmpty ? words : '$_baseText $words';
      if (isFinal) {
        // Commit this chunk into _baseText so a LATER chunk in the same
        // listening session appends after it instead of replacing it.
        // (speech_to_text can finalise more than once per session if you
        // pause briefly - without this, the next chunk wiped everything
        // said before it, which is why words like "tomorrow" spoken after
        // a short pause could vanish along with the rest of the sentence.)
        _baseText = VoiceNoteService.tidy(joined);
        _controller.text = _baseText;
      } else {
        _controller.text = joined;
      }
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  Future<void> _pickCamera() async {
    final f = await context.read<ScannerService>().pickImageFromCamera();
    if (f != null && mounted) setState(() => _images.add(f.path));
  }

  Future<void> _pickGallery() async {
    final files = await context.read<ScannerService>().pickImages();
    if (files.isNotEmpty && mounted) {
      setState(() => _images.addAll(files.map((f) => f.path)));
    }
  }

  void _save() {
    _micWatch?.cancel();
    _voice.stop();
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) return;
    final description = text.isEmpty ? 'Photo task' : text;
    final details = _detailsController.text.trim();

    final bloc = context.read<TaskBloc>();
    if (_isEditing) {
      bloc.add(UpdateTask(
        original: widget.existing!,
        description: description,
        finalImagePaths: List.of(_images),
        deadline: _deadline,
        isDaily: _isDaily,
        notifyEnabled: _notifyEnabled,
        details: details,
      ));
    } else {
      bloc.add(AddTask(
        description,
        List.of(_images),
        deadline: _deadline,
        isDaily: _isDaily,
        notifyEnabled: _notifyEnabled,
        details: details,
      ));
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final media = MediaQuery.of(context);
    // Short screens (landscape, or keyboard open): scroll the WHOLE sheet
    // so the form never collapses to nothing.
    final compact = media.size.height - media.viewInsets.bottom < 480;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      // Cap the height to what's left above the keyboard so the form scrolls
      // instead of overflowing (the yellow/black hatched bar).
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.viewInsets.bottom - media.padding.top - 8,
        ),
        child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: theme.darkShadow.withValues(alpha: theme.isDark ? 0.6 : 0.3),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: _outerWrap(compact, Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSub.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AccentTitle(
                  text: _isEditing ? 'Edit task' : 'New task',
                  accent: 'k',
                  size: 26),
              const SizedBox(height: 16),
              _formWrap(compact, Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              ClayInset(borderRadius: 16, child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                  decoration: InputDecoration(
                    hintText: _listening
                        ? 'Listening...'
                        : 'Task title — type, or tap the mic',
                    hintStyle: TextStyle(color: theme.textSub),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClayInset(
                borderRadius: 16,
                child: TextField(
                  controller: _detailsController,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Description (optional) — shown when you tap the task',
                    hintStyle: TextStyle(color: theme.textSub),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () => showImageViewer(context,
                              paths: _images, initialIndex: i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(_images[i]),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                cacheWidth: 180),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: theme.accent, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.repeat_rounded,
                      size: 17,
                      color: _isDaily ? theme.accent : theme.textSub),
                  const SizedBox(width: 8),
                  Text('Repeat every day',
                      style: TextStyle(
                          color: theme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const Spacer(),
                  Switch.adaptive(
                    value: _isDaily,
                    activeThumbColor: theme.accent,
                    onChanged: _toggleDaily,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              DeadlineNotifyField(
                key: ValueKey('deadline_field_$_isDaily'),
                initialDeadline: _deadline,
                initialNotifyEnabled: _notifyEnabled,
                timeOnlyMode: _isDaily,
                onChanged: _onDeadlineFieldChanged,
              ),
                    ],
              )),
              const SizedBox(height: 14),
              Row(
                children: [
                  ClayIconButton(
                      icon: Icons.photo_camera_outlined,
                      onTap: _pickCamera,
                      size: 46,
                      tooltip: 'Camera'),
                  const SizedBox(width: 12),
                  ClayIconButton(
                      icon: Icons.photo_library_outlined,
                      onTap: _pickGallery,
                      size: 46,
                      tooltip: 'Gallery'),
                  const SizedBox(width: 12),
                  ClayIconButton(
                      icon: _listening
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded,
                      active: _listening,
                      onTap: _toggleMic,
                      size: 46,
                      tooltip: 'Voice note'),
                  const Spacer(),
                  ClayButton(
                    filled: true,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    onTap: _save,
                    child: Text(_isEditing ? 'Save' : 'Add',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                ],
              ),
            ],
          )),
        ),
        ),
      ),
    );
  }

  Widget _outerWrap(bool compact, Widget child) => compact
      ? SingleChildScrollView(
          physics: const BouncingScrollPhysics(), child: child)
      : child;

  Widget _formWrap(bool compact, Widget child) => compact
      ? child
      : Flexible(
          child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(), child: child));
}
