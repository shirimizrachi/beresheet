import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Web-optimized image cache service
/// Uses browser's native caching for web platform and CachedNetworkImage for mobile
class WebImageCacheService {
  /// Creates an optimized image widget for the current platform
  /// 
  /// For web: Uses Image.network with proper cache headers
  /// For mobile: Uses CachedNetworkImage
  static Widget buildEventImage({
    required String? imageUrl,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    // Default placeholder for event image
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.event,
        size: _calculateIconSize(width, height),
        color: Colors.grey[600],
      ),
    );

    // Default error widget for event image
    final defaultErrorWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.broken_image,
        size: _calculateIconSize(width, height),
        color: Colors.red[400],
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return defaultPlaceholder;
    }

    Widget imageWidget;

    if (kIsWeb) {
      // For web: Use Image.network with optimized caching
      imageWidget = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        // Add cache headers for better browser caching
        headers: const {
          'Cache-Control': 'public, max-age=31536000', // Cache for 1 year
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return placeholder ?? defaultPlaceholder;
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? defaultErrorWidget;
        },
        // Enable browser-level caching
        isAntiAlias: true,
        filterQuality: FilterQuality.medium,
      );
    } else {
      // For mobile: Use CachedNetworkImage
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? defaultPlaceholder,
        errorWidget: (context, url, error) => errorWidget ?? defaultErrorWidget,
        memCacheWidth: width?.isFinite == true ? width!.toInt() : null,
        memCacheHeight: height?.isFinite == true ? height!.toInt() : null,
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 1200,
        // Additional web optimizations
        httpHeaders: const {
          'Cache-Control': 'public, max-age=31536000',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        },
      );
    }

    // Apply border radius if provided
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Creates an optimized image widget for user profile photos
  static Widget buildUserProfileImage({
    required String? imageUrl,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    // Default placeholder for user profile
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.person,
        size: _calculateIconSize(width, height),
        color: Colors.grey[600],
      ),
    );

    // Default error widget for user profile
    final defaultErrorWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.person_off,
        size: _calculateIconSize(width, height),
        color: Colors.red[400],
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return defaultPlaceholder;
    }

    Widget imageWidget;

    if (kIsWeb) {
      // For web: Use Image.network with optimized caching
      imageWidget = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        headers: const {
          'Cache-Control': 'public, max-age=31536000',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return placeholder ?? defaultPlaceholder;
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? defaultErrorWidget;
        },
        isAntiAlias: true,
        filterQuality: FilterQuality.medium,
      );
    } else {
      // For mobile: Use CachedNetworkImage
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? defaultPlaceholder,
        errorWidget: (context, url, error) => errorWidget ?? defaultErrorWidget,
        memCacheWidth: width?.isFinite == true ? width!.toInt() : null,
        memCacheHeight: height?.isFinite == true ? height!.toInt() : null,
        maxWidthDiskCache: 800,
        maxHeightDiskCache: 800,
        httpHeaders: const {
          'Cache-Control': 'public, max-age=31536000',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        },
      );
    }

    // Apply border radius if provided
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Creates a circular image widget for user avatars
  static Widget buildCircularUserImage({
    required String? imageUrl,
    required double radius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return buildUserProfileImage(
      imageUrl: imageUrl,
      width: radius * 2,
      height: radius * 2,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: BorderRadius.circular(radius),
      fit: BoxFit.cover,
    );
  }

  /// Pre-caches an image URL for faster loading later
  static Future<void> precacheImageUrl(BuildContext context, String imageUrl) async {
    if (imageUrl.isEmpty) return;
    
    try {
      if (kIsWeb) {
        // For web: Use browser's precaching
        await precacheImage(
          NetworkImage(imageUrl, headers: const {
            'Cache-Control': 'public, max-age=31536000',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
          }),
          context,
        );
      } else {
        // For mobile: Use CachedNetworkImage precaching
        await precacheImage(CachedNetworkImageProvider(imageUrl), context);
      }
    } catch (e) {
      debugPrint('Failed to precache image: $imageUrl, Error: $e');
    }
  }

  /// Pre-caches a list of image URLs
  static Future<void> precacheImages(BuildContext context, List<String> imageUrls) async {
    for (String url in imageUrls) {
      if (url.isNotEmpty) {
        await precacheImageUrl(context, url);
      }
    }
  }

  /// Clears the image cache (web browsers handle this automatically)
  static Future<void> clearCache() async {
    if (!kIsWeb) {
      await CachedNetworkImage.evictFromCache('');
    }
    // Web browsers manage their own cache
  }

  /// Clears cache for a specific image URL
  static Future<void> evictFromCache(String imageUrl) async {
    if (imageUrl.isNotEmpty && !kIsWeb) {
      await CachedNetworkImage.evictFromCache(imageUrl);
    }
    // Web browsers manage their own cache
  }

  /// Helper method to calculate icon size
  static double _calculateIconSize(double? width, double? height) {
    if (width != null && height != null) {
      final calculatedSize = (width + height) / 4;
      return calculatedSize.isFinite && calculatedSize > 0 ? calculatedSize.toDouble() : 40.0;
    }
    return 40.0;
  }
}
