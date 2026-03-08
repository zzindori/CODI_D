import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/body_measurements.dart';
import '../../models/mannequin_config.dart';
import '../../providers/avatar_provider.dart';
import '../../services/config_service.dart';
import '../../widgets/codi_styled_app_bar.dart';

/// Stage-0: 마네킹 선택 및 신체 정보 입력 화면
class MannequinSelectionScreen extends StatefulWidget {
  const MannequinSelectionScreen({super.key});

  @override
  State<MannequinSelectionScreen> createState() =>
      _MannequinSelectionScreenState();
}

class _MannequinSelectionScreenState extends State<MannequinSelectionScreen> {
  String? _selectedMannequinId;
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _shoulderController = TextEditingController();
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingAvatar();
  }

  void _loadExistingAvatar() {
    final provider = context.read<AvatarProvider>();
    if (provider.hasAvatar && provider.currentAvatar != null) {
      _isEditMode = true;
      _selectedMannequinId = provider.currentAvatar!.baseMannequinId;
      _heightController.text = provider.currentAvatar!.bodyMeasurements.height.toString();
      _weightController.text = provider.currentAvatar!.bodyMeasurements.weight.toString();
      if (provider.currentAvatar!.bodyMeasurements.shoulderWidth != null) {
        _shoulderController.text = provider.currentAvatar!.bodyMeasurements.shoulderWidth.toString();
      }
      if (provider.currentAvatar!.bodyMeasurements.chestCircumference != null) {
        _chestController.text = provider.currentAvatar!.bodyMeasurements.chestCircumference.toString();
      }
      if (provider.currentAvatar!.bodyMeasurements.waistCircumference != null) {
        _waistController.text = provider.currentAvatar!.bodyMeasurements.waistCircumference.toString();
      }
      if (provider.currentAvatar!.bodyMeasurements.hipCircumference != null) {
        _hipController.text = provider.currentAvatar!.bodyMeasurements.hipCircumference.toString();
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _shoulderController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  void _createAvatar() async {
    if (_selectedMannequinId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ConfigService.instance.getString(
              'strings.setup.select_mannequin_error',
            ),
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final measurements = BodyMeasurements(
      height: double.parse(_heightController.text),
      weight: double.parse(_weightController.text),
      shoulderWidth: _parseOptionalDouble(_shoulderController.text),
      chestCircumference: _parseOptionalDouble(_chestController.text),
      waistCircumference: _parseOptionalDouble(_waistController.text),
      hipCircumference: _parseOptionalDouble(_hipController.text),
    );

    final provider = context.read<AvatarProvider>();
    
    if (_isEditMode) {
      // 수정 모드: 기존 아바타 업데이트
      await provider.updateAvatar(
        mannequinId: _selectedMannequinId!,
        measurements: measurements,
      );
    } else {
      // 신규 모드: 새로운 아바타 생성
      await provider.createInitialAvatar(
        mannequinId: _selectedMannequinId!,
        measurements: measurements,
      );
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance;
    final mannequins = config.mannequins;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CodiStyledAppBar(
        title: ConfigService.instance.getString('strings.setup.title'),
        actions: [
          CodiAppBarAction(
            tooltip: '옷장',
            icon: Icons.checkroom,
            onTap: () => Navigator.of(context).pushNamed('/wardrobe'),
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionCard(
              context,
              title: config.getString('strings.setup.step1_title'),
              description: config.getString('strings.setup.step1_description'),
              child: _buildMannequinSelector(mannequins),
            ),
            const SizedBox(height: 32),
            _buildSectionCard(
              context,
              title: config.getString('strings.setup.step2_title'),
              description: config.getString('strings.setup.step2_description'),
              child: _buildBodyMeasurementForm(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _createAvatar,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isEditMode ? '수정' : config.getString('strings.setup.create_button'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            SafeArea(
              top: false,
              child: const SizedBox(height: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMannequinSelector(List<MannequinConfig> mannequins) {
    final config = ConfigService.instance;
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mannequins.length,
        itemBuilder: (context, index) {
          final mannequin = mannequins[index];
          final isSelected = _selectedMannequinId == mannequin.id;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMannequinId = mannequin.id;
              });
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primaryContainer.withValues(alpha: 0.35)
                    : colors.surface,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 실제 이미지 로드
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        mannequin.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: colors.surfaceContainerHighest,
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: colors.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mannequin.getDisplayName(config.locale),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colors.primary : colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      mannequin.getDescription(config.locale),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodyMeasurementForm() {
    final config = ConfigService.instance;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _heightController,
                  label: config.getString('strings.body_measurements.height'),
                  icon: Icons.height,
                  requiredField: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildNumberField(
                  controller: _weightController,
                  label: config.getString('strings.body_measurements.weight'),
                  icon: Icons.monitor_weight,
                  requiredField: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _shoulderController,
            label: config.getString('strings.body_measurements.shoulder_width'),
            icon: Icons.width_normal,
            requiredField: false,
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _chestController,
            label: config.getString('strings.body_measurements.chest'),
            icon: Icons.circle_outlined,
            requiredField: false,
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _waistController,
            label: config.getString('strings.body_measurements.waist'),
            icon: Icons.circle_outlined,
            requiredField: false,
          ),
          const SizedBox(height: 16),
          _buildNumberField(
            controller: _hipController,
            label: config.getString('strings.body_measurements.hip'),
            icon: Icons.circle_outlined,
            requiredField: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool requiredField,
  }) {
    final config = ConfigService.instance;
    final colors = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        labelText: label,
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        prefixIcon: Icon(icon, color: colors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
      validator: (value) {
        if (requiredField && (value == null || value.isEmpty)) {
          return config.getString('strings.body_measurements.validation_required');
        }
        if (value == null || value.isEmpty) {
          return null;
        }
        if (double.tryParse(value) == null) {
          return config.getString('strings.body_measurements.validation_number');
        }
        return null;
      },
    );
  }

  double? _parseOptionalDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value);
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String description,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
