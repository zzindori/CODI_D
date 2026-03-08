import 'package:json_annotation/json_annotation.dart';
import 'codi_score.dart';

part 'codi_record.g.dart';

/// 코디 기록
@JsonSerializable()
class CodiRecord {
  final String id;
  final DateTime createdAt;

  /// 상의 ID
  final String topId;

  /// 외투 ID
  final String? outerwearId;

  /// 하의 ID
  final String bottomId;

  /// 합성된 코디 이미지 경로 (아바타 + 옷)
  final String composedImagePath;

  /// 코디 점수
  final CodiScore score;

  /// 메모
  final String? memo;

  /// 착용했는지 여부
  final bool worn;

  /// 착용 날짜
  final DateTime? wornDate;

  CodiRecord({
    required this.id,
    DateTime? createdAt,
    required this.topId,
    this.outerwearId,
    required this.bottomId,
    required this.composedImagePath,
    required this.score,
    this.memo,
    this.worn = false,
    this.wornDate,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CodiRecord.fromJson(Map<String, dynamic> json) =>
      _$CodiRecordFromJson(json);

  Map<String, dynamic> toJson() => _$CodiRecordToJson(this);

  CodiRecord copyWith({
    CodiScore? score,
    String? memo,
    bool? worn,
    DateTime? wornDate,
  }) {
    return CodiRecord(
      id: id,
      createdAt: createdAt,
      topId: topId,
      outerwearId: outerwearId,
      bottomId: bottomId,
      composedImagePath: composedImagePath,
      score: score ?? this.score,
      memo: memo ?? this.memo,
      worn: worn ?? this.worn,
      wornDate: wornDate ?? this.wornDate,
    );
  }
}
