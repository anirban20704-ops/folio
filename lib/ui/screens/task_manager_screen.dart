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
import '../widgets/add_task_sheet.dart';
import '../widgets/neu_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasks());
  }

  @override
  void dispose() {
    _leftPopper.dispose();
    _rightPopper.dispose();
    super.dispose();
  }

  void _onToggle(TaskItem task, bool done) {
    final bloc = context.read<TaskBloc>();
    if (done) {
      HapticFeedback.mediumImpact();
      _leftPopper.play();
      _rightPopper.play();
      // small delay so the tick animation is visible before the card moves
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) bloc.add(ToggleTask(task.id!, true));
      });
    } else {
      bloc.add(ToggleTask(task.id!, false));
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
                            NeuIconButton(
                              icon: Icons.arrow_back_rounded,
                              size: 44,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text('Tasks',
                                  style: GoogleFonts.nunito(
                                      color: theme.text,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1)),
                            ),
                            NeuButton(
                              filled: true,
                              borderRadius: 20,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              onTap: _openAdd,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text('New',
                                      style: GoogleFonts.nunito(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  if (state is TaskError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(state.message,
                            style: TextStyle(color: theme.textSub)),
                      ),
                    )
                  else if (active.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: NeuBox(
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
                            NeuButton(
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
        backgroundColor: theme.bg,
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
          NeuButton(
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
