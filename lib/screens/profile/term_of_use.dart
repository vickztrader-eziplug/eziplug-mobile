import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TermOfUserScreen extends StatefulWidget {
  const TermOfUserScreen({super.key});

  @override
  State<TermOfUserScreen> createState() => _TermOfUserScreenState();
}

class _TermOfUserScreenState extends State<TermOfUserScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _sections = [
    {
      'icon': Icons.check_circle_outline_rounded,
      'color': Colors.green,
      'title': 'Eligibility',
      'content': 'Users must be at least 18 years old to use Eziplug services.',
    },
    {
      'icon': Icons.person_add_outlined,
      'color': Colors.blue,
      'title': 'Account Registration',
      'content': 'Users must provide accurate information including name, phone number, email, and complete KYC verification using valid government-issued documents. You are responsible for maintaining the confidentiality of your account credentials.',
    },
    {
      'icon': Icons.block_outlined,
      'color': Colors.red,
      'title': 'Prohibited Activities',
      'content': 'Users must not use Eziplug for unlawful purposes including fraud, money laundering, terrorist financing, or market manipulation. Violations may result in account suspension and reporting to authorities.',
    },
    {
      'icon': Icons.warning_amber_rounded,
      'color': Colors.orange,
      'title': 'Risk Disclosure',
      'content': 'Cryptocurrency transactions are volatile and irreversible. Eziplug is not liable for losses arising from user errors, incorrect wallet addresses, or market fluctuations.',
    },
    {
      'icon': Icons.account_balance_wallet_outlined,
      'color': Colors.purple,
      'title': 'Wallet & Custody',
      'content': 'Eziplug may provide custodial and non-custodial wallet services. Users are solely responsible for safeguarding their private keys and passwords.',
    },
    {
      'icon': Icons.swap_horiz_rounded,
      'color': Colors.teal,
      'title': 'Deposits & Withdrawals',
      'content': 'Eziplug supports internal transfers, blockchain transfers (USDT, USDC, BTC, etc.), and merchant transactions. Withdrawal limits are tied to KYC levels.',
    },
    {
      'icon': Icons.savings_outlined,
      'color': Colors.indigo,
      'title': 'Saving Products',
      'content': 'Eziplug offers Saving Products where Users can deposit funds to earn interest. Sub-products may include fixed-term deposits, flexible savings, or target savings. Interest rates vary based on deposit type, amount, and duration.',
    },
    {
      'icon': Icons.copyright_outlined,
      'color': Colors.brown,
      'title': 'Intellectual Property',
      'content': 'All Eziplug trademarks, software, and platform content remain the property of VYCKZ EJ GLOBAL.',
    },
    {
      'icon': Icons.shield_outlined,
      'color': Colors.blueGrey,
      'title': 'Limitation of Liability',
      'content': 'The services are provided "as is." Eziplug is not responsible for indirect, incidental, or consequential damages, including downtime, loss of data, or third-party actions.',
    },
    {
      'icon': Icons.gavel_rounded,
      'color': Colors.deepPurple,
      'title': 'Dispute Resolution',
      'content': 'All disputes shall be resolved by arbitration in Lagos, Nigeria, in accordance with the Rules of Arbitration of the Chartered Institute of Arbitrators (UK).',
    },
    {
      'icon': Icons.edit_note_rounded,
      'color': Colors.cyan,
      'title': 'Amendments and Termination',
      'content': 'Eziplug reserves the right to amend these Terms and the Privacy Policy. Users will be notified of material changes.',
    },
    {
      'icon': Icons.email_outlined,
      'color': AppColors.primary,
      'title': 'Contact',
      'content': 'For support, inquiries, or complaints, contact: support@eziplug.ng',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Header Card
                        _buildHeaderCard(),
                        
                        const SizedBox(height: 24),
                        
                        // Terms Sections
                        ..._sections.asMap().entries.map((entry) {
                          final index = entry.key;
                          final section = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildTermCard(
                              index: index + 1,
                              icon: section['icon'] as IconData,
                              color: section['color'] as Color,
                              title: section['title'] as String,
                              content: section['content'] as String,
                            ),
                          );
                        }),
                        
                        const SizedBox(height: 20),
                        
                        // Footer
                        _buildFooter(),
                        
                        const SizedBox(height: 20),
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
            'Terms of Use',
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

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Terms and Conditions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These Terms constitute a legally binding agreement between you and VYCKZ EJ GLOBAL (RC: 3592966), operating under the brand name Eziplug.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Last Updated: January 2025',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermCard({
    required int index,
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: index <= 2,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade600,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'By using Eziplug, you acknowledge that you have read and agree to these Terms of Use.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
