import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'blocs/dashboard/dashboard_bloc.dart';
import 'blocs/dashboard/dashboard_event.dart';
import 'blocs/scanner/scanner_bloc.dart';
import 'repositories/document_repository.dart';
import 'services/scanner_service.dart';
import 'ui/screens/dashboard_screen.dart';
import 'core/folio_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FolioApp());
}

class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository   = DocumentRepository();
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
        ],
        child: Consumer<FolioThemeNotifier>(
          builder: (context, theme, _) => MaterialApp(
            title: 'Folio',
            debugShowCheckedModeBanner: false,
            theme: theme.themeData,          // auto-switches day ↔ night
            home: const DashboardScreen(),
          ),
        ),
      ),
    );
  }
}