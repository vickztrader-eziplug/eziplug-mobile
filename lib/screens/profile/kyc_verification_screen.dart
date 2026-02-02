import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';

class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  // Field validation errors
  Map<String, String> _fieldErrors = {};
  
  // KYC Status
  int _currentTier = 1;
  int? _nextTier;
  bool _hasPending = false;
  Map<String, dynamic>? _pendingSubmission;
  List<dynamic> _verifications = [];
  Map<String, dynamic> _tierRequirements = {};
  Map<String, dynamic> _idTypes = {};
  Map<String, dynamic> _limits = {};
  
  // Tier 2 form data
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _idNumberController = TextEditingController();
  String? _selectedIdType;
  XFile? _idPhoto;
  Uint8List? _idPhotoBytes;
  
  // Tier 3 form data
  XFile? _proofOfAddress;
  Uint8List? _proofOfAddressBytes;
  XFile? _proofOfIncome;
  Uint8List? _proofOfIncomeBytes;
  
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchKycStatus();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchKycStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      
      if (token == null || token.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/kyc/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseData = data['data'] ?? data;
        
        if (mounted) {
          setState(() {
            _currentTier = responseData['current_tier'] ?? 1;
            _nextTier = responseData['next_tier'];
            _hasPending = responseData['has_pending'] ?? false;
            _pendingSubmission = responseData['pending_submission'];
            _verifications = responseData['verifications'] ?? [];
            _tierRequirements = Map<String, dynamic>.from(responseData['tier_requirements'] ?? {});
            _idTypes = Map<String, dynamic>.from(responseData['id_types'] ?? {});
            _limits = Map<String, dynamic>.from(responseData['limits'] ?? {});
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error fetching KYC status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImageSourceSheet(),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        // Clear any error for this field
        _clearFieldError(type);
        setState(() {
          switch (type) {
            case 'id_photo':
              _idPhoto = pickedFile;
              _idPhotoBytes = bytes;
              break;
            case 'proof_of_address':
              _proofOfAddress = pickedFile;
              _proofOfAddressBytes = bytes;
              break;
            case 'proof_of_income':
              _proofOfIncome = pickedFile;
              _proofOfIncomeBytes = bytes;
              break;
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  Widget _buildImageSourceSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Check if selected ID type requires photo upload
  bool _isIdPhotoRequired() {
    // BVN and NIN can be verified electronically, so photo is optional
    return _selectedIdType != 'bvn' && _selectedIdType != 'nin';
  }

  Future<void> _submitTier2() async {
    // Clear previous errors
    setState(() => _fieldErrors.clear());
    
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIdType == null) {
      setState(() => _fieldErrors['id_type'] = 'Please select an ID type');
      return;
    }
    if (_isIdPhotoRequired() && _idPhoto == null) {
      setState(() => _fieldErrors['id_photo'] = 'Please upload your ID photo');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.baseUrl}/kyc/tier2'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['address'] = _addressController.text;
      request.fields['city'] = _cityController.text;
      request.fields['state'] = _stateController.text;
      request.fields['zip_code'] = _zipCodeController.text;
      request.fields['id_type'] = _selectedIdType!;
      request.fields['id_number'] = _idNumberController.text;

      // Add ID photo if provided
      if (_idPhoto != null && _idPhotoBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'id_photo',
          _idPhotoBytes!,
          filename: _idPhoto!.name,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar('Tier 2 verification submitted successfully!');
        await _fetchKycStatus();
      } else {
        final error = jsonDecode(response.body);
        _setFieldErrors(error);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitTier3() async {
    // Clear previous errors
    setState(() => _fieldErrors.clear());
    
    if (_proofOfAddress == null || _proofOfAddressBytes == null) {
      setState(() => _fieldErrors['proof_of_address'] = 'Please upload proof of address');
      return;
    }
    if (_proofOfIncome == null || _proofOfIncomeBytes == null) {
      setState(() => _fieldErrors['proof_of_income'] = 'Please upload proof of income');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.baseUrl}/kyc/tier3'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.files.add(http.MultipartFile.fromBytes(
        'proof_of_address',
        _proofOfAddressBytes!,
        filename: _proofOfAddress!.name,
      ));
      request.files.add(http.MultipartFile.fromBytes(
        'proof_of_income',
        _proofOfIncomeBytes!,
        filename: _proofOfIncome!.name,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar('Tier 3 verification submitted successfully!');
        await _fetchKycStatus();
      } else {
        final error = jsonDecode(response.body);
        _setFieldErrors(error);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Parse Laravel validation errors and return a user-friendly message
  String _parseValidationError(Map<String, dynamic> error) {
    // Check for Laravel validation errors format
    if (error.containsKey('errors') && error['errors'] is Map) {
      final errors = error['errors'] as Map<String, dynamic>;
      final List<String> errorMessages = [];
      
      errors.forEach((field, messages) {
        if (messages is List && messages.isNotEmpty) {
          errorMessages.add(messages.first.toString());
        } else if (messages is String) {
          errorMessages.add(messages);
        }
      });
      
      if (errorMessages.isNotEmpty) {
        return errorMessages.join('\n');
      }
    }
    
    // Fallback to message field
    return error['message']?.toString() ?? 'Failed to submit verification';
  }

  /// Set field-level validation errors from Laravel response
  void _setFieldErrors(Map<String, dynamic> error) {
    setState(() {
      _fieldErrors.clear();
      
      if (error.containsKey('errors') && error['errors'] is Map) {
        final errors = error['errors'] as Map<String, dynamic>;
        errors.forEach((field, messages) {
          if (messages is List && messages.isNotEmpty) {
            _fieldErrors[field] = messages.first.toString();
          } else if (messages is String) {
            _fieldErrors[field] = messages;
          }
        });
      }
      
      // If no field-specific errors, show general message as toast
      if (_fieldErrors.isEmpty) {
        _showSnackBar(error['message']?.toString() ?? 'Validation failed', isError: true);
      }
    });
  }

  /// Clear error for a specific field
  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() {
        _fieldErrors.remove(field);
      });
    }
  }

  /// Build error text widget for a field
  Widget _buildFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _fieldErrors[field]!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header using ModernFormWidgets
                ModernFormWidgets.buildGradientHeader(
                  context: context,
                  title: 'KYC Verification',
                  subtitle: 'Verify your identity to unlock more features',
                  primaryColor: AppColors.primary,
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTierProgress(),
                        const SizedBox(height: 20),
                        _buildCurrentTierCard(),
                        const SizedBox(height: 20),
                        if (_hasPending)
                          _buildPendingCard()
                        else if (_nextTier != null)
                          _buildUpgradeForm(),
                        const SizedBox(height: 20),
                        _buildLimitsCard(),
                        const SizedBox(height: 20),
                        if (_verifications.isNotEmpty) _buildHistorySection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTierProgress() {
    return ModernFormWidgets.buildFormCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernFormWidgets.buildSectionLabel(
            'Verification Progress',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildTierStep(1, 'Basic', _currentTier >= 1),
              _buildTierConnector(_currentTier >= 2),
              _buildTierStep(2, 'Standard', _currentTier >= 2),
              _buildTierConnector(_currentTier >= 3),
              _buildTierStep(3, 'Premium', _currentTier >= 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierStep(int tier, String label, bool isCompleted) {
    final isPending = _hasPending && tier == (_pendingSubmission?['tier'] ?? 0);
    
    Color bgColor;
    Color borderColor;
    
    if (isPending) {
      bgColor = Colors.orange.withOpacity(0.15);
      borderColor = Colors.orange;
    } else if (isCompleted) {
      bgColor = AppColors.primary.withOpacity(0.15);
      borderColor = AppColors.primary;
    } else {
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2.5),
            ),
            child: Center(
              child: isPending
                  ? const Icon(
                      Icons.hourglass_top_rounded,
                      color: Colors.orange,
                      size: 24,
                    )
                  : Icon(
                      isCompleted ? Icons.check_rounded : Icons.circle,
                      color: isCompleted ? AppColors.primary : Colors.grey.shade400,
                      size: isCompleted ? 26 : 14,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tier $tier',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isCompleted ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierConnector(bool isActive) {
    return Container(
      width: 36,
      height: 3,
      margin: const EdgeInsets.only(bottom: 36),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCurrentTierCard() {
    final tierInfo = _tierRequirements[_currentTier.toString()];
    if (tierInfo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
            AppColors.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Level: Tier $_currentTier',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tierInfo['name'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tierInfo['description'] ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Pending',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tier ${_pendingSubmission?['tier'] ?? ''} verification is under review',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModernFormWidgets.buildInfoCard(
            message: 'Your verification is being reviewed by our team. This usually takes 24-48 hours. You will be notified once the review is complete.',
            icon: Icons.schedule_rounded,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeForm() {
    if (_nextTier == 2) {
      return _buildTier2Form();
    } else if (_nextTier == 3) {
      return _buildTier3Form();
    }
    return const SizedBox.shrink();
  }

  Widget _buildTier2Form() {
    final tierInfo = _tierRequirements['2'];
    
    return ModernFormWidgets.buildFormCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upgrade_rounded, color: Color(0xFF2196F3), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Tier 2',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tierInfo?['name'] ?? 'Standard Verification',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Requirements
            _buildRequirementsList(tierInfo?['requirements'] ?? []),
            const SizedBox(height: 24),
            
            // Address field
            ModernFormWidgets.buildTextField(
              controller: _addressController,
              label: 'Home Address',
              hintText: 'Enter your full address',
              prefixIcon: Icons.home_outlined,
              onChanged: (_) => _clearFieldError('address'),
            ),
            _buildFieldError('address'),
            const SizedBox(height: 16),
            
            // City and State
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ModernFormWidgets.buildTextField(
                        controller: _cityController,
                        hintText: 'City',
                        prefixIcon: Icons.location_city_outlined,
                        onChanged: (_) => _clearFieldError('city'),
                      ),
                      _buildFieldError('city'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ModernFormWidgets.buildTextField(
                        controller: _stateController,
                        hintText: 'State',
                        prefixIcon: Icons.map_outlined,
                        onChanged: (_) => _clearFieldError('state'),
                      ),
                      _buildFieldError('state'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Zip Code
            ModernFormWidgets.buildTextField(
              controller: _zipCodeController,
              hintText: 'Zip Code (Optional)',
              prefixIcon: Icons.markunread_mailbox_outlined,
              onChanged: (_) => _clearFieldError('zip_code'),
            ),
            _buildFieldError('zip_code'),
            const SizedBox(height: 16),
            
            // ID Type dropdown
            _buildIdTypeSelector(),
            _buildFieldError('id_type'),
            const SizedBox(height: 16),
            
            // ID Number
            ModernFormWidgets.buildTextField(
              controller: _idNumberController,
              label: 'ID Number',
              hintText: 'Enter your NIN or BVN number',
              prefixIcon: Icons.badge_outlined,
              onChanged: (_) => _clearFieldError('id_number'),
            ),
            _buildFieldError('id_number'),
            const SizedBox(height: 20),
            
            // ID Photo upload
            _buildImageUpload(
              label: 'ID Document Photo',
              hint: 'Take a clear photo of your ID',
              imageBytes: _idPhotoBytes,
              onTap: () => _pickImage('id_photo'),
              isOptional: !_isIdPhotoRequired(),
            ),
            _buildFieldError('id_photo'),
            const SizedBox(height: 24),
            
            // Submit button
            ModernFormWidgets.buildPrimaryButton(
              label: 'Submit Verification',
              onPressed: _submitTier2,
              isLoading: _isSubmitting,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTier3Form() {
    final tierInfo = _tierRequirements['3'];
    
    return ModernFormWidgets.buildFormCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF00C853), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Tier 3',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tierInfo?['name'] ?? 'Premium Verification',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Requirements
          _buildRequirementsList(tierInfo?['requirements'] ?? []),
          const SizedBox(height: 24),
          
          // Proof of Address upload
          _buildImageUpload(
            label: 'Proof of Address',
            hint: 'Upload utility bill or bank statement',
            imageBytes: _proofOfAddressBytes,
            onTap: () => _pickImage('proof_of_address'),
          ),
          _buildFieldError('proof_of_address'),
          const SizedBox(height: 20),
          
          // Proof of Income upload
          _buildImageUpload(
            label: 'Proof of Income',
            hint: 'Upload pay slip or tax returns',
            imageBytes: _proofOfIncomeBytes,
            onTap: () => _pickImage('proof_of_income'),
          ),
          _buildFieldError('proof_of_income'),
          const SizedBox(height: 24),
          
          // Submit button
          ModernFormWidgets.buildPrimaryButton(
            label: 'Submit Verification',
            onPressed: _submitTier3,
            isLoading: _isSubmitting,
            icon: Icons.send_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsList(List<dynamic> requirements) {
    if (requirements.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Requirements',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...requirements.map((req) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    req.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildIdTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernFormWidgets.buildSectionLabel('ID Type', icon: Icons.credit_card_outlined, iconColor: AppColors.primary),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _idTypes.entries.map((entry) {
            final isSelected = _selectedIdType == entry.key;
            return GestureDetector(
              onTap: () {
                _clearFieldError('id_type');
                setState(() => _selectedIdType = entry.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageUpload({
    required String label,
    required String hint,
    required Uint8List? imageBytes,
    required VoidCallback onTap,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ModernFormWidgets.buildSectionLabel(label, icon: Icons.photo_camera_outlined, iconColor: AppColors.primary),
            ),
            if (isOptional)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: imageBytes != null ? 200 : 130,
            decoration: BoxDecoration(
              color: imageBytes != null ? Colors.transparent : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: imageBytes != null ? AppColors.primary : Colors.grey.shade200,
                width: imageBytes != null ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: imageBytes != null 
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: imageBytes != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          imageBytes,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                          ),
                        ),
                      ),
                      // Success indicator
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Uploaded',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.cloud_upload_outlined, size: 32, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to upload',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLimitsCard() {
    final dailyLimit = _limits['daily_limit'] ?? 0;
    final monthlyLimit = _limits['monthly_limit'] ?? 0;
    
    return ModernFormWidgets.buildFormCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernFormWidgets.buildSectionLabel(
            'Transaction Limits',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLimitItem('Daily Limit', '₦${_formatAmount(dailyLimit)}', Icons.today_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildLimitItem('Monthly Limit', '₦${_formatAmount(monthlyLimit)}', Icons.calendar_month_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernFormWidgets.buildSectionLabel(
          'Verification History',
          icon: Icons.history_rounded,
          iconColor: AppColors.primary,
        ),
        const SizedBox(height: 14),
        ...(_verifications.map((v) => _buildHistoryItem(v))),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> verification) {
    final status = verification['status'] ?? '';
    final tier = verification['tier'] ?? 0;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tier $tier Verification',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                if (verification['rejection_reason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      verification['rejection_reason'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toString().toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    final numAmount = (amount is int) ? amount.toDouble() : (amount ?? 0.0);
    if (numAmount >= 1000000) {
      return '${(numAmount / 1000000).toStringAsFixed(1)}M';
    } else if (numAmount >= 1000) {
      return '${(numAmount / 1000).toStringAsFixed(0)}K';
    }
    return numAmount.toStringAsFixed(0);
  }
}
