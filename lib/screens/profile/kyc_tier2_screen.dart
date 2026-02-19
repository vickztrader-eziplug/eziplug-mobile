import 'package:cashpoint/screens/profile/kyc_tier3_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';

class KYCTier2Screen extends StatefulWidget {
  const KYCTier2Screen({super.key});

  @override
  State<KYCTier2Screen> createState() => _KYCTier2ScreenState();
}

class _KYCTier2ScreenState extends State<KYCTier2Screen> {
  String? _selectedIdType;
  final TextEditingController _idNumberController = TextEditingController();
  bool _isSubmitting = false;
  String? _maskedPhone;
  String? _verifiedName;
  String? _debugOtp; // For testing when Termii is not configured
  final TextEditingController _otpController = TextEditingController();
  
  // Identity verification state
  bool _isVerifyingIdentity = false;
  bool _identityVerified = false;
  bool _nameMatch = false;
  Map<String, dynamic>? _matchDetails;
  String? _verificationError;

  final List<Map<String, dynamic>> _idTypes = [
    {'name': 'National Identification Number (NIN)', 'value': 'nin'},
    {'name': 'Bank Verification Number (BVN)', 'value': 'bvn'},
  ];

  @override
  void initState() {
    super.initState();
    // Add listener to auto-verify when 11 digits are entered
    _idNumberController.addListener(_onIdNumberChanged);
  }

