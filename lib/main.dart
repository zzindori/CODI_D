import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/gemini_service.dart';
import 'services/grok_service.dart';
import 'services/stability_service.dart';
import 'services/config_service.dart';
import 'providers/avatar_provider.dart';
import 'providers/wardrobe_provider.dart';
import 'screens/setup/mannequin_selection_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/evolve/evolve_screen.dart';
import 'screens/wardrobe/wardrobe_screen.dart';
import 'screens/coordination/coordination_screen.dart';
import 'screens/analysis/analysis_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  assert(() {
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    debugPaintPointersEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
    return true;
  }());

  try {
    // ConfigService 초기화 (헌법 준수: 모든 표현 데이터 JSON 로드)
    await ConfigService.instance.initialize(locale: 'ko');
    debugPrint('[Main] ✅ ConfigService 초기화 완료');
  } catch (e, st) {
    debugPrint('[Main] ❌ ConfigService 초기화 실패: $e');
    debugPrint('[Main] StackTrace: $st');
  }

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
    const xaiApiKey = String.fromEnvironment('XAI_API_KEY', defaultValue: '');
    const stabilityApiKey = String.fromEnvironment(
      'STABILITY_API_KEY',
      defaultValue: '',
    );

    debugPrint('[MyApp] Gemini API 키 설정됨: ${geminiApiKey.isNotEmpty}');
    debugPrint('[MyApp] XAI API 키 설정됨: ${xaiApiKey.isNotEmpty}');
    debugPrint('[MyApp] Stability API 키 설정됨: ${stabilityApiKey.isNotEmpty}');

    final storageService = StorageService();
    final geminiService = GeminiService(apiKey: geminiApiKey);
    final grokService = GrokService(apiKey: xaiApiKey);
    final stabilityService = StabilityService(apiKey: stabilityApiKey);

    const lightScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFAD8226),
      onPrimary: Color(0xFF191309),
      secondary: Color(0xFFA97C22),
      onSecondary: Color(0xFF191208),
      error: Color(0xFFB53A35),
      onError: Colors.white,
      surface: Color(0xFFF6F3EC),
      onSurface: Color(0xFF181612),
      surfaceContainerHighest: Color(0xFFE6DCC8),
      onSurfaceVariant: Color(0xFF4F4739),
      outline: Color(0xFF8B7A58),
      outlineVariant: Color(0xFFC6B38B),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF25282D),
      onInverseSurface: Color(0xFFF4F0E7),
      inversePrimary: Color(0xFFD2A347),
      tertiary: Color(0xFF7E652C),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFDCC58D),
      onTertiaryContainer: Color(0xFF221A0A),
      primaryContainer: Color(0xFFE0C27D),
      onPrimaryContainer: Color(0xFF241B0B),
      secondaryContainer: Color(0xFFDABE7A),
      onSecondaryContainer: Color(0xFF231A0A),
      errorContainer: Color(0xFFF9DAD7),
      onErrorContainer: Color(0xFF410001),
      surfaceDim: Color(0xFFE0D8C8),
      surfaceBright: Color(0xFFFFF9EF),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF0E9DA),
      surfaceContainer: Color(0xFFEADFCB),
      surfaceContainerHigh: Color(0xFFE4D8C1),
    );

    const darkScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFC89B33),
      onPrimary: Color(0xFF1D1507),
      secondary: Color(0xFFBC8E2D),
      onSecondary: Color(0xFF1C1407),
      error: Color(0xFFF08A7D),
      onError: Color(0xFF3A0604),
      surface: Color(0xFF12110F),
      onSurface: Color(0xFFF0E7D3),
      surfaceContainerHighest: Color(0xFF26221C),
      onSurfaceVariant: Color(0xFFCDBE9F),
      outline: Color(0xFFA18449),
      outlineVariant: Color(0xFF4F4533),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF2A2D31),
      onInverseSurface: Color(0xFFF4EFE3),
      inversePrimary: Color(0xFFD4A84B),
      tertiary: Color(0xFFC9AA6A),
      onTertiary: Color(0xFF221809),
      tertiaryContainer: Color(0xFF4C3A16),
      onTertiaryContainer: Color(0xFFF4E0B3),
      primaryContainer: Color(0xFF5A4315),
      onPrimaryContainer: Color(0xFFF6DFAC),
      secondaryContainer: Color(0xFF503B14),
      onSecondaryContainer: Color(0xFFF2DBA8),
      errorContainer: Color(0xFF60201A),
      onErrorContainer: Color(0xFFFFDAD5),
      surfaceDim: Color(0xFF181A1D),
      surfaceBright: Color(0xFF3A3E44),
      surfaceContainerLowest: Color(0xFF14161A),
      surfaceContainerLow: Color(0xFF212429),
      surfaceContainer: Color(0xFF272B30),
      surfaceContainerHigh: Color(0xFF2F343A),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AvatarProvider(
            storage: storageService,
            gemini: geminiService,
            stability: stabilityService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WardrobeProvider(
            storage: storageService,
            gemini: geminiService,
            grok: grokService,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: ConfigService.instance.getString('strings.app_name'),
        themeMode: ThemeMode.system,
        theme: ThemeData(
          colorScheme: lightScheme,
          useMaterial3: true,
          scaffoldBackgroundColor: lightScheme.inverseSurface,
          cardTheme: CardThemeData(
            color: lightScheme.surfaceContainerLow,
            elevation: 1,
            shadowColor: lightScheme.shadow.withValues(alpha: 0.16),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
          scaffoldBackgroundColor: darkScheme.inverseSurface,
          cardTheme: CardThemeData(
            color: darkScheme.surfaceContainerLow,
            elevation: 1,
            shadowColor: darkScheme.shadow.withValues(alpha: 0.32),
          ),
        ),
        home: const AppInitializer(),
        routes: {
          '/setup': (context) => const MannequinSelectionScreen(),
          '/home': (context) => const HomeScreen(),
          '/evolve': (context) => const EvolveScreen(),
          '/wardrobe': (context) => const WardrobeScreen(),
          '/codi': (context) => const CoordinationScreen(),
          '/coordination': (context) => const CoordinationScreen(),
          '/analysis': (context) => const AnalysisListScreen(),
        },
      ),
    );
  }
}

/// 앱 초기화 및 라우팅 결정
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    debugPrint('[AppInitializer] initState 호출됨');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AppInitializer] build 호출됨');
    return Consumer<AvatarProvider>(
      builder: (context, provider, child) {
        debugPrint(
          '[AppInitializer] Consumer builder 호출됨 - isLoading: ${provider.isLoading}, hasAvatar: ${provider.hasAvatar}',
        );

        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 아바타가 없으면 설정 화면으로
        if (!provider.hasAvatar) {
          debugPrint('[AppInitializer] 아바타 없음 → MannequinSelectionScreen');
          return const MannequinSelectionScreen();
        }

        // 있으면 홈 화면으로
        debugPrint('[AppInitializer] 아바타 있음 → HomeScreen');
        return const HomeScreen();
      },
    );
  }
}
