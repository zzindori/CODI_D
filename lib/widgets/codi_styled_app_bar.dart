import 'package:flutter/material.dart';

class CodiAppBarAction {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const CodiAppBarAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
}

class CodiStyledAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<CodiAppBarAction> actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  static const double _barHeight = 56;
  static const double _verticalInset = 2;

  const CodiStyledAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBackButton = true,
    this.onBack,
    this.bottom,
  });

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(_barHeight + (_verticalInset * 2) + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                _verticalInset,
                12,
                _verticalInset,
              ),
              child: Container(
                height: _barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surfaceBright.withValues(alpha: 0.98),
                      colors.primaryContainer.withValues(alpha: 0.97),
                      colors.inversePrimary.withValues(alpha: 0.95),
                      colors.primary.withValues(alpha: 0.86),
                    ],
                    stops: const [0.0, 0.32, 0.72, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.98),
                    width: 1.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: colors.surfaceBright.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (showBackButton)
                      _CodiAppBarCircleAction(
                        tooltip: '홈',
                        icon: Icons.home_outlined,
                        onTap:
                            onBack ??
                            () => Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/home', (route) => false),
                      )
                    else
                      const SizedBox(width: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ...List.generate(actions.length, (index) {
                        final action = actions[index];
                        return Padding(
                          padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                          child: _CodiAppBarCircleAction(
                            tooltip: action.tooltip,
                            icon: action.icon,
                            onTap: action.onTap,
                          ),
                        );
                      }),
                    ] else
                      const SizedBox(width: 36),
                  ],
                ),
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

class _CodiAppBarCircleAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _CodiAppBarCircleAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: CustomPaint(
          painter: _TopCircleGradientBorderPainter(
            topColor: colors.surfaceBright.withValues(alpha: 0.92),
            bottomColor: colors.primary.withValues(alpha: 0.86),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surfaceBright.withValues(alpha: 0.98),
                  colors.primaryContainer.withValues(alpha: 0.95),
                  colors.primary.withValues(alpha: 0.78),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: colors.surfaceBright.withValues(alpha: 0.62),
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Icon(icon, color: colors.onPrimaryContainer, size: 23),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCircleGradientBorderPainter extends CustomPainter {
  final Color topColor;
  final Color bottomColor;

  _TopCircleGradientBorderPainter({
    required this.topColor,
    required this.bottomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(rect);

    final radius = (size.shortestSide / 2) - (paint.strokeWidth / 2);
    canvas.drawCircle(rect.center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _TopCircleGradientBorderPainter oldDelegate) {
    return oldDelegate.topColor != topColor ||
        oldDelegate.bottomColor != bottomColor;
  }
}
