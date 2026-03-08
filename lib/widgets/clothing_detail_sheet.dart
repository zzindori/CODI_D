import 'dart:io';

import 'package:flutter/material.dart';

class ClothingDetailData {
  final String title;
  final String imagePath;
  final String? dateText;
  final String category;
  final String description;
  final String color;
  final String colorHex;
  final String material;
  final String pattern;
  final String style;
  final List<String> season;
  final List<String> occasion;

  const ClothingDetailData({
    required this.title,
    required this.imagePath,
    this.dateText,
    this.category = '',
    this.description = '',
    this.color = '',
    this.colorHex = '',
    this.material = '',
    this.pattern = '',
    this.style = '',
    this.season = const [],
    this.occasion = const [],
  });
}

class _InfoEntry {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;
  final int maxLines;

  const _InfoEntry({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
    this.maxLines = 2,
  });
}

Future<void> showClothingDetailSheet(
  BuildContext context,
  ClothingDetailData data,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClothingDetailSheet(data: data),
  );
}

class _ClothingDetailSheet extends StatefulWidget {
  final ClothingDetailData data;

  const _ClothingDetailSheet({required this.data});

  @override
  State<_ClothingDetailSheet> createState() => _ClothingDetailSheetState();
}

class _ClothingDetailSheetState extends State<_ClothingDetailSheet> {
  static const double _minDescFontSize = 11;
  static const double _maxDescFontSize = 22;
  double _descFontSize = 13;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = widget.data;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  16 + MediaQuery.of(context).viewPadding.bottom,
                ),
                children: [
                  if ((data.dateText ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        data.dateText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  _buildImage(data.imagePath),
                  const SizedBox(height: 10),
                  _buildDescriptionBox(context),
                  const SizedBox(height: 10),
                  _buildInfoTableCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1,
        child: _buildImageBody(path),
      ),
    );
  }

  Widget _buildImageBody(String path) {
    final colors = Theme.of(context).colorScheme;

    if (path.isEmpty) {
      return ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 42,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(
          color: colors.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.error_outline,
              size: 42,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 42,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.error_outline,
            size: 42,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionBox(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final description = widget.data.description.trim();
    if (description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '설명',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              _fontButton(Icons.remove, _decreaseDescriptionFont),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _descFontSize.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _fontButton(Icons.add, _increaseDescriptionFont),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: _descFontSize,
              height: 1.4,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontButton(IconData icon, VoidCallback onTap) {
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
      _descFontSize = (_descFontSize - 1).clamp(
        _minDescFontSize,
        _maxDescFontSize,
      );
    });
  }

  void _increaseDescriptionFont() {
    setState(() {
      _descFontSize = (_descFontSize + 1).clamp(
        _minDescFontSize,
        _maxDescFontSize,
      );
    });
  }

  Widget _buildInfoTableCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = widget.data;

    final entries = <_InfoEntry>[];

    void addEntry({
      required String label,
      required String rawValue,
      required IconData icon,
      Widget? trailing,
      int maxLines = 2,
    }) {
      final value = _valueOrDash(rawValue);
      entries.add(
        _InfoEntry(
          label: label,
          value: value,
          icon: icon,
          trailing: trailing,
          maxLines: maxLines,
        ),
      );
    }

    final seasonsRaw = data.season.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final seasons = seasonsRaw.isEmpty ? '-' : seasonsRaw.toSet().join(', ');
    final occasionsRaw = data.occasion
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final occasions = occasionsRaw.isEmpty
        ? <String>['-']
        : occasionsRaw.toSet().toList();

    addEntry(label: '카테고리', rawValue: data.category, icon: Icons.checkroom);
    addEntry(
      label: '색상',
      rawValue: data.color,
      icon: Icons.palette_outlined,
      trailing: _colorPalette(data.colorHex),
      maxLines: 1,
    );
    addEntry(label: '스타일', rawValue: data.style, icon: Icons.style_outlined);
    addEntry(label: '소재', rawValue: data.material, icon: Icons.spa_outlined);
    addEntry(label: '패턴', rawValue: data.pattern, icon: Icons.grid_on_outlined);
    addEntry(label: '계절', rawValue: seasons, icon: Icons.wb_sunny_outlined);

    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      final left = entries[i];
      final right = i + 1 < entries.length ? entries[i + 1] : null;
      rows.add(_buildInfoPairRow(context, left, right));
      if (i + 2 < entries.length || occasions.isNotEmpty) {
        rows.add(Divider(height: 1, color: colors.outlineVariant));
      }
    }

    rows.add(_buildOccasionRow(context, occasions));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: rows,
      ),
    );
  }

  Widget _buildInfoPairRow(
    BuildContext context,
    _InfoEntry left,
    _InfoEntry? right,
  ) {
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: _buildInfoCell(context, left)),
          if (right != null)
            VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
          if (right != null) Expanded(child: _buildInfoCell(context, right)),
          if (right == null) const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildInfoCell(BuildContext context, _InfoEntry entry) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        children: [
          Icon(entry.icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: entry.maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (entry.trailing != null) ...[
            const SizedBox(width: 6),
            entry.trailing!,
          ],
        ],
      ),
    );
  }

  Widget _buildOccasionRow(BuildContext context, List<String> occasions) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.outlined_flag_outlined, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          const Text(
            '용도',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: occasions
                  .map(
                    (value) => Chip(
                      label: Text(value, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPalette(String hexCode) {
    final colors = Theme.of(context).colorScheme;
    final color = _tryParseHex(hexCode);
    if (color == null) return const SizedBox.shrink();

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant),
      ),
    );
  }

  Color? _tryParseHex(String? raw) {
    if (raw == null) return null;
    var value = raw.trim().replaceAll('#', '');
    if (value.isEmpty) return null;
    if (value.length == 3) {
      value = value.split('').map((e) => '$e$e').join();
    }
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  String _valueOrDash(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '-';
    return normalized;
  }
}
