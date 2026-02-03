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

          return Stack(
            children: [
              // 레이아웃: 아바타 이미지 + 버튼 바
              Column(
                children: [
                  // 아바타 이미지 영역
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        color: Colors.white,
                        child: Center(
                          child: _buildAvatarImage(avatar.evolvedImagePath,
                              mannequin?.assetPath),
                        ),
                      ),
                    ),
                  ),
                  // 통계 버튼 바
                  Consumer<WardrobeProvider>(
                    builder: (context, wardrobeProvider, child) {
                      return Container(
                        color: Colors.white.withValues(alpha: 0.95),
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              icon: Icons.checkroom,
                              label: config.getString('strings.home.stat_clothes'),
                              count: wardrobeProvider.clothes.length,
                              onTap: () {
                                Navigator.of(context).pushNamed('/wardrobe');
                              },
                            ),
                            _buildStatCard(
                              icon: Icons.auto_awesome,
                              label: config.getString('strings.home.stat_evolution'),
                              count: avatar.evolutionHistory.length,
                            ),
                            _buildStatCard(
                              icon: Icons.style,
                              label: config.getString('strings.home.stat_codi'),
                              count: wardrobeProvider.records.length,
                              onTap: () {
                                Navigator.of(context).pushNamed('/codi');
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SafeArea(
                    top: false,
                    bottom: true,
                    child: const SizedBox(height: 16),
                  ),
                ],
              ),
              // 좌상단 히스토리 버튼
              Positioned(
                top: 30,
                left: 16,
                child: Material(
                  color: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed('/history');
                    },
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.history, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              // 우상단 설정 버튼
              Positioned(
                top: 30,
                right: 16,
                child: Material(
                  color: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed('/setup');
                    },
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.settings, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int count,
    VoidCallback? onTap,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: content,
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
