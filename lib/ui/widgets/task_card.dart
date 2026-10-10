import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/folio_theme.dart';
import '../../models/task_model.dart';
import 'package:intl/intl.dart';
import 'add_task_sheet.dart';
import 'clay_widgets.dart';
import 'image_viewer.dart';

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

  void _showDetails(BuildContext context) {
    final theme = context.read<FolioThemeNotifier>();
    final task = widget.task;
    final hasDetails = task.details.trim().isNotEmpty;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: ClayBox(
          borderRadius: 32,
          depth: ClayDepth.lg,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      task.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: task.isDone ? theme.accent : theme.textSub,
                    ),
                    const SizedBox(width: 8),
                    Text(task.isDone ? 'Done' : 'To do',
                        style: GoogleFonts.nunito(
                            color: theme.textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(task.description,
                    style: GoogleFonts.nunito(
                        color: theme.text,
                        fontSize: 21,
                        height: 1.25,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: hasDetails
                        ? Text(task.details,
                            style: GoogleFonts.nunito(
                                color: theme.text,
                                fontSize: 15,
                                height: 1.5,
                                fontWeight: FontWeight.w600))
                        : Text('No description added.',
                            style: GoogleFonts.nunito(
                                color: theme.textSub,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                if (task.deadline != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.event_rounded,
                          size: 15,
                          color: task.isOverdue
                              ? Colors.redAccent
                              : theme.accent),
                      const SizedBox(width: 6),
                      Text(
                        task.isDaily
                            ? 'Every day, ${DateFormat('h:mm a').format(task.deadline!)}'
                            : DateFormat('EEE, MMM d · h:mm a')
                                .format(task.deadline!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: task.isOverdue
                              ? Colors.redAccent
                              : theme.accent,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ClayButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openEdit(context);
                      },
                      child: Text('Edit',
                          style: GoogleFonts.nunito(
                              color: theme.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                    const SizedBox(width: 10),
                    ClayButton(
                      filled: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      onTap: () => Navigator.pop(ctx),
                      child: Text('Close',
                          style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openImage(BuildContext context, int index) {
    showImageViewer(context,
        paths: widget.task.imagePaths, initialIndex: index);
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
        onTap: () => _showDetails(context),
        onDoubleTap: () => _openEdit(context),
        child: ClayBox(
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
                    onTap: () => _openImage(context, i),
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
                      color: _done ? theme.accent : theme.cardBg,
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
        backgroundColor: theme.cardBg,
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
