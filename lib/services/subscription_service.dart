import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/user_stats.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Singleton instance
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Observable for subscription status
  final StreamController<bool> _isProController = StreamController<bool>.broadcast();
  Stream<bool> get isProStream => _isProController.stream;

  Set<String> _productIds = {'pro_monthly'}; // Define your product ID here

  /// Initialize IAP
  Future<void> init() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint("IAP not available");
      return;
    }

    // Listen to purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      debugPrint("IAP Stream Done");
    }, onError: (error) {
      debugPrint("IAP Stream Error: $error");
    });
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // UI can show a spinner
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Purchase Error: ${purchaseDetails.error}");
          // Handle error UI if needed
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          await _verifyPurchase(purchaseDetails); // Verify and Deliver content
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a real app, verify the token server-side with Google Play Developer API
    // For now, we trust the successful callback and update Firestore
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Logic to check if it's the specific 'pro_monthly' product
      if (purchaseDetails.productID == 'pro_monthly') {
          await _setProStatus(user.uid, true);
      }
    }
  }

  Future<void> _setProStatus(String userId, bool isPro) async {
      await _firestore.collection('users').doc(userId).set({
        'subscriptionTier': isPro ? 'PRO' : 'FREE',
      }, SetOptions(merge: true));
      
      _isProController.add(isPro);
  }


  /// Purchase PRO subscription
  Future<void> purchasePro() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
        throw Exception("Store not available");
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint("Products not found: ${response.notFoundIDs}");
      // Assuming 'pro_monthly' might not be set up in the store yet, 
      // but we proceed with the code logic. 
    }
    
    if (response.productDetails.isEmpty) {
        debugPrint("No product details found.");
        throw Exception("Product not found");
    }

    final ProductDetails productDetails = response.productDetails.first; // Assuming only one pro product
    
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // For subscription on Android/iOS
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }
  
  /// Restore purchases
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  /// Checks if the user can perform an action costing [tokens].
  /// Throws [QuotaExceededException] if limit reached.
  Future<void> checkUsageLimit(String userId, int tokensToAdd) async {
    final docRef = _firestore.collection('users').doc(userId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return; 

    UserStats userStats = UserStats.fromMap(snapshot.data()!);

    // 1. Check if user is PRO
    if (userStats.isPro) return;

    // 2. Check Reset Period 
    final now = DateTime.now();
    if (userStats.billingPeriodEnd == null || now.isAfter(userStats.billingPeriodEnd!)) {
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
}

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException([this.message = "Weekly usage limit exceeded. Upgrade to Pro for unlimited access."]);
  
  @override
  String toString() => message;
}
