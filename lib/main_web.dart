import 'package:beresheet_app/screen/web/web_homepage.dart';
import 'package:beresheet_app/screen/web/web_management_panel.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: WebApp()));
}

class WebApp extends StatelessWidget {
  const WebApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'בראשית - קהילת מגורים',
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const WebHomePage(),
        '/manage': (context) => const WebManagementPanel(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const WebHomePage(),
        );
      },
    );
  }
}