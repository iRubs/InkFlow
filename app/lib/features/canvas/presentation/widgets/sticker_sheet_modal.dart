import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/colors.dart';
import '../../services/sticker_manager.dart';

/// Modal interactivo para selección e importación de stickers.
class StickerSheetModal extends StatefulWidget {
  final ValueChanged<StickerItem> onStickerSelected;

  const StickerSheetModal({super.key, required this.onStickerSelected});

  @override
  State<StickerSheetModal> createState() => _StickerSheetModalState();
}

class _StickerSheetModalState extends State<StickerSheetModal>
    with SingleTickerProviderStateMixin {
  final StickerManager _stickerManager = StickerManager();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _stickerManager.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStickerPreview(StickerItem sticker) {
    if (sticker.assetPath != null) {
      return SvgPicture.asset(sticker.assetPath!, fit: BoxFit.contain);
    } else if (sticker.filePath != null) {
      final ext = p.extension(sticker.filePath!).toLowerCase();
      if (ext == '.svg') {
        return SvgPicture.file(File(sticker.filePath!), fit: BoxFit.contain);
      } else {
        return Image.file(File(sticker.filePath!), fit: BoxFit.contain);
      }
    }
    return const Icon(Icons.broken_image_rounded);
  }

  Widget _buildGrid(List<StickerItem> stickers, {bool isPersonal = false}) {
    if (stickers.isEmpty && isPersonal) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Aún no tienes stickers personalizados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Importa imágenes o recorta trazos con el lazo',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.onStickerSelected(sticker);
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              children: [
                Expanded(child: _buildStickerPreview(sticker)),
                const SizedBox(height: 4),
                Text(
                  sticker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundled = _stickerManager.bundledStickers;
    final eduStickers = bundled
        .where((s) => s.category == 'educacion')
        .toList();
    final orgStickers = bundled
        .where((s) => s.category == 'organizacion')
        .toList();
    final decStickers = bundled
        .where((s) => s.category == 'decoracion')
        .toList();
    final personalStickers = _stickerManager.customStickers;

    return Container(
      height: 460,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Biblioteca de Stickers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  tooltip: 'Agregar Stickers',
                  onSelected: (value) async {
                    if (value == 'image') {
                      final item = await _stickerManager
                          .importStickerFromImage();
                      if (item != null && mounted) {
                        setState(() {});
                      }
                    } else if (value == 'zip') {
                      final messenger = ScaffoldMessenger.of(context);
                      final count = await _stickerManager.importZipPack();
                      if (count > 0 && mounted) {
                        setState(() {});
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Se importaron $count stickers exitosamente',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'image',
                      child: Row(
                        children: [
                          Icon(Icons.image_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Importar imagen como sticker'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'zip',
                      child: Row(
                        children: [
                          Icon(Icons.folder_zip_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Importar pack comprimido (.zip)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: InkColors.accent,
            tabs: const [
              Tab(text: 'Educación'),
              Tab(text: 'Organización'),
              Tab(text: 'Decoración'),
              Tab(text: 'Mis Stickers'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(eduStickers),
                _buildGrid(orgStickers),
                _buildGrid(decStickers),
                _buildGrid(personalStickers, isPersonal: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