  @override
  void dispose() {
    _idNumberController.removeListener(_onIdNumberChanged);
    _idNumberController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Auto-verify identity when 11 digits are entered
  void _onIdNumberChanged() {
    final idNumber = _idNumberController.text.trim();
    
    // Reset verification state if digits change
    if (_identityVerified && idNumber.length != 11) {
      setState(() {
        _identityVerified = false;
        _nameMatch = false;
        _matchDetails = null;
        _verifiedName = null;
        _verificationError = null;
      });
    }
    
    // Auto-verify when 11 digits and ID type selected
    if (idNumber.length == 11 && _selectedIdType != null && !_identityVerified && !_isVerifyingIdentity) {
      _verifyIdentity();
    }
  }

  // Method to verify identity (BVN/NIN) with Paystack
  Future<void> _verifyIdentity() async {
    if (_selectedIdType == null || _selectedIdType!.isEmpty) {
      return;
    }

    final idNumber = _idNumberController.text.trim();
    if (idNumber.length != 11) {
      return;
    }

    setState(() {
      _isVerifyingIdentity = true;
      _verificationError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/kyc/verify-identity'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id_type': _selectedIdType,
          'id_number': idNumber,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (mounted) {
        setState(() => _isVerifyingIdentity = false);

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Identity verified successfully
          setState(() {
            _identityVerified = true;
            _verifiedName = responseData['data']?['verified_name'] ?? 
                            responseData['verified_name'];
            _nameMatch = responseData['data']?['name_match'] ?? 
                         responseData['name_match'] ?? false;
            _matchDetails = responseData['data']?['match_details'] ?? 
                           responseData['match_details'];
            _maskedPhone = responseData['data']?['phone_masked'] ?? 
                          responseData['phone_masked'];
          });
        } else {
          setState(() {
            _verificationError = responseData['message'] ?? 'Verification failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingIdentity = false;
          _verificationError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // Method to submit KYC Tier 2 (Send OTP after identity verified)
  Future<void> _submitKYCTier2() async {
    // Validation
    if (_selectedIdType == null || _selectedIdType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an ID type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final idNumber = _idNumberController.text.trim();
    if (idNumber.isEmpty || idNumber.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 11-digit ID number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if identity was verified
    if (!_identityVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for identity verification to complete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if names match
    if (!_nameMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name on ID does not match your profile. Please update your profile or use a different ID.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/kyc/tier2'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id_type': _selectedIdType,
          'id_number': idNumber,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (response.statusCode == 200 || response.statusCode == 201) {
          // OTP sent successfully or pending - extract data first
          _maskedPhone = responseData['data']?['phone_masked'] ?? 
                         responseData['phone_masked'] ?? 'your phone';
          _verifiedName = responseData['data']?['verified_name'] ?? 
                          responseData['verified_name'];
          // For testing - get debug OTP if Termii is not configured
          _debugOtp = responseData['data']?['debug_otp'] ?? 
                      responseData['debug_otp'];

          // Show OTP modal after the current frame rebuild completes
          // This ensures the loading overlay is fully dismissed first
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showOtpInputDialog();
            }
          });
        } else {
          throw Exception(responseData['message'] ?? 'Failed to verify ID');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to resend OTP
  Future<void> _resendOtp() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/kyc/tier2/resend-otp'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final responseData = jsonDecode(response.body);

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Update debug OTP for testing
          setState(() {
            _debugOtp = responseData['data']?['debug_otp'] ?? 
                        responseData['debug_otp'];
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'OTP resent'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(responseData['message'] ?? 'Failed to resend OTP');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show OTP input bottom sheet modal
  void _showOtpInputDialog() {
    _otpController.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: true,
      builder: (sheetContext) {
        bool isVerifying = false;
        String? dialogDebugOtp = _debugOtp;
        
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
            final screenHeight = MediaQuery.of(context).size.height;
            
            return Container(
              height: (screenHeight * 0.65) + bottomPadding,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header with title and close button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.8),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.sms_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Enter OTP',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: isVerifying
                              ? null
                              : () {
                                  Navigator.of(sheetContext).pop();
                                  _otpController.clear();
                                },
                          icon: const Icon(Icons.close, size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                        bottom: bottomPadding + 24,
                      ),
                      child: Column(
                        children: [
                          // SMS icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sms,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'We sent a verification code to\n${_maskedPhone ?? "your phone"}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          if (_verifiedName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Name: $_verifiedName',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                          // Debug OTP display for testing
                          if (dialogDebugOtp != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'Test OTP: $dialogDebugOtp',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          
                          // OTP Input Field
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 10,
                            ),
                            decoration: InputDecoration(
                              hintText: '------',
                              hintStyle: TextStyle(
                                fontSize: 28,
                                letterSpacing: 10,
                                color: Colors.grey[300],
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Verify OTP Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isVerifying
                                  ? null
                                  : () async {
                                      final otp = _otpController.text.trim();
                                      if (otp.isEmpty) {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter the OTP'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        return;
                                      }
                                      if (otp.length != 6) {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          const SnackBar(
                                            content: Text('OTP must be exactly 6 digits'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        return;
                                      }

                                      setSheetState(() => isVerifying = true);

                                      try {
                                        final authService = Provider.of<AuthService>(this.context, listen: false);
                                        final token = await authService.getToken();

                                        if (token == null || token.isEmpty) {
                                          throw Exception('Authentication token not found');
                                        }

                                        final response = await http.post(
                                          Uri.parse('${Constants.baseUrl}/kyc/tier2/verify-otp'),
                                          headers: {
                                            'Authorization': 'Bearer $token',
                                            'Accept': 'application/json',
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode({'otp': otp}),
                                        );

                                        final responseData = jsonDecode(response.body);

                                        if (mounted) {
                                          setSheetState(() => isVerifying = false);

                                          if (response.statusCode == 200 || response.statusCode == 201) {
                                            // Success! Close OTP sheet and show success
                                            Navigator.of(sheetContext).pop();
                                            _showSuccessDialog(responseData);
                                          } else {
                                            throw Exception(responseData['message'] ?? 'OTP verification failed');
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          setSheetState(() => isVerifying = false);
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: isVerifying
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Verify OTP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Resend OTP row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive code? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await _resendOtp();
                                  setSheetState(() {
                                    dialogDebugOtp = _debugOtp;
                                  });
                                },
                                child: const Text(
                                  'Resend',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(Map<String, dynamic> responseData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Verification Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              responseData['message'] ?? 
                'Your Tier 2 verification has been completed successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (_verifiedName != null) ...[
              const SizedBox(height: 12),
              Text(
                'Verified as: $_verifiedName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to Tier 3 or back
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const KYCTier3Screen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue to Tier 3',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              height: 220,
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
                              'Upgrade (Tier 2)',
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
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Identity Verification',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Verify your identity using your BVN or NIN.\nWe\'ll send an OTP to your registered phone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textColor.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Tier 1 Status
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tier 1',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textColor,
                              ),
                            ),
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[600],
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Select ID Type Dropdown
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedIdType != null 
                                ? Colors.green 
                                : AppColors.lightGrey,
                            width: _selectedIdType != null ? 2 : 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Select ID Type'),
                            value: _selectedIdType,
                            items: _idTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type['value'],
                                child: Text(type['name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedIdType = value;
                                // Reset verification state when ID type changes
                                _identityVerified = false;
                                _nameMatch = false;
                                _matchDetails = null;
                                _verifiedName = null;
                                _verificationError = null;
                              });
                              // Trigger verification if already 11 digits
                              if (_idNumberController.text.trim().length == 11) {
                                _verifyIdentity();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ID Number Input
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _identityVerified && _nameMatch
                                ? Colors.green
                                : _identityVerified && !_nameMatch
                                    ? Colors.orange
                                    : _idNumberController.text.length == 11 
                                        ? AppColors.primary 
                                        : AppColors.lightGrey,
                            width: _idNumberController.text.length == 11 ? 2 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: _idNumberController,
                          keyboardType: TextInputType.number,
                          maxLength: 11,
                          onChanged: (value) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _selectedIdType == 'bvn' 
                                ? 'Enter your 11-digit BVN' 
                                : 'Enter your 11-digit NIN',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            prefixIcon: const Icon(
                              Icons.numbers,
                              color: AppColors.primary,
                            ),
                            suffixIcon: _isVerifyingIdentity
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : _identityVerified
                                    ? Icon(
                                        _nameMatch 
                                            ? Icons.check_circle 
                                            : Icons.warning,
                                        color: _nameMatch 
                                            ? Colors.green 
                                            : Colors.orange,
                                      )
                                    : null,
                          ),
                        ),
                      ),
                      
                      // Verification Status Display
                      if (_isVerifyingIdentity) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Verifying your identity...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Verification Error
                      if (_verificationError != null && !_isVerifyingIdentity) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _verificationError!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Identity Verified - Name Display
                      if (_identityVerified && _verifiedName != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _nameMatch 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _nameMatch ? Colors.green : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _nameMatch 
                                        ? Icons.verified_user 
                                        : Icons.warning_amber,
                                    color: _nameMatch 
                                        ? Colors.green 
                                        : Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _nameMatch 
                                        ? 'Identity Verified' 
                                        : 'Name Mismatch',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _nameMatch 
                                          ? Colors.green[700] 
                                          : Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Name on ID:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _verifiedName!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textColor,
                                ),
                              ),
                              if (_matchDetails != null) ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                _buildMatchDetail('First Name', _matchDetails!['first_name']),
                                _buildMatchDetail('Last Name', _matchDetails!['last_name']),
                                if (_matchDetails!['middle_name'] != null)
                                  _buildMatchDetail('Middle Name', _matchDetails!['middle_name']),
                              ],
                              if (!_nameMatch) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'The name on your ID doesn\'t match your profile. Please update your profile name or use a different ID.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),

                      // Account Limit Info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'After Verification',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLimitRow(
                              'Daily transaction limit',
                              '₦200,000.00',
                            ),
                            const SizedBox(height: 12),
                            _buildLimitRow(
                              'Maximum account balance',
                              '₦500,000.00',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || _isVerifyingIdentity || !_identityVerified || !_nameMatch) 
                              ? null 
                              : _submitKYCTier2,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _identityVerified && _nameMatch
                                ? AppColors.textColor
                                : AppColors.lightGrey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: AppColors.lightGrey,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _identityVerified && _nameMatch
                                      ? 'Send OTP to Complete'
                                      : !_identityVerified
                                          ? 'Enter ID to Verify'
                                          : 'Name Mismatch',
                                  style: TextStyle(
                                    color: _identityVerified && _nameMatch
                                        ? Colors.white
                                        : Colors.grey[600],
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

            // Loading overlay
            if (_isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textColor.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchDetail(String label, Map<String, dynamic>? detail) {
    if (detail == null) return const SizedBox.shrink();
    
    final userValue = detail['user'] ?? '';
    final verifiedValue = detail['verified'] ?? '';
    final match = detail['match'] ?? false;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            match ? Icons.check : Icons.close,
            size: 14,
            color: match ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            verifiedValue,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: match ? Colors.green[700] : Colors.red[700],
            ),
          ),
          if (!match && userValue.isNotEmpty) ...[
            Text(
              ' (Profile: $userValue)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
