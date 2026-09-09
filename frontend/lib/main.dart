import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/farm_provider.dart';
import 'core/providers/evidence_provider.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/sync_provider.dart';

// Screens
import 'screens/1_splash_screen.dart';
import 'screens/3_profile_selection_screen.dart';
import 'screens/farmer_auth_screen.dart';
import 'screens/4_farmer_dashboard_screen.dart';
import 'screens/field_agent_dashboard_screen.dart';

import 'screens/5_voice_log_screen.dart';
import 'screens/6_crop_camera_screen.dart';
import 'screens/7_scan_product_screen.dart';
import 'screens/new_observation_screen.dart';
import 'screens/new_application_screen.dart';
import 'screens/8_evidence_review_screen.dart';
import 'screens/evidence_detail_screen.dart';
import 'screens/evidence_report_screen.dart';
import 'screens/efficacy_insights_screen.dart';
import 'screens/agronomy_suite_screen.dart';
import 'screens/product_intelligence_screen.dart';
import 'screens/buyer_pricing_screen.dart';
import 'screens/ask_pramaan_screen.dart';
import 'screens/9_season_journal_screen.dart';
import 'screens/field_map_screen.dart';
import 'screens/sync_center_screen.dart';
import 'screens/learning_loop_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/trust_validation_screen.dart';
import 'screens/community_logs_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FarmProvider()),
        ChangeNotifierProvider(create: (_) => EvidenceProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: const PramaanApp(),
    ),
  );
}

class PramaanApp extends StatelessWidget {
  const PramaanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'Pramaan AgTech',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: auth.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/profile_selection': (context) => const ProfileSelectionScreen(),
        '/farmer_auth': (context) => const FarmerAuthScreen(),
        '/farmer_dashboard': (context) => const FarmerDashboardScreen(),

        '/field_agent_dashboard': (context) => const FieldAgentDashboardScreen(),
        '/voice_log': (context) => const VoiceLogScreen(),
        '/crop_camera': (context) => const CropCameraScreen(),
        '/scan_product': (context) => const ScanProductScreen(),
        '/new_observation': (context) => const NewObservationScreen(),
        '/new_application': (context) => const NewApplicationScreen(),
        '/evidence_review': (context) => const EvidenceReviewScreen(),
        '/evidence_detail': (context) => const EvidenceDetailScreen(),
        '/evidence_report': (context) => const EvidenceReportScreen(),
        '/efficacy_insights': (context) => const EfficacyInsightsScreen(),
        '/agronomy_suite': (context) => const AgronomySuiteScreen(),
        '/product_intelligence': (context) => const ProductIntelligenceScreen(),
        '/buyer_pricing': (context) => const BuyerPricingScreen(),
        '/ask_pramaan': (context) => const AskPramaanScreen(),
        '/season_journal': (context) => const SeasonJournalScreen(),
        '/field_map': (context) => const FieldMapScreen(),
        '/sync_center': (context) => const SyncCenterScreen(),
        '/learning_loop': (context) => const LearningLoopScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/trust_validation': (context) => const TrustValidationScreen(),
        '/community_logs': (context) => const CommunityLogsScreen(),
      },
    );
  }
}
