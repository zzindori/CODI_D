import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/config_service.dart';

/// 홈 화면 - MyAvatar 표시 및 주요 기능 접근
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance;

    return Scaffold(
      body: Consumer<AvatarProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.hasAvatar) {
            return Center(
              child: Text(config.getString('strings.home.no_avatar')),
            );
          }

          final avatar = provider.avatar!;
          final mannequin = config.getMannequinById(avatar.baseMannequinId);
          final colors = Theme.of(context).colorScheme;
          const avatarPanelWidthFactor = 0.74;
          final sideStop = (1 - avatarPanelWidthFactor) / 2;

          return LayoutBuilder(
            builder: (context, constraints) {
              final avatarPanelWidth = constraints.maxWidth * avatarPanelWidthFactor;

              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            colors.inverseSurface,
                            colors.surfaceBright,
                            colors.surfaceBright,
                            colors.inverseSurface,
                          ],
                          stops: [0.0, sideStop, 1 - sideStop, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // 레이아웃: 아바타 이미지 + 버튼 바
                  Column(
                    children: [
                      // 아바타 이미지 영역
                      Expanded(
                        child: SafeArea(
                          bottom: false,
                          child: Container(
                            color: Colors.transparent,
                            child: Center(
                              child: SizedBox(
                                width: avatarPanelWidth,
                                child: _buildAvatarImage(
                                  avatar.evolvedImagePath,
                                  mannequin?.assetPath,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 통계 버튼 바
                      Consumer<WardrobeProvider>(
                        builder: (context, wardrobeProvider, child) {
                          return _buildBottomQuickBar(context);
                        },
                      ),
                    ],
                  ),
                  // 우상단 설정 버튼
                  Positioned(
                    top: 30,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pushNamed('/setup');
                        },
                        customBorder: const CircleBorder(),
                        child: Ink(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colors.surfaceBright.withValues(alpha: 0.98),
                                colors.primaryContainer.withValues(alpha: 0.96),
                                colors.primary.withValues(alpha: 0.84),
                              ],
                            ),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.82),
                              width: 1.15,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.settings,
                            color: colors.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomQuickBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        color: colors.inverseSurface,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.surfaceBright.withValues(alpha: 0.96),
                colors.primaryContainer.withValues(alpha: 0.92),
                colors.primary.withValues(alpha: 0.74),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.88),
              width: 1.55,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildQuickBarItem(
                context,
                icon: Icons.checkroom,
                label: '옷장',
                onTap: () => Navigator.of(context).pushNamed('/wardrobe'),
              ),
              _buildQuickBarItem(
                context,
                icon: Icons.add,
                label: '추가',
                isPrimaryAction: true,
                onTap: () {
                  context.read<WardrobeProvider>().clearTransientAnalysisState();
                  Navigator.of(context).pushNamed('/evolve');
                },
              ),
              _buildQuickBarItem(
                context,
                icon: Icons.auto_awesome,
                label: '분석',
                isAccent: true,
                onTap: () => Navigator.of(context).pushNamed('/analysis'),
              ),
              _buildQuickBarItem(
                context,
                icon: Icons.style,
                label: '코디',
                onTap: () => Navigator.of(context).pushNamed('/codi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickBarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimaryAction = false,
    bool isAccent = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = isPrimaryAction
        ? colors.inversePrimary
        : colors.onPrimaryContainer;
    final textColor = isPrimaryAction
        ? colors.inversePrimary
      : colors.onPrimaryContainer;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 70,
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  minWidth: isPrimaryAction ? 104 : 68,
                  minHeight: isPrimaryAction ? 56 : 58,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isPrimaryAction ? 16 : 6,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: null,
                  color: isPrimaryAction ? colors.inverseSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(isPrimaryAction ? 30 : 16),
                  border: isPrimaryAction
                      ? Border.all(
                          color: colors.primary.withValues(alpha: 0.92),
                          width: 1.7,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: iconColor, size: 23),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String? evolvedPath, String? mannequinPath) {
    if (evolvedPath != null && evolvedPath.isNotEmpty) {
      return Image.file(
        File(evolvedPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _fallbackAvatar();
        },
      );
    }

    if (mannequinPath != null && mannequinPath.isNotEmpty) {
      // 배경을 흰색으로 설정해서 이미지의 흰색 배경과 통일
      return Container(
        color: Colors.white,
        child: Image.asset(
          mannequinPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _fallbackAvatar();
          },
        ),
      );
    }

    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.person, size: 100),
    );
  }
}
