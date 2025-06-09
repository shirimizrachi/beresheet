import 'package:flutter/material.dart';
import 'package:beresheet_app/config/app_config.dart';

/// Utility class for handling RTL/LTR layout and positioning
class DirectionUtils {
  /// Get the current text direction from app config
  static TextDirection get textDirection => AppConfig.textDirection;
  
  /// Check if the app is using RTL direction
  static bool get isRTL => AppConfig.isRTL;
  
  /// Check if the app is using LTR direction
  static bool get isLTR => AppConfig.isLTR;

  /// Get appropriate alignment based on text direction
  /// For RTL: returns Alignment.topRight
  /// For LTR: returns Alignment.topLeft
  static Alignment get startAlignment => isRTL ? Alignment.topRight : Alignment.topLeft;
  
  /// Get appropriate alignment based on text direction
  /// For RTL: returns Alignment.topLeft
  /// For LTR: returns Alignment.topRight
  static Alignment get endAlignment => isRTL ? Alignment.topLeft : Alignment.topRight;

  /// Get appropriate MainAxisAlignment for start
  /// For RTL: returns MainAxisAlignment.end
  /// For LTR: returns MainAxisAlignment.start
  static MainAxisAlignment get mainAxisAlignmentStart => 
      isRTL ? MainAxisAlignment.end : MainAxisAlignment.start;

  /// Get appropriate MainAxisAlignment for end
  /// For RTL: returns MainAxisAlignment.start
  /// For LTR: returns MainAxisAlignment.end
  static MainAxisAlignment get mainAxisAlignmentEnd => 
      isRTL ? MainAxisAlignment.start : MainAxisAlignment.end;

  /// Get appropriate CrossAxisAlignment for start
  /// For RTL: returns CrossAxisAlignment.end
  /// For LTR: returns CrossAxisAlignment.start
  static CrossAxisAlignment get crossAxisAlignmentStart => 
      isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start;

  /// Get appropriate CrossAxisAlignment for end
  /// For RTL: returns CrossAxisAlignment.start
  /// For LTR: returns CrossAxisAlignment.end
  static CrossAxisAlignment get crossAxisAlignmentEnd => 
      isRTL ? CrossAxisAlignment.start : CrossAxisAlignment.end;

  /// Get appropriate TextAlign for start
  /// For RTL: returns TextAlign.right
  /// For LTR: returns TextAlign.left
  static TextAlign get textAlignStart => isRTL ? TextAlign.right : TextAlign.left;

  /// Get appropriate TextAlign for end
  /// For RTL: returns TextAlign.left
  /// For LTR: returns TextAlign.right
  static TextAlign get textAlignEnd => isRTL ? TextAlign.left : TextAlign.right;

  /// Get appropriate EdgeInsets for start padding
  /// Example: EdgeInsets.only(left: value) for LTR, EdgeInsets.only(right: value) for RTL
  static EdgeInsets paddingStart(double value) => 
      isRTL ? EdgeInsets.only(right: value) : EdgeInsets.only(left: value);

  /// Get appropriate EdgeInsets for end padding
  /// Example: EdgeInsets.only(right: value) for LTR, EdgeInsets.only(left: value) for RTL
  static EdgeInsets paddingEnd(double value) => 
      isRTL ? EdgeInsets.only(left: value) : EdgeInsets.only(right: value);

  /// Get appropriate EdgeInsets for horizontal padding (start, end)
  static EdgeInsets paddingHorizontal(double start, double end) => 
      isRTL 
          ? EdgeInsets.only(right: start, left: end)
          : EdgeInsets.only(left: start, right: end);

  /// Get margin for start side
  static EdgeInsets marginStart(double value) => 
      isRTL ? EdgeInsets.only(right: value) : EdgeInsets.only(left: value);

  /// Get margin for end side
  static EdgeInsets marginEnd(double value) => 
      isRTL ? EdgeInsets.only(left: value) : EdgeInsets.only(right: value);

  /// Get margin for horizontal sides (start, end)
  static EdgeInsets marginHorizontal(double start, double end) => 
      isRTL 
          ? EdgeInsets.only(right: start, left: end)
          : EdgeInsets.only(left: start, right: end);

  /// Get appropriate BorderRadius for start
  static BorderRadius borderRadiusStart(double radius) => 
      isRTL 
          ? BorderRadius.only(topRight: Radius.circular(radius), bottomRight: Radius.circular(radius))
          : BorderRadius.only(topLeft: Radius.circular(radius), bottomLeft: Radius.circular(radius));

  /// Get appropriate BorderRadius for end
  static BorderRadius borderRadiusEnd(double radius) => 
      isRTL 
          ? BorderRadius.only(topLeft: Radius.circular(radius), bottomLeft: Radius.circular(radius))
          : BorderRadius.only(topRight: Radius.circular(radius), bottomRight: Radius.circular(radius));

  /// Helper to get proper icon for navigation based on direction
  /// For "back" navigation: returns arrow_forward for RTL, arrow_back for LTR
  static IconData get backIcon => isRTL ? Icons.arrow_forward : Icons.arrow_back;

  /// Helper to get proper icon for navigation based on direction
  /// For "forward" navigation: returns arrow_back for RTL, arrow_forward for LTR
  static IconData get forwardIcon => isRTL ? Icons.arrow_back : Icons.arrow_forward;

  /// Helper method to wrap widget with Directionality if needed
  static Widget wrapWithDirection(Widget child) {
    return Directionality(
      textDirection: textDirection,
      child: child,
    );
  }

  /// Get appropriate transform for icons that need to be flipped in RTL
  static Matrix4? getIconTransform() {
    if (isRTL) {
      return Matrix4.identity()..scale(-1.0, 1.0, 1.0);
    }
    return null;
  }
}