import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double radius;
  final EdgeInsetsGeometry? margin;

  const ShimmerCircle({super.key, required this.radius, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      margin: margin,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class PostCardShimmer extends StatelessWidget {
  const PostCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  ShimmerCircle(radius: 22),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 120, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 10),
                    ],
                  ),
                ],
              ),
            ),

            // ML Score Badge placeholder
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ShimmerBox(width: 140, height: 24, borderRadius: 12),
            ),

            // Content
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 200, height: 14),
                ],
              ),
            ),

            // Media
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ShimmerBox(
                width: double.infinity,
                height: 200,
                borderRadius: 12,
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ShimmerCircle(radius: 12),
                  const SizedBox(width: 24),
                  const ShimmerCircle(radius: 12),
                  const SizedBox(width: 24),
                  const ShimmerCircle(radius: 12),
                  const Spacer(),
                  const ShimmerCircle(radius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatListItemShimmer extends StatelessWidget {
  const ChatListItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const ShimmerCircle(radius: 28),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 120, height: 16),
                SizedBox(height: 8),
                ShimmerBox(width: double.infinity, height: 14),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShimmerBox(width: 40, height: 12),
              SizedBox(height: 8),
              ShimmerCircle(radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileHeaderShimmer extends StatelessWidget {
  const ProfileHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const ShimmerCircle(radius: 50),
        const SizedBox(height: 16),
        const ShimmerBox(width: 150, height: 20),
        const SizedBox(height: 8),
        const ShimmerBox(width: 100, height: 14),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                ShimmerBox(width: 40, height: 16),
                SizedBox(height: 4),
                ShimmerBox(width: 60, height: 12),
              ],
            ),
            Column(
              children: [
                ShimmerBox(width: 40, height: 16),
                SizedBox(height: 4),
                ShimmerBox(width: 60, height: 12),
              ],
            ),
            Column(
              children: [
                ShimmerBox(width: 40, height: 16),
                SizedBox(height: 4),
                ShimmerBox(width: 60, height: 12),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: ShimmerBox(height: 40, borderRadius: 20)),
              const SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 40, borderRadius: 20)),
            ],
          ),
        ),
      ],
    );
  }
}
