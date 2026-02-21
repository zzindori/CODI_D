/// 워드로브 부위 (사용자에게 노출되는 옷)
/// 
/// 헤어, 상의, 하의, 신발, 악세사리만 워드로브에 표시된다.
class WardrobePart {
  final String id;
  final String category; // 'hair', 'top', 'bottom', 'shoes', 'accessory'
  final String imagePath;
  final DateTime createdAt;
  final String? memo;

  WardrobePart({
    required this.id,
    required this.category,
    required this.imagePath,
    DateTime? createdAt,
    this.memo,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 깊은 복사
  WardrobePart copyWith({
    String? id,
    String? category,
    String? imagePath,
    DateTime? createdAt,
    String? memo,
  }) {
    return WardrobePart(
      id: id ?? this.id,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      memo: memo ?? this.memo,
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'memo': memo,
    };
  }

  /// JSON 역직렬화
  factory WardrobePart.fromJson(Map<String, dynamic> json) {
    return WardrobePart(
      id: json['id'] as String,
      category: json['category'] as String,
      imagePath: json['imagePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      memo: json['memo'] as String?,
    );
  }
}
