/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

// --- Gemini API Configuration ---
// IMPORTANT: For production, store your key in an environment variable
// Run this command in your terminal: firebase functions:config:set gemini.key="YOUR_API_KEY"
const GEMINI_API_KEY = functions.config().gemini.key;
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;


// --- NEW AI FILTERING FUNCTION ---
// This is a "Callable Function" that your Flutter app will invoke directly.
exports.parseFilterQuery = functions.https.onCall(async (data, context) => {
  // Ensure the user is authenticated to prevent abuse
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in to use this feature.");
  }

  const userQuery = data.query;
  if (!userQuery) {
    throw new functions.https.HttpsError("invalid-argument", "The function must be called with one argument 'query'.");
  }

  // A carefully engineered prompt to get structured JSON back from the AI
  const prompt = `
    Analyze the following user query for a service app in Sri Lanka. Extract the following entities:
    - category (e.g., "Plumbing", "Electrician", "Graphic Design")
    - location (e.g., "Colombo", "Kandy", "Galle")
    - max_budget (a number, for queries like "under 10000")
    - isVerified (true if the user asks for "verified", "trusted", or "professional" helpers)

    Respond ONLY with a valid JSON object. Do not include any other text or markdown.
    If an entity is not mentioned, do not include its key in the JSON.

    User Query: "${userQuery}"

    JSON Response:
  `;

  try {
    const response = await fetch(GEMINI_API_URL, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        contents: [{parts: [{text: prompt}]}],
        // Enforce JSON output
        generationConfig: {
          responseMimeType: "application/json",
        },
      }),
    });

    if (!response.ok) {
      throw new functions.https.HttpsError("internal", `API call failed with status: ${response.status}`);
    }

    const result = await response.json();
    // Defensive check for candidate content
    if (!result.candidates || !result.candidates[0].content || !result.candidates[0].content.parts[0].text) {
        console.error("Unexpected Gemini API response structure:", result);
        throw new functions.https.HttpsError("internal", "Failed to parse the AI response.");
    }
    const jsonString = result.candidates[0].content.parts[0].text;
    const parsedJson = JSON.parse(jsonString);

    // Return the parsed JSON object to the Flutter app
    return parsedJson;
  } catch (error) {
    console.error("Error with Gemini API or JSON parsing:", error);
    throw new functions.https.HttpsError("internal", "Failed to parse filter query.", error.message);
  }
});


// --- Reusable Notification Helper Function ---
/**
 * Sends a push notification and saves a record in the user's notification subcollection.
 * @param {string} userId The ID of the user to notify.
 * @param {string} title The title of the notification.
 * @param {string} body The body text of the notification.
 * @param {object} [dataPayload={}] Optional data to send with the notification.
 */
