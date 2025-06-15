import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Service for handling image caching throughout the application
/// Provides centralized image loading with automatic caching for user photos and event images
class ImageCacheService {
  /// Default cache duration for images (7 days)
  static const Duration _defaultCacheDuration = Duration(days: 7);
  
  /// Maximum cache size in MB
  static const int _maxCacheSize = 100;
  
  /// Creates a cached network image widget for user profile photos
  /// 
  /// [imageUrl] - URL of the user profile photo
  /// [width] - Width of the image widget
  /// [height] - Height of the image widget
  /// [placeholder] - Widget to show while loading
  /// [errorWidget] - Widget to show on error
  /// [fit] - How the image should be inscribed into the space
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
        size: (width != null && height != null) ? (width + height) / 4 : 40,
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
        size: (width != null && height != null) ? (width + height) / 4 : 40,
        color: Colors.red[400],
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return defaultPlaceholder;
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? defaultErrorWidget,
      memCacheWidth: width?.isFinite == true ? width!.toInt() : null,
      memCacheHeight: height?.isFinite == true ? height!.toInt() : null,
      maxWidthDiskCache: 800, // Limit disk cache size for profile images
      maxHeightDiskCache: 800,
    );

    // Apply border radius if provided
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Creates a cached network image widget for event images
  /// 
  /// [imageUrl] - URL of the event image
  /// [width] - Width of the image widget
  /// [height] - Height of the image widget
  /// [placeholder] - Widget to show while loading
  /// [errorWidget] - Widget to show on error
  /// [fit] - How the image should be inscribed into the space
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
        size: () {
          if (width != null && height != null) {
            final calculatedSize = (width! + height!) / 4;
            print('DEBUG: Icon size calculation - width: $width, height: $height, calculatedSize: $calculatedSize, isFinite: ${calculatedSize.isFinite}');
            return calculatedSize.isFinite && calculatedSize > 0 ? calculatedSize.toDouble() : 40.0;
          }
          print('DEBUG: Using default icon size: 40');
          return 40.0;
        }(),
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
        size: () {
          if (width != null && height != null) {
            final calculatedSize = (width! + height!) / 4;
            print('DEBUG: Error icon size calculation - width: $width, height: $height, calculatedSize: $calculatedSize, isFinite: ${calculatedSize.isFinite}');
            return calculatedSize.isFinite && calculatedSize > 0 ? calculatedSize.toDouble() : 40.0;
          }
          print('DEBUG: Using default error icon size: 40');
          return 40.0;
        }(),
        color: Colors.red[400],
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return defaultPlaceholder;
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? defaultErrorWidget,
      memCacheWidth: width?.isFinite == true ? width!.toInt() : null,
      memCacheHeight: height?.isFinite == true ? height!.toInt() : null,
      maxWidthDiskCache: 1200, // Higher resolution for event images
      maxHeightDiskCache: 1200,
    );

    // Apply border radius if provided
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Creates a circular cached network image widget for user avatars
  /// 
  /// [imageUrl] - URL of the user photo
  /// [radius] - Radius of the circular image
  /// [placeholder] - Widget to show while loading
  /// [errorWidget] - Widget to show on error
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
  ///
  /// [context] - Build context for pre-caching
  /// [imageUrl] - URL of the image to pre-cache
  static Future<void> precacheImageUrl(BuildContext context, String imageUrl) async {
    if (imageUrl.isEmpty) return;
    
    try {
      await precacheImage(CachedNetworkImageProvider(imageUrl), context);
    } catch (e) {
      // Silently handle pre-cache failures
      debugPrint('Failed to precache image: $imageUrl, Error: $e');
    }
  }

  /// Pre-caches a list of image URLs
  ///
  /// [context] - Build context for pre-caching
  /// [imageUrls] - List of image URLs to pre-cache
  static Future<void> precacheImages(BuildContext context, List<String> imageUrls) async {
    for (String url in imageUrls) {
      if (url.isNotEmpty) {
        await precacheImageUrl(context, url);
      }
    }
  }

  /// Clears the entire image cache
  static Future<void> clearCache() async {
    await CachedNetworkImage.evictFromCache('');
  }

  /// Clears cache for a specific image URL
  /// 
  /// [imageUrl] - URL of the image to remove from cache
  static Future<void> evictFromCache(String imageUrl) async {
    if (imageUrl.isNotEmpty) {
      await CachedNetworkImage.evictFromCache(imageUrl);
    }
  }

  /// Gets cache size information
  static Future<String> getCacheSize() async {
    // Note: CachedNetworkImage doesn't provide direct cache size info
    // This would need additional implementation with the cache manager
    return 'Cache size information not available';
  }
}