import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../models/photo_analysis_record.dart';
import '../../models/simple_clothing_item.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/config_service.dart';
import '../../widgets/codi_styled_app_bar.dart';
import '../../widgets/clothing_detail_sheet.dart';
import '../../widgets/common_delete_dialog.dart';

/// Hex 색상 코드를 Color로 변환
Color hexToColor(String hex) {
  try {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.grey;
  } catch (e) {
    return Colors.grey;
  }
}

/// 날짜를 문자열로 변환 (년-월-일 형식)
String formatDate(DateTime? dateTime) {
  if (dateTime == null) return '-';
  return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
}

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _bannerToken = 0;

  void _showTopAlert(String message, {bool isError = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final token = ++_bannerToken;

    messenger.hideCurrentSnackBar();
    messenger.hideCurrentMaterialBanner();

    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: isError
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              _bannerToken++;
              messenger.hideCurrentMaterialBanner();
            },
            child: const Text('닫기'),
          ),
        ],
      ),
    );

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (token != _bannerToken) return;
      messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance;
    final colors = Theme.of(context).colorScheme;
    final selectedTabColor = colors.inversePrimary;
    final unselectedTabColor = colors.onInverseSurface.withValues(alpha: 0.78);

    return Scaffold(
      appBar: CodiStyledAppBar(
        title: '옷장',
        actions: [
          CodiAppBarAction(
            tooltip: '아이콘 안내',
            icon: Icons.info_outline,
            onTap: () => _showIconGuideDialog(context, config),
          ),
          CodiAppBarAction(
            tooltip: '사진분석등록',
            icon: Icons.add_a_photo_outlined,
            onTap: () => Navigator.of(context).pushNamed('/evolve'),
          ),
          CodiAppBarAction(
            tooltip: '분석목록',
            icon: Icons.auto_awesome,
            onTap: () => Navigator.of(context).pushNamed('/analysis'),
          ),
          CodiAppBarAction(
            tooltip: '코디',
            icon: Icons.style,
            onTap: () => Navigator.of(context).pushNamed('/codi'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: selectedTabColor,
          unselectedLabelColor: unselectedTabColor,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          indicatorSize: TabBarIndicatorSize.label,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: selectedTabColor, width: 2.8),
            insets: const EdgeInsets.symmetric(horizontal: 2),
          ),
          dividerColor: colors.onInverseSurface.withValues(alpha: 0.26),
          tabs: [
            Tab(
              icon: SvgPicture.asset(
                'assets/icons/clothes-cardigan-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  _tabController.index == 0
                      ? selectedTabColor
                      : unselectedTabColor,
                  BlendMode.srcIn,
                ),
              ),
              text: '외투',
            ),
            Tab(
              icon: SvgPicture.asset(
                'assets/icons/clothes-full-shirt-2-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  _tabController.index == 1
                      ? selectedTabColor
                      : unselectedTabColor,
                  BlendMode.srcIn,
                ),
              ),
              text: '상의',
            ),
            Tab(
              icon: SvgPicture.asset(
                'assets/icons/clothes-pants-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  _tabController.index == 2
                      ? selectedTabColor
                      : unselectedTabColor,
                  BlendMode.srcIn,
                ),
              ),
              text: '하의',
            ),
            Tab(
              icon: SvgPicture.asset(
                'assets/icons/baseball-cap-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  _tabController.index == 3
                      ? selectedTabColor
                      : unselectedTabColor,
                  BlendMode.srcIn,
                ),
              ),
              text: '모자',
            ),
            Tab(
              icon: SvgPicture.asset(
                'assets/icons/shoes-4-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  _tabController.index == 4
                      ? selectedTabColor
                      : unselectedTabColor,
                  BlendMode.srcIn,
                ),
              ),
              text: '신발',
            ),
            Tab(
              icon: SvgPicture.asset(
                'assets/icons/watch-alt-2-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  _tabController.index == 5
                      ? selectedTabColor
                      : unselectedTabColor,
                  BlendMode.srcIn,
                ),
              ),
              text: '소품',
            ),
          ],
        ),
      ),
      body: Consumer<WardrobeProvider>(
        builder: (context, provider, _) {
          // SimpleClothingItem (v3) 기반 필터링
          final hasSimpleItems = provider.simpleItems.isNotEmpty;

          if (!hasSimpleItems && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildSimpleClothingList(
                context,
                provider,
                config,
                provider.simpleOuterwearItems,
              ),
              _buildSimpleClothingList(
                context,
                provider,
                config,
                provider.simpleTopItems,
              ),
              _buildSimpleClothingList(
                context,
                provider,
                config,
                provider.simpleBottomItems,
              ),
              _buildSimpleClothingList(
                context,
                provider,
                config,
                provider.simpleHatItems,
              ),
              _buildSimpleClothingList(
                context,
                provider,
                config,
                provider.simpleShoeItems,
              ),
              _buildSimpleClothingList(
                context,
                provider,
                config,
                provider.simpleAccessoryItems,
              ),
            ],
          );
        },
      ),
    );
  }

  /// SimpleClothingItem (v3) 기반 UI
  Widget _buildSimpleClothingList(
    BuildContext context,
    WardrobeProvider provider,
    ConfigService config,
    List<SimpleClothingItem> items,
  ) {
    if (items.isEmpty) {
      return Center(child: Text(config.getString('strings.wardrobe.empty')));
    }

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return ListView.builder(
      itemCount: items.length,
      padding: EdgeInsets.fromLTRB(8, 8, 8, 16 + bottomInset),
      itemBuilder: (context, index) {
        final item = items[index];

        return _buildItemCard(context, item, provider, config);
      },
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    SimpleClothingItem item,
    WardrobeProvider provider,
    ConfigService config,
  ) {
    final colors = Theme.of(context).colorScheme;
    final dateStr = _formatDate(item.createdAt);
    final seasonList = _extractSeasonList(item.season);
    final hasColorHex = item.colorHex.trim().isNotEmpty;
    final styleCircleLabels = <String>[];
    final styleCircleLabelKeys = <String>{};
    final occasionCircleLabels = <String>[];
    final occasionCircleLabelKeys = <String>{};

    if (item.style.trim().isNotEmpty && item.style != 'unknown') {
      final normalizedStyle = item.style.trim().toLowerCase();
      if (styleCircleLabelKeys.add(normalizedStyle)) {
        styleCircleLabels.add(item.style);
      }
    }

    for (final occasion in item.occasion) {
      final normalizedOccasion = occasion.trim().toLowerCase();
      if (normalizedOccasion.isNotEmpty &&
          occasionCircleLabelKeys.add(normalizedOccasion)) {
        occasionCircleLabels.add(occasion);
      }
    }

    return GestureDetector(
      onTap: () => _showItemDetailSlide(context, item),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 첫번째 줄: 썸네일 + 아이템명/날짜 + 삭제 버튼
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildThumbnail(item.photoPath),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _displayLabel(item),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colors.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasColorHex) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 13,
                                      height: 13,
                                      decoration: BoxDecoration(
                                        color: hexToColor(item.colorHex),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey[400]!,
                                          width: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (seasonList.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _buildSeasonIcons(seasonList),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            if (styleCircleLabels.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: styleCircleLabels
                                    .map(
                                      (label) =>
                                          _buildStyleIcon(context, label),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (occasionCircleLabels.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: occasionCircleLabels
                                    .map(
                                      (label) =>
                                          _buildOccasionIcon(context, label),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildWardrobeDeleteAction(
                    context,
                    onTap: () async {
                      final confirmed = await showCommonDeleteDialog(
                        context,
                        title: '삭제할까요?',
                        message: '삭제한 항목은 옷장과 분석 연결 데이터에서 함께 제거됩니다.',
                        cancelText: '취소',
                        confirmText: '확인',
                      );
                      if (!confirmed) return;

                      final removed = await provider.removeSimpleItem(item.id);
                      if (!mounted) return;
                      if (removed) {
                        _showTopAlert('삭제되었습니다');
                      } else {
                        _showTopAlert(
                          provider.error ?? '삭제에 실패했습니다.',
                          isError: true,
                        );
                      }
                    },
                  ),
                ],
              ),
              // 분류 메타데이터(색상/재질/패턴/스타일/시즌/용도)는 내부 로직용으로 숨김
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWardrobeDeleteAction(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final topColor =
        Color.lerp(colors.primaryContainer, colors.errorContainer, 0.55)!;
    final midColor =
        Color.lerp(colors.primaryContainer, colors.errorContainer, 0.72)!;
    final bottomColor = Color.lerp(colors.primary, colors.error, 0.52)!;
    final borderColor = Color.lerp(colors.primary, colors.error, 0.62)!;
    final iconColor =
        Color.lerp(colors.onPrimaryContainer, colors.onErrorContainer, 0.5)!;

    return SizedBox(
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              topColor,
              midColor,
              bottomColor,
            ],
          ),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.16),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Icon(
              Icons.delete_outline,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  String _displayLabel(SimpleClothingItem item) {
    final ko = item.labelKo.trim();
    if (ko.isNotEmpty) return ko;
    if (item.itemType.trim().isNotEmpty) return item.itemType;
    return item.labelEn;
  }

  String _formatDate(DateTime? dateTime) {
    return formatDate(dateTime);
  }

  List<String> _extractSeasonList(List<String> season) {
    return season.where((e) => e.trim().isNotEmpty).toList();
  }

  Widget _buildSeasonIcons(List<String> seasons) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: seasons
          .map(
            (season) => Tooltip(
              message: season,
              child: Icon(
                _seasonIcon(season),
                size: 14,
                color: Colors.grey[700],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStyleIcon(BuildContext context, String style) {
    return Tooltip(
      message: style,
      child: Icon(
        _styleIcon(style),
        size: 18,
        color: _styleColor(context, style),
      ),
    );
  }

  Widget _buildOccasionIcon(BuildContext context, String occasion) {
    return Tooltip(
      message: occasion,
      child: Icon(
        _occasionIcon(occasion),
        size: 18,
        color: _occasionColor(context, occasion),
      ),
    );
  }

  Color _styleColor(BuildContext context, String style) {
    final normalized = style.trim().toLowerCase();
    final scheme = Theme.of(context).colorScheme;

    if (normalized.contains('casual') || normalized.contains('캐주얼')) {
      return scheme.tertiary;
    }
    if (normalized.contains('formal') ||
        normalized.contains('정장') ||
        normalized.contains('포멀')) {
      return scheme.primary;
    }
    if (normalized.contains('sport') || normalized.contains('스포츠')) {
      return scheme.secondary;
    }
    return scheme.onSurfaceVariant;
  }

  IconData _styleIcon(String style) {
    final normalized = style.trim().toLowerCase();
    if (normalized.contains('casual') || normalized.contains('캐주얼')) {
      return Icons.weekend;
    }
    if (normalized.contains('formal') ||
        normalized.contains('정장') ||
        normalized.contains('포멀')) {
      return Icons.business_center;
    }
    if (normalized.contains('sport') || normalized.contains('스포츠')) {
      return Icons.sports_soccer;
    }
    return Icons.checkroom;
  }

  Color _occasionColor(BuildContext context, String occasion) {
    final normalized = occasion.trim().toLowerCase();
    final scheme = Theme.of(context).colorScheme;

    if (normalized.contains('casual') || normalized.contains('캐주얼')) {
      return scheme.primary;
    }

    if (normalized.contains('daily') || normalized.contains('데일리')) {
      return scheme.tertiary;
    }
    if (normalized.contains('work') || normalized.contains('비즈니스')) {
      return scheme.primary;
    }
    if (normalized.contains('date') || normalized.contains('데이트')) {
      return scheme.secondary;
    }
    if (normalized.contains('party') || normalized.contains('파티')) {
      return scheme.error;
    }
    if (normalized.contains('outdoor') || normalized.contains('아웃도어')) {
      return scheme.primary;
    }
    if (normalized.contains('travel') || normalized.contains('여행')) {
      return scheme.tertiary;
    }
    return scheme.onSurfaceVariant;
  }

  IconData _occasionIcon(String occasion) {
    final normalized = occasion.trim().toLowerCase();
    if (normalized.contains('casual') || normalized.contains('캐주얼')) {
      return Icons.weekend;
    }
    if (normalized.contains('daily') || normalized.contains('데일리')) {
      return Icons.today;
    }
    if (normalized.contains('work') || normalized.contains('비즈니스')) {
      return Icons.work;
    }
    if (normalized.contains('date') || normalized.contains('데이트')) {
      return Icons.favorite;
    }
    if (normalized.contains('party') || normalized.contains('파티')) {
      return Icons.celebration;
    }
    if (normalized.contains('outdoor') || normalized.contains('아웃도어')) {
      return Icons.terrain;
    }
    if (normalized.contains('travel') || normalized.contains('여행')) {
      return Icons.luggage;
    }
    return Icons.event;
  }

  IconData _seasonIcon(String season) {
    final normalized = season.trim().toLowerCase();
    if (normalized == 'spring' || normalized == '봄') return Icons.local_florist;
    if (normalized == 'summer' || normalized == '여름') return Icons.wb_sunny;
    if (normalized == 'autumn' || normalized == 'fall' || normalized == '가을') {
      return Icons.park;
    }
    if (normalized == 'winter' || normalized == '겨울') return Icons.ac_unit;
    return Icons.calendar_month;
  }

  Widget _buildThumbnail(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.image_not_supported, size: 24),
      );
    }

    try {
      if (path.startsWith('assets/')) {
        return Image.asset(path, width: 48, height: 48, fit: BoxFit.cover);
      }

      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: 48, height: 48, fit: BoxFit.cover);
      } else {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.error, size: 24),
        );
      }
    } catch (e) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.warning, size: 24),
      );
    }
  }

  void _showItemDetailSlide(
    BuildContext context,
    SimpleClothingItem item,
  ) {
    showClothingDetailSheet(
      context,
      ClothingDetailData(
        title: _displayLabel(item),
        imagePath: item.photoPath,
        dateText: '${ConfigService.instance.getString('strings.wardrobe.registered_date')}: ${formatDate(item.createdAt)}',
        category: _categoryLabel(item.itemCategory),
        description: (item.descriptionKo.trim().isNotEmpty
                ? item.descriptionKo
                : item.description)
            .trim(),
        color: item.color,
        colorHex: item.colorHex,
        material: item.material,
        pattern: item.pattern,
        style: item.style,
        season: item.season,
        occasion: item.occasion,
      ),
    );
  }

  String _categoryLabel(String category) {
    final normalized = category.trim().toLowerCase();
    switch (normalized) {
      case 'outerwear':
        return '외투';
      case 'top':
        return '상의';
      case 'bottom':
        return '하의';
      case 'hat':
        return '모자';
      case 'shoes':
        return '신발';
      case 'accessory':
        return '악세사리';
      default:
        return category;
    }
  }

  void _showIconGuideDialog(BuildContext context, ConfigService config) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('아이콘 안내'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440, maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '스타일 아이콘',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _buildIconGuideRow(
                  icon: Icons.weekend,
                  text: '캐주얼 계열 스타일',
                  color: _styleColor(context, '캐주얼'),
                ),
                _buildIconGuideRow(
                  icon: Icons.business_center,
                  text: '포멀/정장 계열 스타일',
                  color: _styleColor(context, '포멀'),
                ),
                _buildIconGuideRow(
                  icon: Icons.sports_soccer,
                  text: '스포티 계열 스타일',
                  color: _styleColor(context, '스포츠'),
                ),
                const SizedBox(height: 12),
                const Text(
                  '계절 아이콘',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _buildIconGuideRow(
                  icon: Icons.local_florist,
                  text: '봄',
                  color: scheme.primary,
                ),
                _buildIconGuideRow(
                  icon: Icons.wb_sunny,
                  text: '여름',
                  color: scheme.tertiary,
                ),
                _buildIconGuideRow(
                  icon: Icons.park,
                  text: '가을',
                  color: scheme.secondary,
                ),
                _buildIconGuideRow(
                  icon: Icons.ac_unit,
                  text: '겨울',
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  '용도 아이콘',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _buildIconGuideRow(
                  icon: Icons.weekend,
                  text: '캐주얼(용도)',
                  color: _occasionColor(context, '캐주얼'),
                ),
                _buildIconGuideRow(
                  icon: Icons.today,
                  text: '데일리',
                  color: _occasionColor(context, '데일리'),
                ),
                _buildIconGuideRow(
                  icon: Icons.work,
                  text: '비즈니스/출근',
                  color: _occasionColor(context, '비즈니스'),
                ),
                _buildIconGuideRow(
                  icon: Icons.favorite,
                  text: '데이트',
                  color: _occasionColor(context, '데이트'),
                ),
                _buildIconGuideRow(
                  icon: Icons.celebration,
                  text: '파티',
                  color: _occasionColor(context, '파티'),
                ),
                _buildIconGuideRow(
                  icon: Icons.terrain,
                  text: '아웃도어',
                  color: _occasionColor(context, '아웃도어'),
                ),
                _buildIconGuideRow(
                  icon: Icons.luggage,
                  text: '여행',
                  color: _occasionColor(context, '여행'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              config.getString('strings.common.close', fallback: '닫기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGuideRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// 왼쪽 슬라이드 아이템 상세 정보 패널
class _ItemDetailSlidePanel extends StatefulWidget {
  final SimpleClothingItem item;
  final WardrobeProvider provider;
  final ConfigService config;

  const _ItemDetailSlidePanel({
    required this.item,
    required this.provider,
    required this.config,
  });

  @override
  State<_ItemDetailSlidePanel> createState() => _ItemDetailSlidePanelState();
}

class _ItemDetailSlidePanelState extends State<_ItemDetailSlidePanel> {
  static const double _defaultAnalysisFontSize = 14;
  static const double _minDescriptionFontSize = 11;
  static const double _maxDescriptionFontSize = 24;

  double _analysisFontSize = _defaultAnalysisFontSize;
  double? _scaleStartFontSize;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final provider = widget.provider;
    final config = widget.config;
    final record = provider.getPhotoAnalysisForItem(item.photoPath);
    final analysisDetail = _resolveAnalysisDetail(record?.items);
    final primaryTag = analysisDetail.isNotEmpty ? analysisDetail.first : null;
    final descriptionKo = (primaryTag?.descriptionKo ?? item.descriptionKo)
        .trim();
    final descriptionEn = (primaryTag?.description ?? item.description).trim();
    final descriptionText = descriptionKo.isNotEmpty
        ? descriptionKo
        : descriptionEn;
    final displayImagePath = _resolveDetailImagePath(item, provider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayLabel(item),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
            // 내용
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${config.getString('strings.wardrobe.registered_date')}: ${formatDate(item.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  if (displayImagePath.isNotEmpty)
                    _buildImageOverlayCard(imagePath: displayImagePath),
                  if (descriptionText.isNotEmpty)
                    _buildDescriptionCard(descriptionText: descriptionText),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayLabel(SimpleClothingItem item) {
    final ko = item.labelKo.trim();
    if (ko.isNotEmpty) return ko;
    final en = item.labelEn.trim();
    if (en.isNotEmpty) return en;
    if (item.itemType.trim().isNotEmpty) return item.itemType;
    return item.description;
  }

  String _resolveDetailImagePath(
    SimpleClothingItem item,
    WardrobeProvider provider,
  ) {
    final itemPath = item.photoPath.trim();
    if (itemPath.isNotEmpty && File(itemPath).existsSync()) {
      return itemPath;
    }

    final record = provider.getPhotoAnalysisForItem(item.photoPath);
    if (record != null) {
      final exactCrop = record.croppedImagePaths
          .map((path) => path.trim())
          .firstWhere(
            (path) => path == itemPath && File(path).existsSync(),
            orElse: () => '',
          );
      if (exactCrop.isNotEmpty) {
        return exactCrop;
      }

      final matchedCrop = record.croppedImagePaths
          .map((path) => path.trim())
          .firstWhere(
            (path) => path.isNotEmpty && File(path).existsSync(),
            orElse: () => '',
          );
      if (matchedCrop.isNotEmpty) {
        return matchedCrop;
      }
    }

    return '';
  }

  List<AnalysisItemTag> _resolveAnalysisDetail(List<AnalysisItemTag>? tags) {
    if (tags == null || tags.isEmpty) return const [];

    final selectedNames = {
      _normalizeText(widget.item.itemType),
      _normalizeText(widget.item.description),
      _normalizeText(widget.item.descriptionKo),
    }..removeWhere((name) => name.isEmpty);

    final exactMatches = tags.where((tag) {
      final label = _normalizeText(tag.label);
      final description = _normalizeText(tag.description);
      final descriptionKo = _normalizeText(tag.descriptionKo ?? '');

      return selectedNames.contains(label) ||
          selectedNames.contains(description) ||
          selectedNames.contains(descriptionKo);
    }).toList();

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    final selectedType = _normalizeText(widget.item.itemType);
    if (selectedType.isNotEmpty) {
      final typeMatches = tags.where((tag) {
        final label = _normalizeText(tag.label);
        return label.contains(selectedType) || selectedType.contains(label);
      }).toList();

      if (typeMatches.isNotEmpty) {
        return typeMatches;
      }
    }

    final selectedCategory = _normalizeCategory(widget.item.itemCategory);
    final categoryMatches = tags.where((tag) {
      return _normalizeCategory(tag.category) == selectedCategory;
    }).toList();

    if (categoryMatches.isNotEmpty) {
      return categoryMatches;
    }

    return [tags.first];
  }

  String _normalizeText(String? value) {
    if (value == null) return '';
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9가-힣 ]'), '');
  }

  String _normalizeCategory(String? value) {
    final normalized = _normalizeText(value);

    if (normalized.contains('outer') ||
        normalized.contains('outerwear') ||
        normalized.contains('jacket') ||
        normalized.contains('cardigan') ||
        normalized.contains('coat') ||
        normalized.contains('blazer') ||
        normalized.contains('parka') ||
        normalized.contains('아우터') ||
        normalized.contains('외투')) {
      return 'outerwear';
    }

    if (normalized.contains('top') ||
        normalized.contains('upper') ||
        normalized.contains('shirt') ||
        normalized.contains('blouse') ||
        normalized.contains('상의')) {
      return 'top';
    }

    if (normalized.contains('bottom') ||
        normalized.contains('pants') ||
        normalized.contains('trouser') ||
        normalized.contains('skirt') ||
        normalized.contains('jeans') ||
        normalized.contains('하의')) {
      return 'bottom';
    }

    if (normalized.contains('hat') ||
        normalized.contains('cap') ||
        normalized.contains('beanie') ||
        normalized.contains('모자')) {
      return 'hat';
    }

    if (normalized.contains('shoe') ||
        normalized.contains('sneaker') ||
        normalized.contains('boot') ||
        normalized.contains('sandal') ||
        normalized.contains('신발')) {
      return 'shoes';
    }

    if (normalized.contains('accessory') ||
        normalized.contains('jewelry') ||
        normalized.contains('bag') ||
        normalized.contains('belt') ||
        normalized.contains('scarf') ||
        normalized.contains('악세') ||
        normalized.contains('액세')) {
      return 'accessory';
    }

    return normalized;
  }

  Widget _buildImage(String? path, {BoxFit fit = BoxFit.contain}) {
    if (path == null || path.isEmpty) {
      return Center(
        child: Icon(
          Icons.image_not_supported,
          size: 48,
          color: Colors.grey[400],
        ),
      );
    }

    try {
      if (path.startsWith('assets/')) {
        return Image.asset(path, fit: fit, alignment: Alignment.topCenter);
      }

      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: fit, alignment: Alignment.topCenter);
      }

      return Center(
        child: Icon(Icons.error, size: 48, color: Colors.grey[400]),
      );
    } catch (e) {
      return Center(
        child: Icon(Icons.warning, size: 48, color: Colors.grey[400]),
      );
    }
  }

  Widget _buildImageOverlayCard({required String imagePath}) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: _buildImage(imagePath, fit: BoxFit.fitWidth),
      ),
    );
  }

  Widget _buildDescriptionCard({required String descriptionText}) {
    final colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '상세 설명',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  _buildFontAdjustButton(
                    icon: Icons.remove,
                    onTap: _decreaseDescriptionFont,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _analysisFontSize.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildFontAdjustButton(
                    icon: Icons.add,
                    onTap: _increaseDescriptionFont,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onDescriptionScaleStart,
                onScaleUpdate: _onDescriptionScaleUpdate,
                child: Text(
                  descriptionText,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: _analysisFontSize,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontAdjustButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        padding: EdgeInsets.zero,
        splashRadius: 14,
      ),
    );
  }

  void _decreaseDescriptionFont() {
    setState(() {
      _analysisFontSize = (_analysisFontSize - 1).clamp(
        _minDescriptionFontSize,
        _maxDescriptionFontSize,
      );
    });
  }

  void _increaseDescriptionFont() {
    setState(() {
      _analysisFontSize = (_analysisFontSize + 1).clamp(
        _minDescriptionFontSize,
        _maxDescriptionFontSize,
      );
    });
  }

  void _onDescriptionScaleStart(ScaleStartDetails details) {
    _scaleStartFontSize = _analysisFontSize;
  }

  void _onDescriptionScaleUpdate(ScaleUpdateDetails details) {
    final start = _scaleStartFontSize;
    if (start == null) return;

    final scaled = (start * details.scale).clamp(
      _minDescriptionFontSize,
      _maxDescriptionFontSize,
    );
    if ((scaled - _analysisFontSize).abs() < 0.05) {
      return;
    }

    setState(() {
      _analysisFontSize = scaled;
    });
  }
}
