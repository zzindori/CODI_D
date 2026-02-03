import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/gemini_service.dart';
import 'services/config_service.dart';
import 'providers/avatar_provider.dart';
import 'providers/wardrobe_provider.dart';
import 'screens/setup/mannequin_selection_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/evolve/evolve_screen.dart';
import 'screens/wardrobe/wardrobe_screen.dart';
import 'screens/codi/codi_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ConfigService 초기화 (헌법 준수: 모든 표현 데이터 JSON 로드)
  await ConfigService.instance.initialize(locale: 'ko');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Gemini API 키 - 환경 변수나 .env 파일로 관리 필요
    const geminiApiKey = String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );

    final storageService = StorageService();
    final geminiService = GeminiService(apiKey: geminiApiKey);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AvatarProvider(
            storage: storageService,
            gemini: geminiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WardrobeProvider(
            storage: storageService,
            gemini: geminiService,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: ConfigService.instance.getString('strings.app_name'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AppInitializer(),
        routes: {
          '/setup': (context) => const MannequinSelectionScreen(),
          '/home': (context) => const HomeScreen(),
          '/evolve': (context) => const EvolveScreen(),
          '/wardrobe': (context) => const WardrobeScreen(),
          '/codi': (context) => const CodiScreen(),
        },
      ),
    );
  }
}

/// 앱 초기화 및 라우팅 결정
class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AvatarProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 아바타가 없으면 설정 화면으로
        if (!provider.hasAvatar) {
          return const MannequinSelectionScreen();
        }

        // 있으면 홈 화면으로
        return const HomeScreen();
      },
    );
  }
}
