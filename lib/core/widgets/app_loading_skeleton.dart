import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Neutral, non-circular loading state shared by SWS pages.
class AppLoadingSkeleton extends StatelessWidget {
  const AppLoadingSkeleton({super.key, this.rows = 5, this.showHeader = true});
  final int rows;
  final bool showHeader;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (showHeader) ...[
        const _SkeletonBar(width: 210, height: 22),
        const SizedBox(height: 10),
        const _SkeletonBar(width: 240, height: 12),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth < 600 ? 2 : 4;
            return GridView.count(
              crossAxisCount: count,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: List.generate(
                count,
                (_) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBar(width: 38, height: 20),
                      Spacer(),
                      SizedBox(height: 8),
                      _SkeletonBar(width: 55, height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
      ...List.generate(
        rows,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const _SkeletonBar(width: 46, height: 46, radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBar(width: 130.0 + (index % 3) * 35, height: 11),
                    const SizedBox(height: 10),
                    const _SkeletonBar(width: 190, height: 8),
                    const SizedBox(height: 8),
                    const _SkeletonBar(width: 100, height: 8),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _SkeletonBar(width: 72, height: 24),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    this.radius = 8,
  });
  final double width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE9EFEB),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class AppLoadingRows extends StatelessWidget {
  const AppLoadingRows({super.key, this.rows = 3});
  final int rows;
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      rows,
      (index) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const _SkeletonBar(width: 34, height: 34, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 130.0 + (index % 2) * 45, height: 9),
                  const SizedBox(height: 8),
                  const _SkeletonBar(width: 90, height: 7),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
