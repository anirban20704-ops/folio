import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/tasks/task_bloc.dart';
import '../../blocs/tasks/task_event.dart';
import '../../blocs/tasks/task_state.dart';
import '../../core/folio_theme.dart';
import '../../models/task_model.dart';
import 'task_calendar_screen.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/task_card.dart';

class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  final _leftPopper = ConfettiController(duration: const Duration(seconds: 1));
  final _rightPopper = ConfettiController(duration: const Duration(seconds: 1));
  bool _showCompleted = false;
  late final TaskBloc _bloc;
  // Tasks ticked but not yet saved (waiting for the tick animation to play).
  final Set<int> _pendingDone = {};

  @override
  void initState() {
    super.initState();
    _bloc = context.read<TaskBloc>()..add(LoadTasks());
  }

  @override
  void dispose() {
    // Never lose a completion if the user leaves during the animation delay.
    for (final id in _pendingDone) {
      _bloc.add(ToggleTask(id, true));
    }
    _pendingDone.clear();
    _leftPopper.dispose();
    _rightPopper.dispose();
    super.dispose();
  }

  void _onToggle(TaskItem task, bool done) {
    final id = task.id!;
    if (done) {
      HapticFeedback.mediumImpact();
      _leftPopper.play();
      _rightPopper.play();
      _pendingDone.add(id);
      // small delay so the tick animation is visible before the card moves
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_pendingDone.remove(id)) _bloc.add(ToggleTask(id, true));
      });
    } else {
      // Un-ticked before it was saved: nothing to write, DB still says "not done".
      if (_pendingDone.remove(id)) return;
      _bloc.add(ToggleTask(id, false));
    }
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTaskSheet(),
    );
  }

  Widget _popper(Alignment align, ConfettiController c, double direction) {
    final theme = context.read<FolioThemeNotifier>();
    return Align(
      alignment: align,
      child: ConfettiWidget(
        confettiController: c,
        blastDirectionality: BlastDirectionality.directional,
        blastDirection: direction,
        emissionFrequency: 0.06,
        numberOfParticles: 14,
        maxBlastForce: 32,
        minBlastForce: 14,
        gravity: 0.25,
        colors: [
          theme.accent,
          theme.accentSoft,
          Colors.amber,
          Colors.pinkAccent,
          Colors.teal,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return Scaffold(
      backgroundColor: theme.bg,
      body: Stack(
        children: [
          BlocBuilder<TaskBloc, TaskState>(
            builder: (context, state) {
              final loaded = state is TaskLoaded ? state : null;
              final daily = loaded?.daily ?? const <TaskItem>[];
              final active = loaded?.active ?? const <TaskItem>[];
              final done = loaded?.completed ?? const <TaskItem>[];

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Row(
                          children: [
                            ClayIconButton(
                              icon: Icons.arrow_back_rounded,
                              size: 44,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: TasksTitle(size: 32),
                              ),
                            ),
                            ClayIconButton(
                              icon: Icons.calendar_month_rounded,
                              size: 44,
                              tooltip: 'Calendar',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const TaskCalendarScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ClayIconButton(
                              icon: Icons.add_rounded,
                              filled: true,
                              size: 44,
                              tooltip: 'New task',
                              onTap: _openAdd,
                            ),
                            const SizedBox(width: 10),
                            // Same spot as on the dashboard
                            const ClayThemeToggle(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  if (daily.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                        child: Row(
                          children: [
                            Icon(Icons.repeat_rounded,
                                size: 16, color: theme.accent),
                            const SizedBox(width: 6),
                            Text('Everyday',
                                style: GoogleFonts.nunito(
                                    color: theme.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList.separated(
                        itemCount: daily.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => TaskCard(
                          key: ValueKey('d_${daily[i].id}'),
                          task: daily[i],
                          onToggle: (d) => _onToggle(daily[i], d),
                          onDelete: () => context
                              .read<TaskBloc>()
                              .add(DeleteTask(daily[i].id!)),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                  if (state is TaskError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(state.message,
                            style: TextStyle(color: theme.textSub)),
                      ),
                    )
                  else if (active.isEmpty && daily.isEmpty && done.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ClayBox(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.checklist_rounded,
                                  size: 56,
                                  color: theme.textSub.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                  done.isEmpty
                                      ? 'No tasks yet'
                                      : 'All caught up!',
                                  style: TextStyle(
                                      color: theme.text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Tap New to add one',
                                  style: TextStyle(
                                      color: theme.textSub,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList.separated(
                        itemCount: active.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => TaskCard(
                          key: ValueKey('a_${active[i].id}'),
                          task: active[i],
                          onToggle: (d) => _onToggle(active[i], d),
                          onDelete: () => context
                              .read<TaskBloc>()
                              .add(DeleteTask(active[i].id!)),
                        ),
                      ),
                    ),
                  if (done.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(
                                    () => _showCompleted = !_showCompleted),
                                child: Row(
                                  children: [
                                    Text('Completed',
                                        style: GoogleFonts.nunito(
                                            color: theme.text,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: theme.accentSoft,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text('${done.length}',
                                          style: TextStyle(
                                              color: theme.accent,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12)),
                                    ),
                                    const SizedBox(width: 4),
                                    AnimatedRotation(
                                      turns: _showCompleted ? 0.5 : 0,
                                      duration:
                                          const Duration(milliseconds: 250),
                                      child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: theme.textSub),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ClayButton(
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              onTap: () => _confirmClear(done.length),
                              child: Text('Clear',
                                  style: GoogleFonts.nunito(
                                      color: theme.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _showCompleted
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  children: [
                                    for (final t in done)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: TaskCard(
                                          key: ValueKey('c_${t.id}'),
                                          task: t,
                                          onToggle: (d) => _onToggle(t, d),
                                          onDelete: () => context
                                              .read<TaskBloc>()
                                              .add(DeleteTask(t.id!)),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          ),
          IgnorePointer(
            child: Stack(children: [
              _popper(Alignment.bottomLeft, _leftPopper, -math.pi / 3),
              _popper(Alignment.bottomRight, _rightPopper, -2 * math.pi / 3),
            ]),
          ),
        ],
      ),
    );
  }

  void _confirmClear(int count) {
    final theme = context.read<FolioThemeNotifier>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Clear completed?',
            style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
        content: Text(
            'This permanently deletes $count completed task${count == 1 ? '' : 's'} and their images.',
            style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: theme.textSub, fontWeight: FontWeight.w700)),
          ),
          ClayButton(
            filled: true,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            onTap: () {
              context.read<TaskBloc>().add(ClearCompleted());
              Navigator.pop(ctx);
            },
            child: Text('Clear',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
