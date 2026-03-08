import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/photo_analysis_record.dart';
import '../../providers/wardrobe_provider.dart';
import '../evolve/evolve_screen.dart';
import '../../widgets/codi_styled_app_bar.dart';
import '../../widgets/clothing_detail_sheet.dart';
import '../../widgets/common_delete_dialog.dart';

class AnalysisListScreen extends StatelessWidget {
  const AnalysisListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CodiStyledAppBar(
        title: '분석 목록',
        actions: [
          CodiAppBarAction(
            tooltip: '드레스룸',
            icon: Icons.checkroom,
            onTap: () => Navigator.of(context).pushNamed('/wardrobe'),
          ),
          CodiAppBarAction(
            tooltip: '사진분석등록',
            icon: Icons.add_a_photo_outlined,
            onTap: () => Navigator.of(context).pushNamed('/evolve'),
          ),
          CodiAppBarAction(
            tooltip: '코디',
            icon: Icons.style,
            onTap: () => Navigator.of(context).pushNamed('/codi'),
          ),
        ],
      ),
      body: Consumer<WardrobeProvider>(
        builder: (context, provider, _) {
          final analyses = provider.photoAnalyses;
          final bottomInset = MediaQuery.of(context).viewPadding.bottom;

          if (provider.isLoading && analyses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (analyses.isEmpty) {
            return const Center(
              child: Text('아직 분석 기록이 없습니다.'),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 16 + bottomInset),
            itemCount: analyses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final record = analyses[index];
              final itemCount = record.items.length;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _showOriginalImagePopup(context, record),
                          child: _buildSideThumbnail(record.imagePath, width: 76),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDate(record.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '분석$itemCount개',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _headerActionIcon(
                                    context,
                                    tooltip: '편집',
                                    icon: Icons.edit_square,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EvolveScreen(
                                          initialEditRecord: record,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  _headerActionIcon(
                                    context,
                                    tooltip: '삭제',
                                    icon: Icons.delete_outline,
                                    destructive: true,
                                    onTap: () => _confirmAndDeleteRecord(context, record),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 68,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: record.croppedImagePaths.isNotEmpty
                                      ? record.croppedImagePaths.length
                                      : 1,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, thumbIndex) {
                                    final path = record.croppedImagePaths.isNotEmpty
                                        ? record.croppedImagePaths[thumbIndex]
                                        : record.imagePath;
                                    final tag = thumbIndex < record.items.length
                                        ? record.items[thumbIndex]
                                      : null;

                                    return GestureDetector(
                                      onTap: () => _showAnalysisDetail(
                                        context,
                                        record,
                                        tag,
                                        path,
                                      ),
                                      child: _buildThumbnail(path, size: 68),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(String path, {double size = 64}) {
    if (path.isEmpty) {
      return Builder(
        builder: (context) =>
            _thumbnailFallback(context, Icons.image_not_supported, size: size),
      );
    }

    if (path.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) =>
              _thumbnailFallback(context, Icons.error, size: size),
        ),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return Builder(
        builder: (context) => _thumbnailFallback(
          context,
          Icons.broken_image_outlined,
          size: size,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) =>
            _thumbnailFallback(context, Icons.error, size: size),
      ),
    );
  }


  Widget _buildSideThumbnail(String path, {double width = 76}) {
    if (path.isEmpty) {
      return SizedBox(
        width: width,
        child: Builder(
          builder: (context) => _thumbnailFallback(
            context,
            Icons.image_not_supported,
            size: width,
          ),
        ),
      );
    }

    if (path.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) =>
                _thumbnailFillFallback(context, Icons.error),
          ),
        ),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return SizedBox(
        width: width,
        child: Builder(
          builder: (context) =>
              _thumbnailFillFallback(context, Icons.broken_image_outlined),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) =>
              _thumbnailFillFallback(context, Icons.error),
        ),
      ),
    );
  }

  Widget _thumbnailFillFallback(BuildContext context, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHighest,
      child: Icon(icon, color: colors.onSurfaceVariant),
    );
  }

  Widget _thumbnailFallback(
    BuildContext context,
    IconData icon, {
    double size = 64,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: colors.onSurfaceVariant),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  Widget _headerActionIcon(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final topColor = destructive
        ? Color.lerp(colors.primaryContainer, colors.errorContainer, 0.55)!
        : colors.surfaceBright.withValues(alpha: 0.98);
    final midColor = destructive
        ? Color.lerp(colors.primaryContainer, colors.errorContainer, 0.72)!
        : colors.primaryContainer.withValues(alpha: 0.95);
    final bottomColor = destructive
        ? Color.lerp(colors.primary, colors.error, 0.52)!
        : colors.primary.withValues(alpha: 0.78);
    final borderColor = destructive
        ? Color.lerp(colors.primary, colors.error, 0.62)!
        : colors.primary.withValues(alpha: 0.98);
    final iconColor = destructive
        ? Color.lerp(colors.onPrimaryContainer, colors.onErrorContainer, 0.5)!
        : colors.onPrimaryContainer;

    return Tooltip(
      message: tooltip,
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
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                size: 17,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteRecord(
    BuildContext context,
    PhotoAnalysisRecord record,
  ) async {
    final confirmed = await showCommonDeleteDialog(
      context,
      title: '삭제할까요?',
      message: '삭제하면 옷장에 연결된 데이터도 함께 삭제됩니다.',
      cancelText: '취소',
      confirmText: '확인',
    );

    if (!confirmed || !context.mounted) return;
    await _deleteRecord(context, record);
  }

  Future<void> _deleteRecord(
    BuildContext context,
    PhotoAnalysisRecord record,
  ) async {
    final provider = context.read<WardrobeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.deletePhotoAnalysis(record.id);
    if (!context.mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? '분석 항목이 삭제되었습니다.' : '삭제에 실패했습니다.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showOriginalImagePopup(
    BuildContext context,
    PhotoAnalysisRecord record,
  ) {
    final originalPath = record.imagePath.trim();
    final firstStagePath = record.generatedImagePath.trim();
    final colors = Theme.of(context).colorScheme;
    final originalImage = _buildPopupImage(path: originalPath, colors: colors);
    final firstStageImage = _buildPopupImage(path: firstStagePath, colors: colors);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: colors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '분석 이미지',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                          tooltip: '닫기',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '원본 이미지',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Center(child: originalImage),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1차 추출 이미지',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Center(child: firstStageImage),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '아이템별 상세',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPopupItemDetailList(context, colors: colors, record: record),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupImage({
    required String path,
    required ColorScheme colors,
  }) {
    if (path.isEmpty) {
      return Icon(Icons.image_not_supported, color: colors.onSurfaceVariant);
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.error_outline, color: colors.onSurfaceVariant),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant);
    }

    return Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.error_outline, color: colors.onSurfaceVariant),
    );
  }

  Widget _buildPopupItemDetailList(
    BuildContext context, {
    required ColorScheme colors,
    required PhotoAnalysisRecord record,
  }) {
    if (record.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Text(
          '아이템 상세 데이터가 없습니다.',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(record.items.length, (index) {
          final item = record.items[index];
          final imagePath = index < record.croppedImagePaths.length
              ? record.croppedImagePaths[index].trim()
              : '';
          final itemImage = _buildPopupImage(path: imagePath, colors: colors);
          final title = _itemLabel(item).isEmpty
              ? _categoryKorean(item.category)
              : _itemLabel(item);
          final descriptionKo = (item.descriptionKo ?? '').trim();
          final descriptionEn = item.description.trim();
          final detail = descriptionKo.isNotEmpty ? descriptionKo : descriptionEn;

          final row = Padding(
            padding: EdgeInsets.only(
              bottom: index == record.items.length - 1 ? 0 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outlineVariant),
                    color: colors.surfaceContainerHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(child: itemImage),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _categoryKorean(item.category),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (index == record.items.length - 1) return row;

          return Column(
            children: [
              row,
              Divider(color: colors.outlineVariant, height: 1),
              const SizedBox(height: 10),
            ],
          );
        }),
      ),
    );
  }

  void _showAnalysisDetail(
    BuildContext context,
    PhotoAnalysisRecord record,
    AnalysisItemTag? tag,
    String imagePath,
  ) {
    final title = _itemLabel(tag);
    final descriptionKo = (tag?.descriptionKo ?? '').trim();
    final descriptionEn = (tag?.description ?? '').trim();

    showClothingDetailSheet(
      context,
      ClothingDetailData(
        title: title.isEmpty ? '분석 항목' : title,
        imagePath: imagePath,
        dateText: '분석일: ${_formatDate(record.createdAt)}',
        category: _categoryKorean(tag?.category ?? ''),
        description: descriptionKo.isNotEmpty ? descriptionKo : descriptionEn,
        color: (tag?.color ?? '').trim(),
        colorHex: (tag?.colorHex ?? '').trim(),
        material: (tag?.material ?? '').trim(),
        pattern: (tag?.pattern ?? '').trim(),
        style: (tag?.style ?? '').trim(),
        season: tag?.season ?? const [],
        occasion: tag?.occasion ?? const [],
      ),
    );
  }

  String _itemLabel(AnalysisItemTag? tag) {
    if (tag == null) return '';
    final ko = tag.labelKo.trim();
    if (ko.isNotEmpty) return ko;
    final en = tag.labelEn.trim();
    if (en.isNotEmpty) return en;
    return tag.label.trim();
  }

  String _categoryKorean(String category) {
    switch (category.trim().toLowerCase()) {
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
}
