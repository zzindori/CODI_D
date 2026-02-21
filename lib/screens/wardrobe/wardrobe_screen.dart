import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/config_service.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(config.getString('strings.wardrobe.title')),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '상의'),
            Tab(text: '하의'),
            Tab(text: '신발'),
            Tab(text: '악세사리'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed('/evolve'),
        child: const Icon(Icons.add),
      ),
      body: Consumer<WardrobeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.clothes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildClothingList(context, provider, config, provider.tops),
              _buildClothingList(context, provider, config, provider.bottoms),
              _buildClothingList(context, provider, config, provider.shoes),
              _buildClothingList(context, provider, config, provider.accessories),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClothingList(
    BuildContext context,
    WardrobeProvider provider,
    ConfigService config,
    List<dynamic> clothes,
  ) {
    if (clothes.isEmpty) {
      return Center(
        child: Text(config.getString('strings.wardrobe.empty')),
      );
    }

    return ListView.builder(
      itemCount: clothes.length,
      itemBuilder: (context, index) {
        final item = clothes[index];
        final type = config.getClothingTypeById(item.typeId);
        final label = type?.getDisplayName(config.locale) ?? item.typeId;

        return ListTile(
          leading: _buildThumbnail(item.extractedImagePath ?? item.originalImagePath),
          title: Text(item.name),
          subtitle: Text(label),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => provider.removeClothing(item.id),
          ),
          onTap: () => _showImageDialog(context, item),
        );
      },
    );
  }

  Widget _buildThumbnail(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, width: 48, height: 48, fit: BoxFit.cover);
    }
    return Image.file(File(path), width: 48, height: 48, fit: BoxFit.cover);
  }

  void _showImageDialog(BuildContext context, dynamic item) {
    final generatedImagePath = item.imagePath;
    final sourceImagePath = item.sourceImagePath;
    
    showDialog(
      context: context,
      builder: (ctx) => _ImageViewDialog(
        itemName: item.name,
        generatedImagePath: generatedImagePath,
        sourceImagePath: sourceImagePath,
      ),
    );
  }
}

class _ImageViewDialog extends StatefulWidget {
  final String itemName;
  final String generatedImagePath;
  final String? sourceImagePath;

  const _ImageViewDialog({
    required this.itemName,
    required this.generatedImagePath,
    required this.sourceImagePath,
  });

  @override
  State<_ImageViewDialog> createState() => _ImageViewDialogState();
}

class _ImageViewDialogState extends State<_ImageViewDialog> {
  late bool showOriginal;

  @override
  void initState() {
    super.initState();
    showOriginal = false;
  }

  @override
  Widget build(BuildContext context) {
    final displayPath = showOriginal ? widget.sourceImagePath : widget.generatedImagePath;
    final displayLabel = showOriginal ? '원본' : '생성본';

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.itemName),
                Text(
                  displayLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            automaticallyImplyLeading: false,
            actions: [
              if (widget.sourceImagePath != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      showOriginal = !showOriginal;
                    });
                  },
                  child: Text(showOriginal ? '생성본' : '원본'),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Flexible(
            child: InteractiveViewer(
              child: displayPath!.startsWith('assets/')
                  ? Image.asset(displayPath, fit: BoxFit.contain)
                  : Image.file(File(displayPath), fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
