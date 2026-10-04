import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/folio_theme.dart';
import '../../models/task_model.dart';
import 'package:intl/intl.dart';
import 'add_task_sheet.dart';
import 'neu_widgets.dart';

class TaskCard extends StatefulWidget {
  final TaskItem task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late bool _done = widget.task.isDone;

  @override
  void didUpdateWidget(covariant TaskCard old) {
    super.didUpdateWidget(old);
    if (old.task.isDone != widget.task.isDone) _done = widget.task.isDone;
  }

  void _flip() {
    setState(() => _done = !_done);
    widget.onToggle(_done);
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(existing: widget.task),
    );
  }

  void _openImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          child: Center(child: Image.file(File(path))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final task = widget.task;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Right swipe: tick/untick in place, never remove the card.
          _flip();
          return false;
        }
        return _confirmDelete(context, theme);
      },
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.check_circle_outline_rounded,
            color: Colors.green, size: 26),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
      ),
      child: GestureDetector(
        onDoubleTap: () => _openEdit(context),
        child: NeuBox(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.imagePaths.isNotEmpty) ...[
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: task.imagePaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openImage(context, task.imagePaths[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(task.imagePaths[i]),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: theme.accentSoft,
                          child: Icon(Icons.broken_image_outlined,
                              color: theme.textSub),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _flip,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _done ? theme.accent : theme.bg,
                      borderRadius: BorderRadius.circular(9),
                      border: _done
                          ? null
                          : Border.all(
                              color: theme.textSub.withValues(alpha: 0.55),
                              width: 1.6,
                            ),
                      boxShadow:
                          _done ? theme.pressedShadow : theme.subtleShadow,
                    ),
                    child: AnimatedScale(
                      scale: _done ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: GoogleFonts.nunito(
                          color: _done ? theme.textSub : theme.text,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          decoration: _done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: theme.textSub,
                        ),
                        child: Text(task.description),
                      ),
                      if (task.isDaily) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.accentSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.repeat_rounded,
                                  size: 12, color: theme.accent),
                              const SizedBox(width: 4),
                              Text('Everyday',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: theme.accent)),
                            ],
                          ),
                        ),
                      ],
                      if (task.deadline != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: task.isOverdue
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : theme.accentSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_rounded,
                                  size: 12,
                                  color: task.isOverdue
                                      ? Colors.redAccent
                                      : theme.accent),
                              const SizedBox(width: 4),
                              Text(
                                task.isDaily
                                    ? DateFormat('h:mm a').format(task.deadline!)
                                    : DateFormat('MMM d, h:mm a')
                                        .format(task.deadline!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: task.isOverdue
                                      ? Colors.redAccent
                                      : theme.accent,
                                ),
                              ),
                              if (task.notifyEnabled) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.notifications_rounded,
                                    size: 11,
                                    color: task.isOverdue
                                        ? Colors.redAccent
                                        : theme.accent),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, FolioThemeNotifier theme) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Task?',
            style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
        content: Text(
          'Delete "${widget.task.description}"? This cannot be undone.',
          style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
