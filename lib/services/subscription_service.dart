import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/user_stats.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Singleton instance
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  /// Initialize RevenueCat securely by fetching config from Cloud Functions
  Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    try {
      // Fetch secure config
      final result = await _functions.httpsCallable('getSubscriptionConfig').call();
      final data = result.data as Map<dynamic, dynamic>;
      
      String? apiKey;
      if (defaultTargetPlatform == TargetPlatform.android) {
         apiKey = data['revenueCatApiKeyAndroid'] as String?;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
         apiKey = data['revenueCatApiKeyIos'] as String?;
      }

      if (apiKey != null) {
        await Purchases.configure(PurchasesConfiguration(apiKey));
        
        // Listen for subscription changes
        Purchases.addCustomerInfoUpdateListener((customerInfo) {
          _handleCustomerInfo(customerInfo);
        });
      }
    } catch (e) {
      debugPrint("Failed to initialize SubscriptionService: $e");
      // Fallback or disable premium features gracefully
    }
  }

  /// Checks if the user can perform an action costing [tokens].
  /// Throws [QuotaExceededException] if limit reached.
  Future<void> checkUsageLimit(String userId, int tokensToAdd) async {
    final docRef = _firestore.collection('users').doc(userId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return; // Assume new user is fine or handle separately

    UserStats userStats = UserStats.fromMap(snapshot.data()!);

    // 1. Check if user is PRO
    if (userStats.isPro) return;

    // 2. Check Reset Period (Client side check for UI speed, validated eventually by server reset)
    final now = DateTime.now();
    if (userStats.billingPeriodEnd == null || now.isAfter(userStats.billingPeriodEnd!)) {
      // Trigger reset logic (ideally this is also server-side, but keeping client trigger for now)
      await _resetUsage(userId);
      return; 
    }

    // 3. Check Limit
    if (userStats.tokenUsageCurrentPeriod + tokensToAdd >= UserStats.freeTierWeeklyLimit) {
      throw QuotaExceededException();
    }
  }

  /// Updates usage after a successful generation via Cloud Function
  Future<void> incrementUsage(String userId, int tokensUsed) async {
    try {
      await _functions.httpsCallable('logTokenUsage').call({
        'tokens': tokensUsed,
      });
    } catch (e) {
      debugPrint("Failed to log usage: $e");
      // Fallback: Optimistic local update via Firestore directly if function fails?
      // For now, fail silently or fallback to direct write if critically needed.
    }
  }

  Future<void> _resetUsage(String userId) async {
    final docRef = _firestore.collection('users').doc(userId);
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    
    await docRef.set({
      'tokenUsageCurrentPeriod': 0,
      'billingPeriodEnd': Timestamp.fromDate(nextWeek),
    }, SetOptions(merge: true));
  }

  /// Purchase PRO subscription
  Future<void> purchasePro() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        // Purchase the first available package in the current offering
        final package = offerings.current!.availablePackages.first;
        await Purchases.purchasePackage(package);
        // Listener dealing with update automatically
      } else {
        debugPrint("No offerings available");
      }
    } catch (e) {
      debugPrint("Purchase failed: $e");
      rethrow;
    }
  }
  
  /// Restore purchases
  Future<void> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      await _handleCustomerInfo(customerInfo);
    } catch (e) {
       debugPrint("Restore failed: $e");
    }
  }

  Future<void> _handleCustomerInfo(CustomerInfo customerInfo) async {
     // Check if entitlement is active
     final isPro = customerInfo.entitlements.all["pro"]?.isActive ?? false;
     debugPrint("Subscription Updated. isPro: $isPro");

     final user = FirebaseAuth.instance.currentUser;
     if (user != null) {
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'subscriptionTier': isPro ? 'PRO' : 'FREE',
        }, SetOptions(merge: true));
     }
  }
}

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException([this.message = "Weekly usage limit exceeded. Upgrade to Pro for unlimited access."]);
  
  @override
  String toString() => message;
}
