import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/codi_score.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/config_service.dart';
import '../../services/codi_composer_service.dart';

class CodiScreen extends StatefulWidget {
  const CodiScreen({super.key});

  @override
  State<CodiScreen> createState() => _CodiScreenState();
}

class _CodiScreenState extends State<CodiScreen> {
  String? _selectedTopId;
  String? _selectedBottomId;
  String? _composedImagePath;
  bool _isProcessing = false;
  late Map<String, int> _scores;

  @override
  void initState() {
    super.initState();
    final config = ConfigService.instance;
    _scores = {
      for (final item in config.scoreItems)
        item.id: ((item.min + item.max) / 2).round()
    };
  }

  Future<void> _createCodi() async {
    final config = ConfigService.instance;
    final wardrobe = context.read<WardrobeProvider>();
    final avatarProvider = context.read<AvatarProvider>();

    if (_selectedTopId == null || _selectedBottomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(config.getString('strings.codi.no_items'))),
      );
      return;
    }

    final top = wardrobe.clothes.firstWhere(
      (c) => c.id == _selectedTopId,
      orElse: () => wardrobe.clothes.first,
    );
    final bottom = wardrobe.clothes.firstWhere(
      (c) => c.id == _selectedBottomId,
      orElse: () => wardrobe.clothes.first,
    );

    final avatar = avatarProvider.avatar;
    if (avatar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(config.getString('strings.errors.no_avatar'))),
      );
      return;
    }

    final mannequin =
        config.getMannequinById(avatar.baseMannequinId);
    final basePath = avatar.evolvedImagePath?.isNotEmpty == true
        ? avatar.evolvedImagePath!
        : mannequin?.assetPath;

    if (basePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(config.getString('strings.errors.mannequin_not_found'))),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final composer = CodiComposerService();
    final composed = await composer.compose(
      basePath: basePath,
      clothingImagePaths: [
        top.extractedImagePath ?? top.originalImagePath,
        bottom.extractedImagePath ?? bottom.originalImagePath,
      ],
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (composed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(config.getString('strings.errors.compose_failed'))),
      );
      return;
    }

    final score = CodiScore(scores: Map<String, int>.from(_scores));
    await wardrobe.addCodiRecord(
      topId: top.id,
      bottomId: bottom.id,
      composedImagePath: composed.path,
      score: score,
      memo: null,
    );

    setState(() => _composedImagePath = composed.path);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(config.getString('strings.codi.created'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance;
    final wardrobe = context.watch<WardrobeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(config.getString('strings.codi.title')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSelectionRow(
              label: config.getString('strings.codi.select_top'),
              value: _selectedTopId,
              items: wardrobe.tops,
              onChanged: (value) => setState(() => _selectedTopId = value),
            ),
            const SizedBox(height: 12),
            _buildSelectionRow(
              label: config.getString('strings.codi.select_bottom'),
              value: _selectedBottomId,
              items: wardrobe.bottoms,
              onChanged: (value) => setState(() => _selectedBottomId = value),
            ),
            const SizedBox(height: 16),
            Text(
              config.getString('strings.score.title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildScoreSliders(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isProcessing ? null : _createCodi,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isProcessing
                  ? Text(config.getString('strings.wardrobe.processing'))
                  : Text(config.getString('strings.codi.create')),
            ),
            if (_composedImagePath != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 320,
                child: Image.file(File(_composedImagePath!), fit: BoxFit.contain),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionRow({
    required String label,
    required String? value,
    required List<dynamic> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item.id as String,
                child: Text(item.name as String),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  List<Widget> _buildScoreSliders() {
    final config = ConfigService.instance;
    final items = config.scoreItems;

    return items.map((item) {
      final value = _scores[item.id] ?? item.min;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.getDisplayName(config.locale)),
          Slider(
            value: value.toDouble(),
            min: item.min.toDouble(),
            max: item.max.toDouble(),
            divisions: item.max - item.min,
            label: value.toString(),
            onChanged: (v) {
              setState(() {
                _scores[item.id] = v.round();
              });
            },
          ),
        ],
      );
    }).toList();
  }
}