const sendAndSaveNotification = async (userId, title, body, dataPayload = {}) => {
  try {
    // Save the notification to the user's subcollection
    await db.collection("users").doc(userId).collection("notifications").add({
      title: title,
      body: body,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ...dataPayload,
    });

    // Get the user's FCM tokens to send a push notification
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User ${userId} not found, cannot send notification.`);
      return;
    }
    const fcmTokens = userDoc.data().fcmTokens;

    if (fcmTokens && Array.isArray(fcmTokens) && fcmTokens.length > 0) {
      const payload = {
        notification: {title, body},
        data: dataPayload,
      };
      await admin.messaging().sendToDevice(fcmTokens, payload);
    }
  } catch (error) {
    console.error(`Error sending notification to ${userId}:`, error);
  }
};

// --- Triggers for Task Management and Activity Feed ---
exports.onTaskCreateForActivity = functions.firestore
    .document("tasks/{taskId}")
    .onCreate((snap, context) => {
      const task = snap.data();
      if (!task.posterId) return null;
      const chatRef = db.collection("chats").doc();
      return db.runTransaction(async (transaction) => {
        transaction.set(snap.ref, {
          participantIds: [task.posterId],
          chatId: chatRef.id,
        }, {merge: true});
        transaction.set(chatRef, {
          taskId: snap.id,
          participantIds: [task.posterId],
          isTaskChat: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    });

exports.onTaskUpdateForActivity = functions.firestore
    .document("tasks/{taskId}")
    .onUpdate((change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      if (!before.assignedHelperId && after.assignedHelperId) {
        const chatRef = db.collection("chats").doc(after.chatId);
        return db.runTransaction(async (transaction) => {
          transaction.update(change.after.ref, {
            participantIds: admin.firestore.FieldValue.arrayUnion(after.assignedHelperId),
          });
          transaction.update(chatRef, {
            participantIds: admin.firestore.FieldValue.arrayUnion(after.assignedHelperId),
          });
        });
      }
      return null;
    });

// --- Cloud Function for "Task Radio" ---
exports.onUrgentTaskCreate = functions.firestore
    .document("tasks/{taskId}")
    .onCreate(async (snap, context) => {
      const task = snap.data();
      if (!task.isUrgent || !task.location) return null;
      const liveHelpersSnapshot = await db.collection("users")
          .where("isLive", "==", true)
          .where("isHelper", "==", true)
          .get();
      if (liveHelpersSnapshot.empty) {
        console.log("No live helpers found for urgent task.");
        return null;
      }
      const taskLat = task.location.latitude;
      const taskLon = task.location.longitude;
      const notificationPromises = [];
      const logPromises = [];
      liveHelpersSnapshot.forEach((doc) => {
        const helper = doc.data();
        if (helper.workLocation) {
          const helperLat = helper.workLocation.latitude;
          const helperLon = helper.workLocation.longitude;
          const R = 6371; // Radius of Earth in kilometers
          const dLat = (helperLat - taskLat) * (Math.PI / 180);
          const dLon = (helperLon - taskLon) * (Math.PI / 180);
          const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                    Math.cos(taskLat * (Math.PI / 180)) *
                    Math.cos(helperLat * (Math.PI / 180)) *
                    Math.sin(dLon / 2) * Math.sin(dLon / 2);
          const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
          const distance = R * c;
          if (distance <= 10) { // Notify helpers within a 10km radius
            notificationPromises.push(sendAndSaveNotification(
                doc.id,
                "🚨 Urgent Task Nearby!",
                `"${task.title}" is just ${distance.toFixed(1)}km away.`,
                {type: "task_details", relatedId: snap.id},
            ));
            logPromises.push(
                snap.ref.collection("urgent_notifications_log").add({
                  helperId: doc.id,
                  helperName: helper.displayName || "Unknown Helper",
                  distance: distance,
                  timestamp: admin.firestore.FieldValue.serverTimestamp(),
                }),
            );
          }
        }
      });
      return Promise.all([...notificationPromises, ...logPromises]);
    });

// --- Automated Content Moderation ---
exports.onNewTaskScan = functions.firestore
    .document("tasks/{taskId}")
    .onCreate(async (snap, context) => {
      const task = snap.data();
      const contentToScan = `${task.title} ${task.description}`;
      const prompt = `Analyze the following text for harmful content (like hate speech, harassment, violence, or explicit content). Respond with a single word: "Safe" or "Unsafe". Text: "${contentToScan}"`;
      try {
        const response = await fetch(GEMINI_API_URL, {
          method: "POST",
          headers: {"Content-Type": "application/json"},
          body: JSON.stringify({contents: [{parts: [{text: prompt}]}]}),
        });
        if (!response.ok) {
          throw new Error(`API call failed with status: ${response.status}`);
        }
        const result = await response.json();
        const classification = result.candidates[0].content.parts[0].text.trim();
        if (classification.includes("Unsafe")) {
          await snap.ref.update({status: "under_review"});
          await db.collection("reports").add({
            contentType: "task",
            reportedContentId: snap.id,
            contentSnippet: task.title,
            reason: "Automatically flagged by AI for harmful content.",
            reporterId: "system_ai",
            reporterName: "Community Watch AI",
            reportedUserId: task.posterId,
            status: "pending",
            reportedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } catch (error) {
        console.error("Error with Gemini API during content scan:", error);
      }
    });

// --- Notification Triggers ---
exports.sendOfferNotification = functions.firestore
    .document("tasks/{taskId}/offers/{offerId}")
    .onCreate(async (snap, context) => {
      const offer = snap.data();
      const taskDoc = await db.collection("tasks").doc(offer.taskId).get();
      if (!taskDoc.exists) {
          console.error(`Task ${offer.taskId} not found for offer ${snap.id}`);
          return null;
      }
      const task = taskDoc.data();
      return sendAndSaveNotification(
          task.posterId,
          `New Offer for "${task.title}"`,
          `${offer.helperName} has made an offer of LKR ${offer.amount}.`,
          {type: "task_offer", relatedId: offer.taskId},
      );
    });

exports.onUserCreateSetup = functions.auth.user().onCreate((user) => {
  return db.collection("users").doc(user.uid).set({
    email: user.email,
    displayName: user.displayName,
    photoURL: user.photoURL,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isHelper: false,
    trustScore: 10,
    walletBalance: 0, // Initialize wallet balance
  }, {merge: true});
});


// --- Verification Logic ---
exports.onUserStatusChange = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      const userId = context.params.userId;

      if (before.verificationStatus === "pending" && before.verificationStatus !== after.verificationStatus) {
        let title = "Verification Update";
        let body = "Your Servana verification status has been updated.";
        let type = "verification_update";

        if (after.verificationStatus === "verified") {
          title = "🎉 Congratulations, you're verified!";
          body = "Your profile has been approved. You can now start accepting tasks.";
          type = "verification_approved";
          await change.after.ref.update({
            trustScore: admin.firestore.FieldValue.increment(50),
          });
        } else if (after.verificationStatus === "rejected") {
          title = "Verification Update";
          body = "There was an issue with your submitted documents. Please review and contact support.";
          type = "verification_rejected";
        }
        return sendAndSaveNotification(userId, title, body, {type: type, relatedId: userId});
      }
      return null;
    });


// --- [REVISED & FIXED] Referral System Logic ---
exports.onUserCreateForReferral = functions.firestore
    .document("users/{userId}")
    .onCreate(async (snap, context) => {
        const newUser = snap.data();
        const newUserId = context.params.userId;
        const referringUserId = newUser.referredBy;

        if (!referringUserId) {
            console.log(`User ${newUserId} was not referred.`);
            return null;
        }

        const referrerRef = db.collection("users").doc(referringUserId);
        const newUserRef = snap.ref;

        const settingsDoc = await db.collection('settings').doc('platform').get();
        const referralBonus = settingsDoc.exists && settingsDoc.data().referralBonus ? settingsDoc.data().referralBonus : 500;

        try {
            await db.runTransaction(async (transaction) => {
                const referrerDoc = await transaction.get(referrerRef);
                if (!referrerDoc.exists) {
                    throw new Error(`Referrer user ${referringUserId} not found.`);
                }

                // 1. Update the referrer's balance and add their transaction log
                transaction.update(referrerRef, {
                    walletBalance: admin.firestore.FieldValue.increment(referralBonus)
                });
                const referrerTransactionRef = referrerRef.collection("wallet_transactions").doc();
                transaction.set(referrerTransactionRef, {
                    amount: referralBonus,
                    type: "referral_credit",
                    message: `Credit for referring ${newUser.displayName || "a new user"}.`,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                });

                // 2. Update the new user's balance and add their transaction log
                transaction.update(newUserRef, {
                    walletBalance: admin.firestore.FieldValue.increment(referralBonus)
                });
                const newUserTransactionRef = newUserRef.collection("wallet_transactions").doc();
                transaction.set(newUserTransactionRef, {
                    amount: referralBonus,
                    type: "signup_bonus",
                    message: "Welcome bonus for using a referral code!",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                });
            });
            console.log(`Successfully processed referral for ${newUserId} from ${referringUserId}.`);
        } catch (error) {
            console.error("Referral transaction failed: ", error);
        }

        return null;
    });
