import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../blocs/tasks/task_bloc.dart';
import '../../blocs/tasks/task_state.dart';
import '../../core/folio_theme.dart';
import '../../models/task_model.dart';
import '../widgets/clay_widgets.dart';

/// A lightweight month-grid calendar for tasks with a deadline.
/// Only reachable via the calendar icon on the Task Manager screen -
/// the main task list is unaffected.
class TaskCalendarScreen extends StatefulWidget {
  const TaskCalendarScreen({super.key});

  @override
  State<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

class _TaskCalendarScreenState extends State<TaskCalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected = DateTime.now();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: BlocBuilder<TaskBloc, TaskState>(
          builder: (context, state) {
            final tasks = state is TaskLoaded ? state.tasks : <TaskItem>[];
            final withDeadline = tasks.where((t) => t.deadline != null).toList();

            final firstOfMonth = DateTime(_month.year, _month.month, 1);
            final daysInMonth =
                DateTime(_month.year, _month.month + 1, 0).day;
            final leadingBlanks = firstOfMonth.weekday % 7; // Sun=0..Sat=6

            List<TaskItem> tasksOn(DateTime day) =>
                withDeadline.where((t) => _sameDay(t.deadline!, day)).toList();

            final selectedTasks =
                _selected == null ? <TaskItem>[] : tasksOn(_selected!);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      ClayIconButton(
                        icon: Icons.arrow_back_rounded,
                        size: 42,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Calendar',
                            style: GoogleFonts.nunito(
                                color: theme.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClayBox(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left_rounded,
                                  color: theme.textSub),
                              onPressed: () => setState(() =>
                                  _month = DateTime(_month.year, _month.month - 1)),
                            ),
                            Text(DateFormat.yMMMM().format(_month),
                                style: GoogleFonts.nunito(
                                    color: theme.text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            IconButton(
                              icon: Icon(Icons.chevron_right_rounded,
                                  color: theme.textSub),
                              onPressed: () => setState(() =>
                                  _month = DateTime(_month.year, _month.month + 1)),
                            ),
                          ],
                        ),
                        Row(
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                              .map((d) => Expanded(
                                    child: Center(
                                      child: Text(d,
                                          style: TextStyle(
                                              color: theme.textSub,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11)),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7),
                          itemCount: leadingBlanks + daysInMonth,
                          itemBuilder: (_, i) {
                            if (i < leadingBlanks) return const SizedBox();
                            final day = i - leadingBlanks + 1;
                            final date =
                                DateTime(_month.year, _month.month, day);
                            final isSelected =
                                _selected != null && _sameDay(date, _selected!);
                            final isToday = _sameDay(date, DateTime.now());
                            final hasTasks = tasksOn(date).isNotEmpty;
                            final hasOverdue =
                                tasksOn(date).any((t) => t.isOverdue);

                            return GestureDetector(
                              onTap: () => setState(() => _selected = date),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? theme.accent : null,
                                    shape: BoxShape.circle,
                                    border: isToday && !isSelected
                                        ? Border.all(color: theme.accent, width: 1.4)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('$day',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : theme.text,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            )),
                                        if (hasTasks)
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? Colors.white
                                                  : hasOverdue
                                                      ? Colors.redAccent
                                                      : theme.accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: selectedTasks.isEmpty
                      ? Center(
                          child: Text(
                            _selected == null
                                ? 'Pick a day to see its tasks'
                                : 'No tasks due on this day',
                            style: TextStyle(
                                color: theme.textSub, fontWeight: FontWeight.w600),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: selectedTasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final t = selectedTasks[i];
                            return ClayBox(
                              borderRadius: 16,
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(
                                    t.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: t.isDone
                                        ? theme.accent
                                        : theme.textSub,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      t.description,
                                      style: TextStyle(
                                        color: theme.text,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        decoration: t.isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('h:mm a').format(t.deadline!),
                                    style: TextStyle(
                                      color: theme.textSub,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
