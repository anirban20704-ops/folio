import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/tasks/task_bloc.dart';
import '../../blocs/tasks/task_event.dart';
import '../../core/folio_theme.dart';
import '../../services/date_parser.dart';
import '../../models/task_model.dart';
import '../../services/scanner_service.dart';
import '../../services/voice_note_service.dart';
import 'deadline_notify_field.dart';
import 'neu_widgets.dart';

class AddTaskSheet extends StatefulWidget {
  /// Pass an existing task to edit it in place; omit to create a new one.
  final TaskItem? existing;
  const AddTaskSheet({super.key, this.existing});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _controller = TextEditingController();
  final _voice = VoiceNoteService();
  final List<String> _images = [];
  bool _listening = false;
  String _baseText = '';
  DateTime? _deadline;
  bool _deadlineEditedManually = false;
  bool _isDaily = false;
  bool _notifyEnabled = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _controller.text = existing.description;
      _images.addAll(existing.imagePaths);
      _deadline = existing.deadline;
      _deadlineEditedManually = true; // don't let auto-detect override an edit
      _isDaily = existing.isDaily;
      _notifyEnabled = existing.notifyEnabled;
    }
    _controller.addListener(_detectDeadline);
  }

  void _detectDeadline() {
    if (_deadlineEditedManually || _isDaily) return;
    final found = DateParser.extract(_controller.text);
    if (found != _deadline) setState(() => _deadline = found);
  }

  void _toggleDaily(bool value) {
    setState(() {
      _isDaily = value;
      if (value) {
        _deadline = null;
        _deadlineEditedManually = true;
      }
    });
  }

  void _onDeadlineFieldChanged(DateTime? deadline, bool notify) {
    setState(() {
      _deadline = deadline;
      _notifyEnabled = notify;
      _deadlineEditedManually = true;
    });
  }

  @override
  void dispose() {
    _voice.stop();
    _controller.removeListener(_detectDeadline);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _voice.stop();
      setState(() => _listening = false);
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
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) return;
    final description = text.isEmpty ? 'Photo task' : text;

    final bloc = context.read<TaskBloc>();
    if (_isEditing) {
      bloc.add(UpdateTask(
        original: widget.existing!,
        description: description,
        finalImagePaths: List.of(_images),
        deadline: _deadline,
        isDaily: _isDaily,
        notifyEnabled: _notifyEnabled,
      ));
    } else {
      bloc.add(AddTask(
        description,
        List.of(_images),
        deadline: _deadline,
        isDaily: _isDaily,
        notifyEnabled: _notifyEnabled,
      ));
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
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
              Text(_isEditing ? 'Edit task' : 'New task',
                  style: GoogleFonts.nunito(
                      color: theme.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: theme.bg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: theme.insetShadow,
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                  decoration: InputDecoration(
                    hintText: _listening
                        ? 'Listening...'
                        : 'Type, or tap the mic and speak',
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_images[i]),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              cacheWidth: 180),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  NeuIconButton(
                      icon: Icons.photo_camera_outlined,
                      onTap: _pickCamera,
                      size: 46,
                      tooltip: 'Camera'),
                  const SizedBox(width: 12),
                  NeuIconButton(
                      icon: Icons.photo_library_outlined,
                      onTap: _pickGallery,
                      size: 46,
                      tooltip: 'Gallery'),
                  const SizedBox(width: 12),
                  NeuIconButton(
                      icon: _listening
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded,
                      active: _listening,
                      onTap: _toggleMic,
                      size: 46,
                      tooltip: 'Voice note'),
                  const Spacer(),
                  NeuButton(
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
          ),
        ),
      ),
    );
  }
}
