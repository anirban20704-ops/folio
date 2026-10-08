import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/folio_theme.dart';

/// Shared "set a deadline, optionally get reminded" control, used by tasks
/// (one-off and everyday) and by documents. Deadline is always optional;
/// the notification toggle is only enabled once a deadline (or, in
/// [timeOnlyMode], a time) has actually been set.
class DeadlineNotifyField extends StatefulWidget {
  final DateTime? initialDeadline;
  final bool initialNotifyEnabled;

  /// For everyday tasks: only a time of day is meaningful (it repeats
  /// every day), so the date picker step is skipped - [onChanged] still
  /// receives a full DateTime, with today's date and the chosen time.
  final bool timeOnlyMode;

  final void Function(DateTime? deadline, bool notifyEnabled) onChanged;

  const DeadlineNotifyField({
    super.key,
    required this.initialDeadline,
    required this.initialNotifyEnabled,
    required this.onChanged,
    this.timeOnlyMode = false,
  });

  @override
  State<DeadlineNotifyField> createState() => _DeadlineNotifyFieldState();
}

class _DeadlineNotifyFieldState extends State<DeadlineNotifyField> {
  late DateTime? _deadline = widget.initialDeadline;
  late bool _notify = widget.initialNotifyEnabled && _deadline != null;

  void _emit() => widget.onChanged(_deadline, _notify);

  Future<void> _pick() async {
    final now = DateTime.now();
    DateTime? datePart = _deadline;

    if (!widget.timeOnlyMode) {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: _deadline ?? now,
        firstDate: now.subtract(const Duration(days: 1)),
        lastDate: now.add(const Duration(days: 365 * 3)),
      );
      if (pickedDate == null || !mounted) return;
      datePart = pickedDate;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _deadline != null
          ? TimeOfDay(hour: _deadline!.hour, minute: _deadline!.minute)
          : const TimeOfDay(hour: 18, minute: 0),
      helpText:
          widget.timeOnlyMode ? 'Remind me every day at' : 'Reminder time (optional)',
    );
    if (!mounted) return;

    final base = datePart ?? now;
    final time = pickedTime ?? const TimeOfDay(hour: 18, minute: 0);
    setState(() {
      _deadline = DateTime(base.year, base.month, base.day, time.hour, time.minute);
    });
    _emit();
  }

  void _clear() {
    setState(() {
      _deadline = null;
      _notify = false;
    });
    _emit();
  }

  void _toggleNotify(bool value) {
    if (_deadline == null) return; // guarded by the switch being disabled too
    setState(() => _notify = value);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final label = _deadline == null
        ? (widget.timeOnlyMode ? 'Set a daily reminder time' : 'Add a deadline')
        : (widget.timeOnlyMode
            ? DateFormat('h:mm a').format(_deadline!)
            : DateFormat('MMM d, h:mm a').format(_deadline!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _deadline == null ? theme.cardBg : theme.accentSoft,
              borderRadius: BorderRadius.circular(10),
              boxShadow: _deadline == null ? theme.subtleShadow : null,
              border: _deadline == null
                  ? Border.all(color: theme.textSub.withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.timeOnlyMode ? Icons.access_time_rounded : Icons.event_rounded,
                  size: 15,
                  color: _deadline == null ? theme.textSub : theme.accent,
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _deadline == null ? theme.textSub : theme.accent,
                    )),
                if (_deadline != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _clear,
                    child: Icon(Icons.close_rounded, size: 14, color: theme.accent),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.notifications_outlined,
                size: 17,
                color: _deadline == null
                    ? theme.textSub.withValues(alpha: 0.4)
                    : (_notify ? theme.accent : theme.textSub)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _deadline == null ? 'Set a time to enable reminders' : 'Remind me',
                style: TextStyle(
                  color: _deadline == null ? theme.textSub.withValues(alpha: 0.6) : theme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Switch.adaptive(
              value: _notify,
              activeThumbColor: theme.accent,
              // Disabled (greyed, non-interactive) until a deadline/time is set.
              onChanged: _deadline == null ? null : _toggleNotify,
            ),
          ],
        ),
      ],
    );
  }
}
