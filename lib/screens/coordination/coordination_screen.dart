import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wardrobe_provider.dart';
import '../../models/simple_clothing_item.dart';

/// 코디 생성 화면 (v3.0)
/// 
/// 원칙:
/// - 옷장에서 옷 선택 (상의 + 하의 + 신발)
/// - "코디 생성" 버튼 → Gemini 프롬프트 생성 → Stability API 호출
/// - 마네킹 착장 이미지 생성 (사용자가 보여준 6컷 예시처럼)
class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({super.key});

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  String? _selectedTopId;
  String? _selectedBottomId;
  String? _selectedShoesId;
  
  bool _isGenerating = false;
  String? _generatedImagePath;
  String? _errorMessage;

  Future<void> _generateCoordination() async {
    if (_selectedTopId == null && _selectedBottomId == null && _selectedShoesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 한 개 이상의 옷을 선택해주세요')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final wardrobeProvider = context.read<WardrobeProvider>();
      final items = wardrobeProvider.simpleItems;

      // 선택된 아이템 찾기
      final selectedItems = <SimpleClothingItem>[];
      if (_selectedTopId != null) {
        final top = items.firstWhere((item) => item.id == _selectedTopId);
        selectedItems.add(top);
      }
      if (_selectedBottomId != null) {
        final bottom = items.firstWhere((item) => item.id == _selectedBottomId);
        selectedItems.add(bottom);
      }
      if (_selectedShoesId != null) {
        final shoes = items.firstWhere((item) => item.id == _selectedShoesId);
        selectedItems.add(shoes);
      }

      // TODO: Gemini로 코디 프롬프트 생성
      // TODO: Stability API로 마네킹 이미지 생성
      // 임시로 첫 번째 아이템 이미지 표시
      setState(() {
        _generatedImagePath = selectedItems.first.photoPath;
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코디 생성 완료! (임시 구현)')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobeProvider = context.watch<WardrobeProvider>();
    final items = wardrobeProvider.simpleItems;

    // 카테고리별 필터링
    final tops = items.where((item) => 
      item.itemType.toLowerCase().contains('top') || 
      item.itemType.toLowerCase().contains('shirt') ||
      item.itemType.toLowerCase().contains('jacket')
    ).toList();
    
    final bottoms = items.where((item) => 
      item.itemType.toLowerCase().contains('bottom') || 
      item.itemType.toLowerCase().contains('pants') ||
      item.itemType.toLowerCase().contains('skirt')
    ).toList();
    
    final shoes = items.where((item) => 
      item.itemType.toLowerCase().contains('shoes') || 
      item.itemType.toLowerCase().contains('sneaker') ||
      item.itemType.toLowerCase().contains('boot')
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 코디 생성'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '옷을 선택하면 AI가 마네킹에 입혀서 보여드립니다',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // 상의 선택
                    _buildCategorySelector(
                      title: '상의',
                      items: tops,
                      selectedId: _selectedTopId,
                      onSelect: (id) => setState(() => _selectedTopId = id),
                    ),
                    const SizedBox(height: 16),
                    
                    // 하의 선택
                    _buildCategorySelector(
                      title: '하의',
                      items: bottoms,
                      selectedId: _selectedBottomId,
                      onSelect: (id) => setState(() => _selectedBottomId = id),
                    ),
                    const SizedBox(height: 16),
                    
                    // 신발 선택
                    _buildCategorySelector(
                      title: '신발',
                      items: shoes,
                      selectedId: _selectedShoesId,
                      onSelect: (id) => setState(() => _selectedShoesId = id),
                    ),
                    const SizedBox(height: 24),
                    
                    // 생성된 이미지
                    if (_generatedImagePath != null) ...[
                      const Text('생성된 코디', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        height: 400,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_generatedImagePath!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // 에러 메시지
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateCoordination,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isGenerating ? '생성 중...' : 'AI 코디 생성'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector({
    required String title,
    required List<SimpleClothingItem> items,
    required String? selectedId,
    required ValueChanged<String?> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '(${items.length})',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '해당 카테고리의 옷이 없습니다',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item.id == selectedId;
                
                return GestureDetector(
                  onTap: () => onSelect(isSelected ? null : item.id),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(item.photoPath),
                            fit: BoxFit.cover,
                          ),
                          if (isSelected)
                            Container(
                              color: Colors.blue.withValues(alpha: 0.3),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
