import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../blocs/tasks/task_bloc.dart';
import '../../blocs/tasks/task_event.dart';
import '../../core/folio_theme.dart';
import '../../services/date_parser.dart';
import '../../services/scanner_service.dart';
import '../../services/voice_note_service.dart';
import 'neu_widgets.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_detectDeadline);
  }

  void _detectDeadline() {
    if (_deadlineEditedManually) return; // user already set/cleared it by hand
    final found = DateParser.extract(_controller.text);
    if (found != _deadline) setState(() => _deadline = found);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59);
        _deadlineEditedManually = true;
      });
    }
  }

  void _clearDeadline() {
    setState(() {
      _deadline = null;
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
      _controller.text = isFinal ? VoiceNoteService.tidy(joined) : joined;
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
    context.read<TaskBloc>().add(AddTask(
          text.isEmpty ? 'Photo task' : text,
          List.of(_images),
          deadline: _deadline,
        ));
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
              Text('New task',
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
              GestureDetector(
                onTap: _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _deadline == null ? theme.bg : theme.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _deadline == null ? theme.subtleShadow : null,
                    border: _deadline == null
                        ? Border.all(color: theme.textSub.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_rounded,
                          size: 15,
                          color: _deadline == null ? theme.textSub : theme.accent),
                      const SizedBox(width: 6),
                      Text(
                        _deadline == null
                            ? 'Add a deadline'
                            : DateFormat.yMMMd().format(_deadline!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _deadline == null ? theme.textSub : theme.accent,
                        ),
                      ),
                      if (_deadline != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _clearDeadline,
                          child: Icon(Icons.close_rounded,
                              size: 14, color: theme.accent),
                        ),
                      ],
                    ],
                  ),
                ),
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
                    child: Text('Add',
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
