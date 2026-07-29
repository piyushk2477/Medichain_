import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:medichain_beta/services/api_client.dart';
import 'package:medichain_beta/services/supabase_service.dart';
import 'package:medichain_beta/screens/splash_screen.dart';
import 'package:medichain_beta/screens/auth/login_screen.dart';
import 'package:medichain_beta/screens/patient/patient_dashboard.dart';
import 'package:medichain_beta/screens/patient/upload_screen.dart';
import 'package:medichain_beta/screens/patient/records_screen.dart';
import 'package:medichain_beta/screens/patient/profile_screen.dart';
import 'package:medichain_beta/screens/doctor/doctor_dashboard_screen.dart';
import 'package:medichain_beta/widgets/private_route.dart';
import 'package:medichain_beta/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // Load any persisted auth token and try to restore the session so a returning
  // user lands straight on their dashboard (the splash screen re-checks too).
  await ApiClient.instance.loadTokens();
  await SupabaseService.restoreSession();
  runApp(const MedichainApp());
}

class MedichainApp extends StatelessWidget {
  const MedichainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medichain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/login': (_) => const LoginScreen(),
          '/patient/dashboard': (_) => const PrivateRoute(
            requiredRole: 'patient',
            child: PatientDashboard(),
          ),
          '/patient/upload': (_) => const PrivateRoute(
            requiredRole: 'patient',
            child: UploadScreen(),
          ),
          '/patient/records': (_) => const PrivateRoute(
            requiredRole: 'patient',
            child: RecordsScreen(),
          ),
          '/patient/profile': (_) => const PrivateRoute(
            requiredRole: 'patient',
            child: ProfileScreen(),
          ),
          '/doctor/dashboard': (_) => const PrivateRoute(
            requiredRole: 'doctor',
            child: DoctorDashboardScreen(),
          ),
        };

        final builder = routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(builder: builder, settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      },
    );
  }
}