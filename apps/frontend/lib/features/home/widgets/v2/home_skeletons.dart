import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class HomeSkeletons {
  static Widget artistGridSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Column(
            children: [
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFFE0E0E0),
                  highlightColor: const Color(0xFFF5F5F5),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: const Color(0xFFE0E0E0),
                highlightColor: const Color(0xFFF5F5F5),
                child: Container(
                  height: 12,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          childCount: 6,
        ),
      ),
    );
  }

  static Widget songListSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFE0E0E0),
              highlightColor: const Color(0xFFF5F5F5),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          childCount: 4,
        ),
      ),
    );
  }
}
