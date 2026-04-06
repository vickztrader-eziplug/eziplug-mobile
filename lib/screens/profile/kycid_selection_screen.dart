// 3. KYC ID Selection Screen
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class KYCIDSelectionScreen extends StatefulWidget {
  const KYCIDSelectionScreen({super.key});

  @override
  State<KYCIDSelectionScreen> createState() => _KYCIDSelectionScreenState();
}

class _KYCIDSelectionScreenState extends State<KYCIDSelectionScreen> {
  String? _selectedIDType;

  final List<Map<String, dynamic>> _idTypes = [
    {'name': 'NIN Card / Slip', 'icon': Icons.credit_card, 'value': 'nin'},
    {
      'name': 'Driver\'s License',
      'icon': Icons.card_membership,
      'value': 'drivers_license',
    },
    {'name': 'BVN Number', 'icon': Icons.numbers, 'value': 'bvn'},
    {'name': 'Passport', 'icon': Icons.book, 'value': 'passport'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? AppColors.headerDark : AppColors.primary,
                    isDark ? AppColors.headerDark : AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'Select ID Type',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section with curved top
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select ID type',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.titleLarge?.color ?? AppColors.textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose the type of identification document you want to upload',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color ?? AppColors.textColor.withOpacity(0.7),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ID Type Options
                            ..._idTypes.map((idType) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildIDTypeOption(
                                  idType['name'],
                                  idType['icon'],
                                  idType['value'],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    // Continue Button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selectedIDType != null
                              ? () {
                                  // Return the selected ID type to the previous screen
                                  Navigator.pop(context, _selectedIDType);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textColor,
                            disabledBackgroundColor: AppColors.lightGrey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIDTypeOption(String name, IconData icon, String value) {
    final isSelected = _selectedIDType == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIDType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade800 : AppColors.lightGrey),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : (isDark ? Colors.grey.shade800 : AppColors.textColor.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : theme.textTheme.titleMedium?.color ?? AppColors.textColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : theme.textTheme.titleMedium?.color ?? AppColors.textColor,
                ),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedIDType,
              onChanged: (value) {
                setState(() {
                  _selectedIDType = value;
                });
              },
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
