import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/body_measurements.dart';
import '../../models/mannequin_config.dart';
import '../../providers/avatar_provider.dart';
import '../../services/config_service.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode 
          ? '${ConfigService.instance.getString('strings.setup.title')} (수정)'
          : ConfigService.instance.getString('strings.setup.title')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              config.getString('strings.setup.step1_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              config.getString('strings.setup.step1_description'),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildMannequinSelector(mannequins),
            const SizedBox(height: 32),
            Text(
              config.getString('strings.setup.step2_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              config.getString('strings.setup.step2_description'),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildBodyMeasurementForm(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _createAvatar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(
                _isEditMode
                  ? '수정'
                  : config.getString('strings.setup.create_button'),
                style: const TextStyle(fontSize: 16),
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
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                  width: isSelected ? 3 : 1,
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
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, size: 60),
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
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      mannequin.getDescription(config.locale),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
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
}
