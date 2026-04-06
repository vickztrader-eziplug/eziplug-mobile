// 1. KYC Tier 1 Screen
import 'dart:io';
import 'package:cashpoint/screens/profile/kyc_tier2_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';

class KYCTier1Screen extends StatefulWidget {
  const KYCTier1Screen({super.key});

  @override
  State<KYCTier1Screen> createState() => _KYCTier1ScreenState();
}

class _KYCTier1ScreenState extends State<KYCTier1Screen> {
  bool _isLoadingUserData = true;
  bool _isUploadingPhoto = false;

  // User data
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String _userProfilePicture = '';

  // KYC Status
  bool _tier1Completed = false;
  String? _tier2Status; // null, 'pending', 'approved', 'rejected'
  String? _tier3Status; // null, 'pending', 'approved', 'rejected'

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() => _isLoadingUserData = false);
        return;
      }

      final response = await http.get(
        Uri.parse(Constants.user),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data;

        if (mounted) {
          setState(() {
            _userName = userData['firstName'] ?? '';
            _userEmail = userData['email'] ?? '';
            _userPhone = userData['phone'] ?? '';
            _userProfilePicture =
                userData['profile'] ?? userData['avatar'] ?? '';

            // Check KYC status from backend
            _tier1Completed =
                userData['kyc_tier1_completed'] == true ||
                userData['kyc_tier_1'] == 'approved' ||
                (_userName.isNotEmpty &&
                    _userEmail.isNotEmpty &&
                    _userPhone.isNotEmpty);

            // Get tier 2 and 3 status
            _tier2Status =
                userData['kyc_tier2_status'] ?? userData['kyc_tier_2'];
            _tier3Status =
                userData['kyc_tier3_status'] ?? userData['kyc_tier_3'];

            _isLoadingUserData = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
    }
  }

    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: theme.cardColor,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Profile Photo',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to upload photo
  Future<void> _uploadPhoto(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.baseUrl}/passport'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add photo file
      request.files.add(
        await http.MultipartFile.fromPath('photo', pickedFile.path),
      );

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        setState(() => _isUploadingPhoto = false);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);

          // Update profile picture
          setState(() {
            _userProfilePicture =
                responseData['profile'] ??
                responseData['avatar'] ??
                responseData['photo'] ??
                '';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseData['message'] ?? 'Profile photo updated successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh user data
          _fetchUserData();
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Failed to upload photo');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
                              'Upgrade (Tier 1)',
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
                child: _isLoadingUserData
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Complete Your KYC',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.titleLarge?.color ?? AppColors.textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'To keep your account safe and secure,\nwe need to verify your identity',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color ?? AppColors.textColor.withOpacity(0.7),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Profile Image with Upload
                            GestureDetector(
                              onTap: _isUploadingPhoto
                                  ? null
                                  : _showImageSourceDialog,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGrey.withOpacity(
                                        0.3,
                                      ),
                                      shape: BoxShape.circle,
                                      image: _userProfilePicture.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                _userProfilePicture,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _userProfilePicture.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 40,
                                            color: AppColors.primary,
                                          )
                                        : null,
                                  ),
                                  if (_isUploadingPhoto)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            // KYC Steps
                            _buildKYCStep(
                              'Selfie Verification',
                              _userProfilePicture.isNotEmpty,
                            ),
                            const SizedBox(height: 12),
                            _buildKYCStep('Name', _userName.isNotEmpty),
                            const SizedBox(height: 12),
                            _buildKYCStep(
                              'Phone Number',
                              _userPhone.isNotEmpty,
                            ),
                            const SizedBox(height: 12),
                            _buildKYCStep(
                              'Email Address',
                              _userEmail.isNotEmpty,
                            ),
                            const SizedBox(height: 24),

                            // Completion Status
                            if (_tier1Completed)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'KYC Tier 1 Completed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green[600],
                                    size: 20,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 24),

                            // Tier 2 Status (if exists)
                            if (_tier2Status != null)
                              _buildTierStatusCard('Tier 2', _tier2Status!),

                            // Tier 3 Status (if exists)
                            if (_tier3Status != null)
                              _buildTierStatusCard('Tier 3', _tier3Status!),

                            if (_tier2Status != null || _tier3Status != null)
                              const SizedBox(height: 24),

                            // Account Limit
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Limit',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.titleMedium?.color ?? AppColors.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLimitRow(
                                    'Daily transaction limit',
                                    '₦50,000.00',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildLimitRow(
                                    'Maximum account balance',
                                    '₦300,000.00',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Upgrade Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _tier1Completed
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const KYCTier2Screen(),
                                          ),
                                        );
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
                                  'Upgrade to next level',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKYCStep(String title, bool isCompleted) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color ?? AppColors.textColor,
            ),
          ),
          if (isCompleted)
            Icon(Icons.check_circle, color: Colors.green[600], size: 22)
          else
            Icon(
              Icons.radio_button_unchecked,
              color: Colors.grey[400],
              size: 22,
            ),
        ],
      ),
    );
  }

  Widget _buildTierStatusCard(String tier, String status) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = status;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'KYC $tier',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium?.color ?? AppColors.textColor,
            ),
          ),
          Row(
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(statusIcon, color: statusColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }

    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? AppColors.textColor.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.titleMedium?.color ?? AppColors.textColor,
          ),
        ),
      ],
    );
  }
}
