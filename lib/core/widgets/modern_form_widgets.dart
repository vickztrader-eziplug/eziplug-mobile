import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Modern, reusable form widgets for consistent UI across the app
/// These components are responsive and adapt to different screen sizes

class ModernFormWidgets {
  /// Modern gradient app bar for service screens
  static Widget buildGradientHeader({
    required BuildContext context,
    required String title,
    String? subtitle,
    double? walletBalance,
    bool isLoadingBalance = false,
    Color primaryColor = AppColors.primary,
    VoidCallback? onBack,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
          child: Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
                onPressed: onBack ?? () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (walletBalance != null || isLoadingBalance) ...[
                      const SizedBox(height: 4),
                      isLoadingBalance
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Balance: ₦${_formatBalance(walletBalance!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 44), // Balance for back button
            ],
          ),
        ),
      ),
    );
  }

  /// Modern section label with optional icon
  static Widget buildSectionLabel(
    String label, {
    IconData? icon,
    Color? iconColor,
    Color? textColor,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (iconColor ?? (isDark ? AppColors.primaryLight : AppColors.primary)).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon, 
                  color: iconColor ?? (isDark ? AppColors.primaryLight : AppColors.primary), 
                  size: 14
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor ?? theme.textTheme.titleMedium?.color ?? (isDark ? const Color(0xFFF0F4FF) : AppColors.textColor),
              ),
            ),
          ],
        );
      }
    );
  }

  /// Modern text input field
  static Widget buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? label,
    IconData? prefixIcon,
    Widget? suffixWidget,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    bool readOnly = false,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              buildSectionLabel(label),
              const SizedBox(height: 10),
            ],
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.2) : AppColors.primary.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                maxLines: maxLines,
                maxLength: maxLength,
                readOnly: readOnly,
                onTap: onTap,
                onChanged: onChanged,
                inputFormatters: inputFormatters,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? theme.textTheme.titleMedium?.color,
                  letterSpacing: 0.3,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF5A6178) : Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  counterText: '', // Hide maxLength counter
                  prefixIcon: prefixIcon != null
                      ? Icon(prefixIcon, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20)
                      : null,
                  suffixIcon: suffixIcon ?? suffixWidget,
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF2D3141) : Colors.grey.shade200, 
                      width: 1
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.primaryLight : AppColors.primary, 
                      width: 1.5
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  /// Modern dropdown selector
  static Widget buildDropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) getLabel,
    required void Function(T?) onChanged,
    IconData? prefixIcon,
    bool isLoading = false,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionLabel(label),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.2) : AppColors.primary.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : DropdownButtonFormField<T>(
                      value: value,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded, 
                        color: isDark ? AppColors.primaryLight : AppColors.primary
                      ),
                      dropdownColor: theme.cardColor,
                      decoration: InputDecoration(
                        prefixIcon: prefixIcon != null
                            ? Icon(prefixIcon, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20)
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF2D3141) : Colors.grey.shade200, 
                            width: 1
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.primaryLight : AppColors.primary, 
                            width: 1.5
                          ),
                        ),
                      ),
                      hint: Text(
                        hint,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF8891A5) : Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                      items: items.map((item) {
                        return DropdownMenuItem<T>(
                          value: item,
                          child: Text(
                            getLabel(item),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: onChanged,
                    ),
            ),
          ],
        );
      }
    );
  }

  /// Modern selectable chip/card for options (networks, amounts, etc.)
  static Widget buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    String? imagePath,
    Color? selectedColor,
    double? width,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final color = selectedColor ?? (isDark ? AppColors.primaryLight : AppColors.primary);
        
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.12) : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : (isDark ? const Color(0xFF2D3141) : Colors.grey.shade200),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      imagePath,
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_not_supported,
                        size: 20,
                        color: isDark ? const Color(0xFF5A6178) : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? color : (isDark ? const Color(0xFF8891A5) : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? color : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  /// Modern amount selection grid
  static Widget buildAmountGrid({
    required List<int> amounts,
    required int? selectedAmount,
    required void Function(int) onSelect,
    int crossAxisCount = 4,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: amounts.map((amount) {
            final isSelected = selectedAmount == amount;
            return GestureDetector(
              onTap: () => onSelect(amount),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? (isDark ? AppColors.primaryLight : AppColors.primary) : theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? (isDark ? AppColors.primaryLight : AppColors.primary) : (isDark ? const Color(0xFF2D3141) : Colors.grey.shade200),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '₦${_formatAmount(amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }
    );
  }

  /// Modern network/provider selector grid
  static Widget buildNetworkGrid({
    required List<Map<String, dynamic>> networks,
    required String? selectedId,
    required void Function(String id, String name) onSelect,
    bool isLoading = false,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        if (isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Row(
          children: networks.map((network) {
            final id = network['id'].toString();
            final name = network['name'] as String;
            final assetPath = network['assetPath'] as String?;
            final isSelected = selectedId == id;

            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(id, name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.1) : theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? (isDark ? AppColors.primaryLight : AppColors.primary) : (isDark ? const Color(0xFF2D3141) : Colors.grey.shade200),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (assetPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            assetPath,
                            width: 46,
                            height: 46,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  name.substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        name.length > 6 ? name.substring(0, 6) : name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? (isDark ? AppColors.primaryLight : AppColors.primary) : theme.textTheme.bodySmall?.color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }
    );
  }

  /// Modern primary action button
  static Widget buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Color? backgroundColor,
    IconData? icon,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor ?? (isDark ? AppColors.primaryLight : AppColors.primary),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              disabledBackgroundColor: isDark ? const Color(0xFF2D3141) : Colors.grey.shade300,
            ),
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }
    );
  }

  /// Modern card container for form sections
  static Widget buildFormCard({
    required Widget child,
    EdgeInsets? padding,
    Color? backgroundColor,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      }
    );
  }

  /// Modern info/tip card
  static Widget buildInfoCard({
    required String message,
    IconData icon = Icons.info_outline,
    Color? color,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = color ?? (isDark ? AppColors.primaryLight : AppColors.info);
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: cardColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: cardColor.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  /// Helper to format balance
  static String _formatBalance(double balance) {
    if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(2)}M';
    } else if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(1)}K';
    }
    return balance.toStringAsFixed(2);
  }

  /// Helper to format amount
  static String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return amount.toString();
  }
}
