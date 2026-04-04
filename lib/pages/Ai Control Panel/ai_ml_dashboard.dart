import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/Ai%20Control%20Panel/tabs/Insights%20Tab/insights_tabs.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/state/userprofile_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:wallone/utils/services/purchase_service.dart';

/// Simplified AI Advisor Dashboard — Only shows InsightsTab
/// Works in both development mode (manual toggle) and production mode (real IAP)
class AIAdvisorDashboard extends StatefulWidget {
  const AIAdvisorDashboard({super.key});

  @override
  State<AIAdvisorDashboard> createState() => _AIAdvisorDashboardState();
}

class _AIAdvisorDashboardState extends State<AIAdvisorDashboard> {
  final PurchaseService _purchaseService = PurchaseService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration.zero); // Let the build fully settle
      final provider = context.read<AIAdvisorProvider>();
      provider.autoRefreshIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, userProvider, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: userProvider.isPremium
                  ? const InsightsTab()
                  : _buildBlurredBackground(),
            ),

            // Premium banner at the center
            if (!userProvider.isPremium)
              Center(
                child: _buildPremiumBanner(context),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBlurredBackground() {
    return Stack(
      children: [
        const InsightsTab(),

        // Blur filter
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.1), // Light dim
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumBanner(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, userProvider, child) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: userProvider.isPremium
                    ? [Colors.amber.shade600, Colors.amber.shade700]
                    : [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (userProvider.isPremium
                          ? Colors.amber.shade600
                          : Colors.deepPurple.shade400)
                      .withAlpha(100),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Premium Icon
                Icon(
                  userProvider.isPremium ? Icons.star : Icons.star_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                // Text section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userProvider.isPremium
                            ? 'Premium Active'
                            : 'Upgrade to Premium',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        userProvider.isPremium
                            ? 'Enjoy all advanced AI features'
                            : 'Unlock advanced insights & analytics',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Button
                GestureDetector(
                  onTap: () => _handlePremiumAction(context, userProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white30,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      userProvider.isPremium ? 'Active' : 'Upgrade',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePremiumAction(
    BuildContext context,
    UserProfileProvider userProvider,
  ) {
    // Show upgrade options
    _showUpgradeDialog(context, userProvider);
  }

  void _showUpgradeDialog(
      BuildContext context, UserProfileProvider userProvider) {
    final products = _purchaseService.products;
    final isDevMode = userProvider.isInDevelopmentMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Text(
                    'Upgrade to Premium',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Benefits List
                ..._buildBenefitsList(),

                const SizedBox(height: 32),

                // Show loading, products, or dev mode option
                if (isDevMode)
                  Center(
                      child: _buildDevModeUpgradeButton(context, userProvider))
                else if (products.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading subscription options...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: budgetTextLight(context),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...products.map((product) =>
                      _buildProductOption(context, product, userProvider)),

                const SizedBox(height: 16),

                // Cancel button
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Maybe later',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevModeUpgradeButton(
      BuildContext context, UserProfileProvider userProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: purpleColors(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await userProvider.setPremium(true);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      '🔧 DEV: Premium activated!',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                backgroundColor: purpleColors(context),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Upgrade Now',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductOption(
    BuildContext context,
    ProductDetails product,
    UserProfileProvider userProvider,
  ) {
    final isAnnual = product.id.contains('annual');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: purpleColors(context).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAnnual ? Colors.amber : Colors.deepPurple.withAlpha(100),
          width: isAnnual ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor(context),
                        ),
                      ),
                    ),
                    if (isAnnual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SAVE 20%',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: budgetTextLight(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  product.price,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  try {
                    // Initiate purchase
                    await _purchaseService.buyProduct(product);

                    // Close loading (purchase flow continues in background)
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                    }
                  } catch (e) {
                    // Close loading
                    if (context.mounted) {
                      Navigator.pop(context);

                      // Show error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Purchase failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    'Subscribe',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBenefitsList() {
    final benefits = [
      'Advanced AI Insights & Analytics',
      'Real-time Financial Recommendations',
      'Ad-free Experience',
    ];

    return benefits.map((benefit) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                benefit,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: primaryColor(context),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
