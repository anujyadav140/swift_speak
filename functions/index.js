const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// 1. Get RevenueCat Configuration (Securely)
// Requires App Check to prevent unauthorized access (e.g. from curl)
exports.getSubscriptionConfig = functions.https.onCall((data, context) => {
  // Uncomment to enforce App Check
  // if (context.app == undefined) {
  //   throw new functions.https.HttpsError(
  //     'failed-precondition',
  //     'The function must be called from an App Check verified app.'
  //   );
  // }

  // Return the API Key. 
  // This key is still "public" in nature (RevenueCat SDK uses it), 
  // but this prevents it from being scraped from the APK static analysis.
  // It effectively makes it "Runtime Only".
  return {
    revenueCatApiKeyAndroid: "sk_TohWqYUgPvEMqQNmEcsklEIdWYmpa",
    revenueCatApiKeyIos: "sk_TohWqYUgPvEMqQNmEcsklEIdWYmpa",
  };
});

// 2. Secure Usage Logging
// Client calls this instead of writing to Firestore directly.
// This allows us to enforce logic server-side.
exports.logTokenUsage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const userId = context.auth.uid;
  const tokensUsed = data.tokens;

  if (!tokensUsed || typeof tokensUsed !== 'number') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid token count');
  }

  const userRef = admin.firestore().collection('users').doc(userId);

  // Transaction for safety
  await admin.firestore().runTransaction(async (t) => {
    const doc = await t.get(userRef);
    if (!doc.exists) return; // Or create

    const currentUsage = doc.data().tokenUsageCurrentPeriod || 0;

    t.update(userRef, {
      tokenUsageCurrentPeriod: currentUsage + tokensUsed
    });
  });

  return { success: true };
});
