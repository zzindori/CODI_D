import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/my_avatar.dart';
import '../models/clothing_item.dart';
import '../models/codi_record.dart';

/// 로컬 저장소 서비스
class StorageService {
  static const String _keyAvatar = 'my_avatar';
  static const String _keyClothes = 'clothes';
  static const String _keyRecords = 'codi_records';

  /// MyAvatar 저장
  Future<void> saveAvatar(MyAvatar avatar) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(avatar.toJson());
    await prefs.setString(_keyAvatar, json);
  }

  /// MyAvatar 불러오기
  Future<MyAvatar?> loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyAvatar);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return MyAvatar.fromJson(json);
    } catch (e) {
      // Error loading avatar: $e
      return null;
    }
  }

  /// 옷 목록 저장
  Future<void> saveClothes(List<ClothingItem> clothes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = clothes.map((item) => item.toJson()).toList();
    await prefs.setString(_keyClothes, jsonEncode(jsonList));
  }

  /// 옷 목록 불러오기
  Future<List<ClothingItem>> loadClothes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyClothes);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => ClothingItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Error loading clothes: $e
      return [];
    }
  }

  /// 코디 기록 저장
  Future<void> saveRecords(List<CodiRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((record) => record.toJson()).toList();
    await prefs.setString(_keyRecords, jsonEncode(jsonList));
  }

  /// 코디 기록 불러오기
  Future<List<CodiRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyRecords);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => CodiRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Error loading records: $e
      return [];
    }
  }

  /// 모든 데이터 삭제 (초기화)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
