import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _middleNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  Map<String, String> _fieldErrors = {};

  // Passport (using the circular uploader)
  XFile? _selectedPassport;
  Uint8List? _selectedPassportBytes;
  String? _currentPassport;

  final ImagePicker _picker = ImagePicker();

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _firstNameFocus.dispose();
    _middleNameFocus.dispose();
    _lastNameFocus.dispose();
    _usernameFocus.dispose();
    _phoneFocus.dispose();
    _animationController?.dispose();
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
        final responseData = jsonDecode(response.body);
        
        // Extract user data - data is directly in 'data' key
        final data = responseData['data'] ?? responseData;

        if (mounted) {
          setState(() {
            _firstNameController.text = data['first_name']?.toString() ?? '';
            _middleNameController.text = data['middle_name']?.toString() ?? '';
            _lastNameController.text = data['last_name']?.toString() ?? '';
            _usernameController.text = data['username']?.toString() ?? '';
            _emailController.text = data['email']?.toString() ?? '';
            _phoneController.text = data['phone']?.toString() ?? '';
            _currentPassport = data['passport']?.toString() ?? data['photo']?.toString() ?? '';
            _isLoadingProfile = false;
          });
          if (_animationController?.status == AnimationStatus.dismissed) {
            _animationController?.forward();
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingProfile = false);
          if (_animationController?.status == AnimationStatus.dismissed) {
            _animationController?.forward();
          }
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        if (_animationController?.status == AnimationStatus.dismissed) {
          _animationController?.forward();
        }
        ToastHelper.showError('Error loading profile');
      }
    }
  }

  Future<void> _pickPassport() async {
    try {
      // Show bottom sheet with options
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildImagePickerSheet(),
      );
    } catch (e) {
      print('Error picking passport: $e');
      ToastHelper.showError('Error selecting photo');
    }
  }

  Widget _buildImagePickerSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Change Profile Photo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 85,
                  );
                  if (pickedFile != null) {
                    await _uploadPassport(pickedFile);
                  }
                },
              ),
              _buildPickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: Colors.purple,
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 85,
                  );
                  if (pickedFile != null) {
                    await _uploadPassport(pickedFile);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _fieldErrors = {};
    });
    HapticFeedback.mediumImpact();

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      // Update user profile info
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/user/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'first_name': _firstNameController.text.trim(),
          'middle_name': _middleNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh user data
        await authService.refreshUserData();

        if (!mounted) return;

        ToastHelper.showSuccess('Profile updated successfully!');

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else if (response.statusCode == 422) {
        // Handle validation errors
        final errors = result['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          setState(() {
            _fieldErrors = errors.map((key, value) => 
              MapEntry(key, (value as List).first.toString()));
          });
        } else {
          ToastHelper.showError(result['message'] ?? 'Validation failed');
        }
      } else {
        ToastHelper.showError(result['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      print('Error updating profile: $e');
      ToastHelper.showError('Error updating profile');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildAppBar(),

                // Content
                Expanded(
                  child: _isLoadingProfile
                      ? _buildLoadingState()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: FadeTransition(
                            opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                            child: SlideTransition(
                              position: _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Profile Photo Section
                                    _buildProfilePhotoSection(),

                                    const SizedBox(height: 32),

                                    // Personal Info Card
                                    _buildPersonalInfoCard(),

                                    const SizedBox(height: 20),

                                    // Contact Info Card
                                    _buildContactInfoCard(),

                                    const SizedBox(height: 32),

                                    // Update Button
                                    _buildUpdateButton(),

                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading profile...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Updating profile...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return Column(
      children: [
        // Photo Container
        Stack(
          children: [
            // Main Photo Circle
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.primary.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipOval(
                    child: Container(
                      width: 116,
                      height: 116,
                      color: Colors.grey.shade200,
                      child: _buildProfileImage(),
                    ),
                  ),
                ),
              ),
            ),

            // Camera Button
            Positioned(
              bottom: 5,
              right: 5,
              child: GestureDetector(
                onTap: _pickPassport,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Uploading Indicator
            if (_selectedPassport != null && _isLoading)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Photo Label
        Text(
          'Profile Photo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),

        // Uploading Hint
        if (_selectedPassport != null && _isLoading) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Uploading photo...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.blue.shade600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // First Name Field
          _buildInputField(
            label: 'First Name',
            controller: _firstNameController,
            focusNode: _firstNameFocus,
            icon: Icons.person_outline_rounded,
            errorText: _fieldErrors['first_name'],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'First name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Middle Name Field (Optional)
          _buildInputField(
            label: 'Middle Name (Optional)',
            controller: _middleNameController,
            focusNode: _middleNameFocus,
            icon: Icons.person_outline_rounded,
            errorText: _fieldErrors['middle_name'],
          ),

          const SizedBox(height: 20),

          // Last Name Field
          _buildInputField(
            label: 'Last Name',
            controller: _lastNameController,
            focusNode: _lastNameFocus,
            icon: Icons.person_outline_rounded,
            errorText: _fieldErrors['last_name'],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Last name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Username Field
          _buildInputField(
            label: 'Username',
            controller: _usernameController,
            focusNode: _usernameFocus,
            icon: Icons.alternate_email_rounded,
            errorText: _fieldErrors['username'],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Username is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.contact_mail_outlined,
                  color: Colors.green.shade600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Email Field (Read-only)
          _buildInputField(
            label: 'Email Address',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: false, // Email is read-only
          ),

          const SizedBox(height: 20),

          // Phone Field (Editable)
          _buildInputField(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            errorText: _fieldErrors['phone'],
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
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? errorText,
    String? Function(String?)? validator,
  }) {
    final bool hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError
                  ? Colors.red.shade400
                  : enabled
                      ? (focusNode?.hasFocus ?? false
                          ? AppColors.primary
                          : Colors.grey.shade200)
                      : Colors.grey.shade300,
              width: hasError
                  ? 1.5
                  : (enabled && (focusNode?.hasFocus ?? false) ? 2 : 1),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: hasError
                          ? Colors.red.withOpacity(0.08)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            enabled: enabled,
            style: TextStyle(
              fontSize: 15,
              color: enabled ? Colors.black87 : Colors.grey.shade600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  color: hasError
                      ? Colors.red.shade400
                      : enabled
                          ? (focusNode?.hasFocus ?? false
                              ? AppColors.primary
                              : Colors.grey.shade400)
                          : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              suffixIcon: !enabled
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: validator,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: Colors.red.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: AppColors.primary.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Update Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Upload passport immediately when selected
  Future<void> _uploadPassport(XFile imageFile) async {
    // Read bytes first for preview
    final bytes = await imageFile.readAsBytes();
    
    setState(() {
      _selectedPassport = imageFile;
      _selectedPassportBytes = bytes;
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.baseUrl}/passport'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      
      // Use bytes for cross-platform compatibility
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: 'passport_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Extract passport URL from response
        final responseData = data['data'] ?? data;
        final user = responseData['user'] ?? responseData;
        final passportUrl = user['passport'];
        
        setState(() {
          _currentPassport = passportUrl;
          _selectedPassport = null;
          _selectedPassportBytes = null;
        });
        
        // Refresh user data
        await authService.refreshUserData();
        
        ToastHelper.showSuccess('Photo updated successfully!');
      } else {
        ToastHelper.showError(data['message'] ?? 'Failed to upload photo');
        setState(() {
          _selectedPassport = null;
          _selectedPassportBytes = null;
        });
      }
    } catch (e) {
      print('Error uploading passport: $e');
      ToastHelper.showError('Error uploading photo');
      setState(() {
        _selectedPassport = null;
        _selectedPassportBytes = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper method to get passport image
  ImageProvider? _getPassportImage() {
    print('_getPassportImage called');
    print('_selectedPassportBytes: ${_selectedPassportBytes != null}');
    print('_currentPassport: $_currentPassport');
    
    try {
      if (_selectedPassportBytes != null) {
        print('Returning MemoryImage');
        return MemoryImage(_selectedPassportBytes!);
      } else if (_currentPassport != null && _currentPassport!.isNotEmpty) {
        String url = _currentPassport!;
        
        // If it's a relative path, prepend the base URL
        if (url.startsWith('/storage') || url.startsWith('storage')) {
          // Get base URL without /api suffix
          String baseUrl = Constants.baseUrl;
          if (baseUrl.endsWith('/api')) {
            baseUrl = baseUrl.substring(0, baseUrl.length - 4);
          }
          url = '$baseUrl${url.startsWith('/') ? url : '/$url'}';
        }
        
        print('Final image URL: $url');
        
        // Only return NetworkImage for valid URLs
        if (url.startsWith('http://') || url.startsWith('https://')) {
          print('Returning NetworkImage for: $url');
          return NetworkImage(url);
        } else {
          print('URL does not start with http/https');
        }
      } else {
        print('No passport to display');
      }
    } catch (e) {
      print('Error loading passport image: $e');
    }
    return null;
  }

  // Build profile image with error handling
  Widget _buildProfileImage() {
    // Show selected image bytes
    if (_selectedPassportBytes != null) {
      return Image.memory(
        _selectedPassportBytes!,
        fit: BoxFit.cover,
        width: 116,
        height: 116,
      );
    }
    
    // Show network image if available
    if (_currentPassport != null && _currentPassport!.isNotEmpty) {
      String url = _currentPassport!;
      
      // If it's a relative path, prepend the base URL
      if (url.startsWith('/storage') || url.startsWith('storage')) {
        String baseUrl = Constants.baseUrl;
        if (baseUrl.endsWith('/api')) {
          baseUrl = baseUrl.substring(0, baseUrl.length - 4);
        }
        url = '$baseUrl${url.startsWith('/') ? url : '/$url'}';
      }
      
      print('Loading image from: $url');
      
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          width: 116,
          height: 116,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Image load error: $error');
            return Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.red.shade400,
            );
          },
        );
      }
    }
    
    // Show placeholder
    return Icon(
      Icons.person_rounded,
      size: 50,
      color: Colors.grey.shade400,
    );
  }

  // Helper method to show placeholder when no passport
  Widget? _getPassportChild() {
    if (_selectedPassport == null &&
        (_currentPassport == null || _currentPassport!.isEmpty)) {
      return Icon(
        Icons.person_rounded,
        size: 50,
        color: Colors.grey.shade400,
      );
    }
    return null;
  }
}
