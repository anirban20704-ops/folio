import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'blocs/dashboard/dashboard_bloc.dart';
import 'blocs/dashboard/dashboard_event.dart';
import 'blocs/scanner/scanner_bloc.dart';
import 'blocs/tasks/task_bloc.dart';
import 'blocs/tasks/task_event.dart';
import 'repositories/task_repository.dart';
import 'repositories/document_repository.dart';
import 'services/scanner_service.dart';
import 'ui/screens/splash_screen.dart';
import 'core/folio_theme.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the animated loading screen straight away; notification setup
  // (timezone lookup etc.) used to run first and kept the screen black.
  runApp(const FolioApp());
  // Notification set-up is heavy; do it well after the first frames.
  // (It also initialises on demand the first time a reminder is scheduled.)
  unawaited(Future.delayed(
      const Duration(seconds: 6), NotificationService.instance.init));
}

class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository   = DocumentRepository();
    final taskRepo     = TaskRepository();
    final scannerSvc   = ScannerService();
    final themeNotifier = FolioThemeNotifier();   // ← NEW

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FolioThemeNotifier>.value(value: themeNotifier),

        Provider<ScannerService>.value(value: scannerSvc),
        Provider<DocumentRepository>.value(value: repository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => DashboardBloc(repository: repository)
              ..add(LoadDashboard()),
          ),
          BlocProvider(
            create: (_) => ScannerBloc(
              scannerService: scannerSvc,
              repository: repository,
            ),
          ),
          BlocProvider(
            create: (_) => TaskBloc(repository: taskRepo)..add(LoadTasks()),
          ),
        ],
        child: Consumer<FolioThemeNotifier>(
          builder: (context, theme, _) => MaterialApp(
            title: 'Folio',
            debugShowCheckedModeBanner: false,
            theme: theme.themeData,          // auto-switches day ↔ night
            // Respect the user's font size, but cap it so layouts stay usable
            // (without a cap, "largest" fonts overflow every screen).
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler
                      .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35),
                ),
                child: child!,
              );
            },
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}