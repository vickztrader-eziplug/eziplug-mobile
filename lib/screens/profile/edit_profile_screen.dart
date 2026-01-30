import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingProfile = true;

  // Passport (using the circular uploader)
  File? _selectedPassport;
  String? _currentPassport;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoadingProfile = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _fullNameController.text =
                data['first_name'] ?? data['firstName'] ?? data['name'] ?? '';
            _usernameController.text =
                data['username'] ?? data['userName'] ?? '';
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _currentPassport = data['passport'] ?? data['photo'] ?? '';
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        _showSnackBar('Error loading profile', Colors.red);
      }
    }
  }

  Future<void> _pickPassport() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedPassport = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking passport: $e');
      _showSnackBar('Error selecting passport', Colors.red);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      bool profileUpdated = false;
      bool passportUpdated = false;

      // 1. Update user info (email, phone) if changed
      if (_emailController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty) {
        var profileRequest = http.MultipartRequest(
          'POST',
          Uri.parse('${Constants.baseUrl}/user/update'),
        );

        profileRequest.headers['Authorization'] = 'Bearer $token';
        profileRequest.headers['Accept'] = 'application/json';
        profileRequest.fields['email'] = _emailController.text.trim();
        profileRequest.fields['phone'] = _phoneController.text.trim();

        print('📤 Updating profile info...');
        final profileStreamedResponse = await profileRequest.send();
        final profileResponse = await http.Response.fromStream(
          profileStreamedResponse,
        );
        final profileData = jsonDecode(profileResponse.body);

        print('📡 Profile Response Status: ${profileResponse.statusCode}');
        print('📦 Profile Response Data: $profileData');

        if (profileResponse.statusCode == 200 ||
            profileResponse.statusCode == 201) {
          profileUpdated = true;
        }
      }

      // 2. Upload passport if selected
      if (_selectedPassport != null) {
        var passportRequest = http.MultipartRequest(
          'POST',
          Uri.parse('${Constants.baseUrl}/passport'),
        );

        passportRequest.headers['Authorization'] = 'Bearer $token';
        passportRequest.headers['Accept'] = 'application/json';
        passportRequest.files.add(
          await http.MultipartFile.fromPath('photo', _selectedPassport!.path),
        );

        print('📤 Uploading passport...');
        final passportStreamedResponse = await passportRequest.send();
        final passportResponse = await http.Response.fromStream(
          passportStreamedResponse,
        );
        final passportData = jsonDecode(passportResponse.body);

        print('📡 Passport Response Status: ${passportResponse.statusCode}');
        print('📦 Passport Response Data: $passportData');

        if (passportResponse.statusCode == 200 ||
            passportResponse.statusCode == 201) {
          final responseData = getResponseData(passportData);
          final updatedUser = responseData['user'] ?? passportData['user'];
          if (updatedUser != null) {
            setState(() {
              _currentPassport = updatedUser['passport'];
              _selectedPassport = null;
            });
          }
          passportUpdated = true;
        }
      }

      // Refresh user data
      await authService.refreshUserData();

      if (!mounted) return;

      // Show success message
      if (passportUpdated && profileUpdated) {
        _showSnackBar(
          'Profile and passport updated successfully',
          Colors.green,
        );
      } else if (passportUpdated) {
        _showSnackBar('Passport updated successfully', Colors.green);
      } else if (profileUpdated) {
        _showSnackBar('Profile updated successfully', Colors.green);
      } else {
        _showSnackBar('No changes to update', Colors.orange);
      }

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      print('Error updating profile: $e');
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
              ),

            // Header Section
            Container(
              width: double.infinity,
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
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
                              'Edit Profile',
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
                    const SizedBox(height: 20),
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
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoadingProfile
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Passport Picture (Circular)
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 3,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: AppColors.lightGrey,
                                      backgroundImage: _getPassportImage(),
                                      child: _getPassportChild(),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickPassport,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Show a badge when passport is selected but not uploaded
                                  if (_selectedPassport != null)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Label
                              Text(
                                'Passport / ID Photo',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textColor.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Hint text when passport is selected
                              if (_selectedPassport != null)
                                Text(
                                  'Tap "Update Profile" to save',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                              const SizedBox(height: 30),

                              // Full Name (Read-only)
                              _buildLabel('Full Name'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _fullNameController,
                                hintText: 'Full Name',
                                enabled: false,
                              ),

                              const SizedBox(height: 20),

                              // Username (Read-only)
                              _buildLabel('Username'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _usernameController,
                                hintText: 'Username',
                                enabled: false,
                              ),

                              const SizedBox(height: 20),

                              // Email (Editable)
                              _buildLabel('Email Address'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Phone (Editable)
                              _buildLabel('Phone Number'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _phoneController,
                                hintText: 'Phone Number',
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Phone number is required';
                                  }
                                  if (value.length < 10) {
                                    return 'Enter a valid phone number';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 40),

                              // Update Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _updateProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.textColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    disabledBackgroundColor:
                                        AppColors.lightGrey,
                                  ),
                                  child: const Text(
                                    'Update Profile',
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
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get passport image
  ImageProvider? _getPassportImage() {
    if (_selectedPassport != null) {
      // Show selected passport (preview before upload)
      return FileImage(_selectedPassport!);
    } else if (_currentPassport != null && _currentPassport!.isNotEmpty) {
      // Show uploaded passport from server
      return NetworkImage(_currentPassport!);
    }
    return null;
  }

  // Helper method to show placeholder when no passport
  Widget? _getPassportChild() {
    if (_selectedPassport == null &&
        (_currentPassport == null || _currentPassport!.isEmpty)) {
      return const Icon(
        Icons.badge_outlined,
        size: 60,
        color: AppColors.textColor,
      );
    }
    return null;
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? AppColors.cardBackground : Colors.grey[200],
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: enabled ? AppColors.lightGrey : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(
          fontSize: 14,
          color: enabled
              ? AppColors.textColor
              : AppColors.textColor.withOpacity(0.5),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textColor.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: !enabled
              ? Icon(Icons.lock_outline, color: Colors.grey[400], size: 20)
              : null,
        ),
        validator: validator,
      ),
    );
  }
}
