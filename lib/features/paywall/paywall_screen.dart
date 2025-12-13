import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _buyPro() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await SubscriptionService().purchasePro();
      if (mounted) {
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Purchase failed. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    try {
      await SubscriptionService().restorePurchases();
      if (mounted) Navigator.pop(context); 
    } catch (e) {
      if (mounted) setState(() => _error = "Restore failed.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, size: 40, color: Colors.indigoAccent),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  "Unlock Pro Benefits",
                  style: GoogleFonts.ebGaramond(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "Elevate your communication with unlimited power.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Features Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                  ]
                ),
                child: Column(
                  children: [
                    _buildFeatureItem(context, "Unlimited Grammar Fixes", Icons.check_circle_outline),
                    const SizedBox(height: 16),
                    _buildFeatureItem(context, "Unlimited Smart Schedule", Icons.calendar_today),
                    const SizedBox(height: 16),
                    _buildFeatureItem(context, "Priority Support", Icons.star_outline),
                  ],
                ),
              ),
              
              const Spacer(),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                ),

              // Price and Button
              Column(
                children: [
                  Text(
                    "\$2.99 / month",
                    style: GoogleFonts.inter(
                      fontSize: 18, 
                      fontWeight: FontWeight.w600,
                      color: textColor
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _buyPro,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C6BC0), // Indigo
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Subscribe Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _restore,
                    child: Text("Restore Purchases", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: Colors.indigoAccent, size: 22),
        const SizedBox(width: 16),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
