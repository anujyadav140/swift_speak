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
        Navigator.pop(context, true); // Success
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
      // In a real app, check if restoration was successful (isPro user) before popping
      if (mounted) Navigator.pop(context); 
    } catch (e) {
      if (mounted) setState(() => _error = "Restore failed.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background/Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 60, color: Colors.amber),
                const SizedBox(height: 24),
                Text(
                  "Upgrade to Pro",
                  style: GoogleFonts.ebGaramond(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Unlock unlimited AI corrections and smart scheduling.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                _buildFeatureRow("Unlimited Grammar Fixes"),
                _buildFeatureRow("Unlimited Smart Schedule"),
                _buildFeatureRow("Priority Support"),
                const SizedBox(height: 48),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _buyPro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Get Pro"),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _restore,
                  child: const Text("Restore Purchases", style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
