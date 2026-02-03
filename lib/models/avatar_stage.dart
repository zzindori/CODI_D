/// 아바타 진화 단계
enum AvatarStage {
  /// Stage-0: 고정 마네킹 선택
  anchor(0, 'Anchor Stage'),

  /// Stage-1: 실루엣 진화 (사진 기반)
  silhouette(1, 'Silhouette Evolution'),

  /// Stage-2+: 옷 레이어 및 디테일
  layered(2, 'Layer & Detail');

  final int level;
  final String description;

  const AvatarStage(this.level, this.description);
}
