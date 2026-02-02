import 'package:cashpoint/screens/auth/forgot_password_screen_enhanced.dart';
import 'package:cashpoint/screens/auth/pin_setup_screen.dart';
import 'package:cashpoint/screens/home/main_screen.dart';
import 'package:cashpoint/screens/profile/about_screen.dart';
import 'package:cashpoint/screens/profile/change_password_screen.dart';
import 'package:cashpoint/screens/profile/change_pin_otp_screen.dart';
import 'package:cashpoint/screens/profile/new_pin_screen.dart';
import 'package:cashpoint/screens/profile/edit_profile_screen.dart';
import 'package:cashpoint/screens/profile/kyc_verification_screen.dart';
import 'package:cashpoint/screens/profile/leaderboard.dart';
import 'package:cashpoint/screens/profile/privacy_policy_screen.dart';
import 'package:cashpoint/screens/profile/support_screen.dart';
import 'package:cashpoint/screens/profile/term_of_use.dart';
import 'package:cashpoint/screens/transactions/airtime_screen.dart';
import 'package:cashpoint/screens/transactions/airtime_swap_screen.dart';
import 'package:cashpoint/screens/transactions/bet_history_screen.dart';
import 'package:cashpoint/screens/transactions/bet_screen.dart';
import 'package:cashpoint/screens/transactions/buy_crypto.dart';
import 'package:cashpoint/screens/transactions/buy_giftcard.dart';
import 'package:cashpoint/screens/transactions/cable_screen.dart';
import 'package:cashpoint/screens/transactions/data_screen.dart';
import 'package:cashpoint/screens/transactions/education_pin_screen.dart';
import 'package:cashpoint/screens/transactions/electricity.dart';
import 'package:cashpoint/screens/transactions/gift_user.dart';
import 'package:cashpoint/screens/transactions/lock_fund.dart';
import 'package:cashpoint/screens/transactions/more_services.dart';
import 'package:cashpoint/screens/transactions/notification_screen.dart';
import 'package:cashpoint/screens/transactions/rate_calculator.dart';
import 'package:cashpoint/screens/transactions/save_and_earn.dart';
import 'package:cashpoint/screens/transactions/sell_crypto.dart';
import 'package:cashpoint/screens/transactions/sell_giftcard.dart';
import 'package:cashpoint/screens/transactions/payout_screen.dart';
import 'package:cashpoint/pages/debug_logs_screen.dart';
import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/register_screen_enhanced.dart';
import 'screens/auth/verification_screen_enhanced.dart';
import 'screens/auth/login_screen_enhanced.dart';
import 'screens/profile/profile_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const register = '/register';
  static const verify = '/verify';
  static const emailVerify = '/email-verify';
  static const pinSetup = '/pin-setup';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const main = '/main';
  static const profile = '/profile';
  static const editProfile = '/editProfile';
  static const changePin = '/changePin';
  static const changePinOtp = '/changePinOtp';
  static const changePassword = '/changePassword';
  static const about = '/about';
  static const termOfUse = '/termOfUse';
  static const support = '/support';
  static const privacyPolicy = '/privacyPolicy';
  static const leaderboard = '/leaderboard';
  static const buyGiftcard = '/buyGiftcard';
  static const sellGiftcard = '/sellGiftcard';
  static const buyCrypto = '/buyCrypto';
  static const sellCrypto = '/sellCrypto';
  static const bet = '/bet';
  static const betHistory = '/bet-history';
  static const rateCalculator = '/rateCalculator';
  static const moreServices = '/moreServices';
  static const giftUser = '/giftUser';
  static const buyAirtime = '/buyAirtime';
  static const airtimeSwap = '/airtimeSwap';
  static const buyData = '/buyData';
  static const buyCable = '/buyCable';
  static const buyElectricity = '/buyElectricity';
  static const educationPin = '/educationPin';
  static const saveAndEarn = '/saveAndEarn';
  static const lockFund = '/lockFund';
  static const notification = '/notification';
  static const kyc = '/kyc';
  static const payoutAccounts = '/payoutAccounts';
  static const debugLogs = '/debug-logs';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case debugLogs:
        return MaterialPageRoute(builder: (_) => const DebugLogsScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case register:
        return MaterialPageRoute(builder: (_) => RegisterScreenEnhanced());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreenEnhanced());
      case verify:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => VerificationScreenEnhanced(
            email: args?['email'] ?? '',
            token: args?['token'] ?? '',
            isEmailVerification: false,
          ),
        );
      case emailVerify:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => VerificationScreenEnhanced(
            email: args?['email'] ?? '',
            token: args?['token'] ?? '',
            isEmailVerification: true,
          ),
        );
      case pinSetup:
        return MaterialPageRoute(builder: (_) => const PinSetupScreen());
      case login:
        // ✅ FIXED: Pass savedEmail to LoginScreen
        final savedEmail = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => LoginScreenEnhanced(savedEmail: savedEmail),
        );
      case main:
        return MaterialPageRoute(builder: (_) => MainScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      case changePin:
        return MaterialPageRoute(builder: (_) => const ChangePinOtpScreen());
      case changePinOtp:
        return MaterialPageRoute(builder: (_) => const NewPinScreen());
      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case about:
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      case termOfUse:
        return MaterialPageRoute(builder: (_) => const TermOfUserScreen());
      case privacyPolicy:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen());
      case support:
        return MaterialPageRoute(builder: (_) => const SupportScreen());
      case leaderboard:
        return MaterialPageRoute(builder: (_) => const LeaderboardScreen());
      case buyGiftcard:
        return MaterialPageRoute(builder: (_) => const BuyGiftCardScreen());
      case sellGiftcard:
        return MaterialPageRoute(builder: (_) => const SellGiftCardScreen());
      case buyCrypto:
        return MaterialPageRoute(
          builder: (_) => const BuyCryptoScreen(cryptoName: ''),
        );
      case sellCrypto:
        return MaterialPageRoute(
          builder: (_) => const SellCryptoScreen(cryptoName: ''),
        );
      case bet:
        return MaterialPageRoute(builder: (_) => const BettingScreen());
      case betHistory:
        return MaterialPageRoute(builder: (_) => const BetHistoryScreen());
      case moreServices:
        return MaterialPageRoute(builder: (_) => const MoreServicesScreen());
      case giftUser:
        return MaterialPageRoute(builder: (_) => const GiftUserScreen());
      case buyAirtime:
        return MaterialPageRoute(builder: (_) => const AirtimeScreen());
      case airtimeSwap:
        return MaterialPageRoute(builder: (_) => const AirtimeSwapScreen());
      case buyData:
        return MaterialPageRoute(builder: (_) => const DataScreen());
      case buyCable:
        return MaterialPageRoute(builder: (_) => const CableScreen());
      case buyElectricity:
        return MaterialPageRoute(builder: (_) => const ElectricityScreen());
      case educationPin:
        return MaterialPageRoute(builder: (_) => const EducationPinScreen());
      case saveAndEarn:
        return MaterialPageRoute(builder: (_) => const SaveAndEarnScreen());
      case lockFund:
        return MaterialPageRoute(builder: (_) => const LockFundScreen());
      case rateCalculator:
        return MaterialPageRoute(builder: (_) => const RateCalculatorScreen());
      case notification:
        return MaterialPageRoute(builder: (_) => const NotificationScreen());
      case kyc:
        return MaterialPageRoute(builder: (_) => const KycVerificationScreen());
      case payoutAccounts:
        return MaterialPageRoute(builder: (_) => const PayoutScreen());

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
    }
  }
}
