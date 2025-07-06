import 'package:flutter/material.dart';
import 'package:beresheet_app/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: [AppShadows.cardShadow],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        child: card,
      );
    }

    return card;
  }
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
          padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.small),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: AppTextStyles.buttonText,
              ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String labelText;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;

  const AppTextField({
    super.key,
    required this.labelText,
    this.hintText,
    this.controller,
    this.validator,
    this.onSaved,
    this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onSaved: onSaved,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.primary) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

class ActivityChip extends StatelessWidget {
  final String activity;
  final bool isSelected;
  final VoidCallback onTap;

  const ActivityChip({
    super.key,
    required this.activity,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activityColor = ActivityTypeHelper.getColor(activity);
    final displayName = ActivityTypeHelper.getDisplayName(activity, context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.circular),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activityColor : activityColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.circular),
          border: Border.all(
            color: activityColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ActivityTypeHelper.getIcon(activity),
              size: 16,
              color: isSelected ? Colors.white : activityColor,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              displayName,
              style: AppTextStyles.chipText.copyWith(
                color: isSelected ? Colors.white : activityColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({
    super.key,
    this.size = 60,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: size,
          width: size,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.apartment,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        if (showText) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'בראשית',
            style: AppTextStyles.heading4,
          ),
          Text(
            'קהילת מגורים',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [AppShadows.cardShadow],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const AppLogo(size: 50),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.heading3),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  const AppBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.accent,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}