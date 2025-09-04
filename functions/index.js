/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

// --- Gemini API Configuration ---
const GEMINI_API_KEY = functions.config().gemini.key;
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;

// Define the commission fee constant
const HELPER_COMMISSION_FEE = 25.0;


// --- AI FILTERING FUNCTION ---
exports.parseFilterQuery = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in to use this feature.");
  }
  const userQuery = data.query;
  if (!userQuery) {
    throw new functions.https.HttpsError("invalid-argument", "The function must be called with one argument 'query'.");
  }
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
        generationConfig: {
          responseMimeType: "application/json",
        },
      }),
    });
    if (!response.ok) {
      throw new functions.https.HttpsError("internal", `API call failed with status: ${response.status}`);
    }
    const result = await response.json();
    if (!result.candidates || !result.candidates[0].content || !result.candidates[0].content.parts[0].text) {
      console.error("Unexpected Gemini API response structure:", result);
      throw new functions.https.HttpsError("internal", "Failed to parse the AI response.");
    }
    const jsonString = result.candidates[0].content.parts[0].text;
    const parsedJson = JSON.parse(jsonString);
    return parsedJson;
  } catch (error) {
    console.error("Error with Gemini API or JSON parsing:", error);
    throw new functions.https.HttpsError("internal", "Failed to parse filter query.", error.message);
  }
});


// --- NEW FUNCTION TO SECURELY ACCEPT OFFERS ---
exports.acceptOffer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in to accept an offer.");
  }

  const posterId = context.auth.uid;
  const {taskId, offerId} = data;

  if (!taskId || !offerId) {
    throw new functions.https.HttpsError("invalid-argument", "The function must be called with 'taskId' and 'offerId'.");
  }

  const taskRef = db.collection("tasks").doc(taskId);
  const offerRef = taskRef.collection("offers").doc(offerId);

  try {
    await db.runTransaction(async (transaction) => {
      const taskDoc = await transaction.get(taskRef);
      const offerDoc = await transaction.get(offerRef);

      if (!taskDoc.exists) throw new functions.https.HttpsError("not-found", "Task not found.");
      if (!offerDoc.exists) throw new functions.https.HttpsError("not-found", "Offer not found.");

      const taskData = taskDoc.data();
      const offerData = offerDoc.data();
      const helperId = offerData?.helperId;

      const helperRef = db.collection("users").doc(helperId);
      const helperDoc = await transaction.get(helperRef);

      if (!helperDoc.exists) throw new functions.https.HttpsError("not-found", "Helper not found.");

      if (taskData?.posterId !== posterId) {
        throw new functions.https.HttpsError("permission-denied", "You are not the owner of this task.");
      }

      if (taskData?.status !== "open" && taskData?.status !== "negotiating") {
        throw new functions.https.HttpsError("failed-precondition", "This task is no longer open for offers.");
      }

      const helperData = helperDoc.data();
      if ((helperData?.servCoinBalance ?? 0) < HELPER_COMMISSION_FEE) {
        throw new functions.https.HttpsError("failed-precondition", "Helper has insufficient coins to cover the commission.");
      }

      const finalAmount = offerData?.amount;
      const helperName = helperData?.displayName ?? "Unknown Helper";

      // --- THIS IS THE FIX: Use '?? null' to prevent 'undefined' errors ---
      const helperAvatarUrl = helperData?.photoURL ?? null;
      const helperPhoneNumber = helperData?.phoneNumber ?? null;

      const posterRef = db.collection("users").doc(posterId);
      const posterDoc = await transaction.get(posterRef);
      const posterPhoneNumber = posterDoc.data()?.phoneNumber ?? null;

      transaction.update(taskRef, {
        "status": "assigned",
        "finalAmount": finalAmount,
        "assignedHelperId": helperId,
        "assignedHelperName": helperName,
        "assignedHelperAvatarUrl": helperAvatarUrl,
        "assignedHelperPhoneNumber": helperPhoneNumber,
        "posterPhoneNumber": posterPhoneNumber,
        "assignmentTimestamp": admin.firestore.FieldValue.serverTimestamp(),
        "participantIds": [posterId, helperId],
        "assignedOfferId": offerId,
      });

      transaction.update(helperRef, {
        "servCoinBalance": admin.firestore.FieldValue.increment(-HELPER_COMMISSION_FEE),
      });

      const transactionRef = helperRef.collection("transactions").doc();
      transaction.set(transactionRef, {
        "amount": -HELPER_COMMISSION_FEE,
        "type": "commission",
        "description": `Commission for task: "${taskData?.title}"`,
        "relatedTaskId": taskId,
        "timestamp": admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(offerRef, {"status": "accepted"});
    });
    return {success: true, message: "Offer accepted successfully!"};
  } catch (error) {
    console.error("Error accepting offer:", error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError("internal", "An unexpected error occurred.");
  }
});


// (The rest of the file is unchanged)
// --- Reusable Notification Helper Function ---
const sendAndSaveNotification = async (userId, title, body, dataPayload = {}) => {
  try {
    await db.collection("users").doc(userId).collection("notifications").add({
      title: title,
      body: body,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ...dataPayload,
    });
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return;
    const fcmTokens = userDoc.data()?.fcmTokens;
    if (fcmTokens && Array.isArray(fcmTokens) && fcmTokens.length > 0) {
      await admin.messaging().sendToDevice(fcmTokens, {notification: {title, body}, data: dataPayload});
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
      if (liveHelpersSnapshot.empty) return null;
      const taskLat = task.location.latitude;
      const taskLon = task.location.longitude;
      const notificationPromises = [];
      const logPromises = [];
      liveHelpersSnapshot.forEach((doc) => {
        const helper = doc.data();
        if (helper.workLocation) {
          const helperLat = helper.workLocation.latitude;
          const helperLon = helper.workLocation.longitude;
          const R = 6371;
          const dLat = (helperLat - taskLat) * (Math.PI / 180);
          const dLon = (helperLon - taskLon) * (Math.PI / 180);
          const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                    Math.cos(taskLat * (Math.PI / 180)) *
                    Math.cos(helperLat * (Math.PI / 180)) *
                    Math.sin(dLon / 2) * Math.sin(dLon / 2);
          const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
          const distance = R * c;
          if (distance <= 10) {
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
      if (!taskDoc.exists) return null;
      const task = taskDoc.data();
      if (!task) return null;
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
    servCoinBalance: 0,
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

// --- Referral System Logic ---
exports.onUserCreateForReferral = functions.firestore
    .document("users/{userId}")
    .onCreate(async (snap, context) => {
      const newUser = snap.data();
      const newUserId = context.params.userId;
      if (!newUser) return null;
      const referringUserId = newUser.referredBy;
      if (!referringUserId) return null;

      const referrerRef = db.collection("users").doc(referringUserId);
      const newUserRef = snap.ref;
      const settingsDoc = await db.collection("settings").doc("platform").get();
      const referralBonus = settingsDoc.exists && settingsDoc.data()?.referralBonus ? settingsDoc.data()?.referralBonus : 500;

      try {
        await db.runTransaction(async (transaction) => {
          const referrerDoc = await transaction.get(referrerRef);
          if (!referrerDoc.exists) throw new Error(`Referrer user ${referringUserId} not found.`);

          transaction.update(referrerRef, {
            servCoinBalance: admin.firestore.FieldValue.increment(referralBonus),
          });
          const referrerTransactionRef = referrerRef.collection("transactions").doc();
          transaction.set(referrerTransactionRef, {
            amount: referralBonus,
            type: "referral_credit",
            message: `Credit for referring ${newUser.displayName || "a new user"}.`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

          transaction.update(newUserRef, {
            servCoinBalance: admin.firestore.FieldValue.increment(referralBonus),
          });
          const newUserTransactionRef = newUserRef.collection("transactions").doc();
          transaction.set(newUserTransactionRef, {
            amount: referralBonus,
            type: "signup_bonus",
            message: "Welcome bonus for using a referral code!",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      } catch (error) {
        console.error("Referral transaction failed: ", error);
      }
      return null;
    });

// --- Admin helper ---
async function assertAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated','Sign in required');
  }
  const uid = context.auth.uid;
  const doc = await db.collection('users').doc(uid).get();
  const m = doc.data() || {};
  const isAdmin = (m.isAdmin === true) || (m.roles && m.roles.admin === true);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied','Admin only');
  }
  return uid;
}


// --- Resolve dispute (admin callable) ---
exports.resolveDisputeAdmin = functions.https.onCall(async (data, context) => {
  const uid = await assertAdmin(context);
  const {disputeId, resolution, posterDelta = 0, helperDelta = 0, notes = ''} = data || {};
  if (!disputeId || !resolution) throw new functions.https.HttpsError('invalid-argument','Missing fields');
  const ref = db.collection('disputes').doc(disputeId);
  await db.runTransaction(async (trx) => {
    const snap = await trx.get(ref);
    const m = snap.data() || {};
    const posterId = m.posterId || '';
    const helperId = m.helperId || '';
    // coin deltas
    async function applyDelta(userId, amt) {
      if (!userId || !amt) return;
      const uref = db.collection('users').doc(userId);
      const usnap = await trx.get(uref);
      const u = usnap.data() || {};
      const prev = u.walletBalance || 0;
      trx.set(uref, {walletBalance: prev + amt, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
      const tx = db.collection('transactions').doc();
      trx.set(tx, {
        userId, type: 'dispute_adjustment', amount: amt, status: 'ok',
        notes: `dispute:${disputeId} ${notes||''}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await applyDelta(posterId, posterDelta);
    await applyDelta(helperId, helperDelta);
    trx.set(ref, {
      status: 'resolved',
      resolution,
      resolutionNotes: notes,
      resolvedBy: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    const audit = db.collection('admin_audit').doc();
    trx.set(audit, {
      actor: uid, action: 'resolve_dispute', disputeId, resolution, posterDelta, helperDelta, notes,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  return {ok:true};
});


// --- Create payout batch (admin callable) ---
exports.createPayoutBatch = functions.https.onCall(async (data, context) => {
  const uid = await assertAdmin(context);
  const lines = (data && Array.isArray(data.lines)) ? data.lines : [];
  if (!lines.length) throw new functions.https.HttpsError('invalid-argument','No lines');
  const total = lines.reduce((acc, l) => acc + (parseInt(l.amount||0,10)||0), 0);
  const batchRef = db.collection('payouts').doc();
  await batchRef.set({
    status: 'pending',
    total, lines,
    createdBy: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  const audit = db.collection('admin_audit').doc();
  await audit.set({actor: uid, action: 'create_payout_batch', batchId: batchRef.id, total, createdAt: admin.firestore.FieldValue.serverTimestamp()});
  return {ok:true, id: batchRef.id};
});

// --- Mark payout paid (admin callable) ---
exports.markPayoutPaid = functions.https.onCall(async (data, context) => {
  const uid = await assertAdmin(context);
  const {batchId, txId} = data || {};
  if (!batchId || !txId) throw new functions.https.HttpsError('invalid-argument','Missing fields');
  const ref = db.collection('payouts').doc(batchId);
  await ref.set({
    status: 'paid',
    txId,
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    paidBy: uid,
  }, {merge: true});
  const audit = db.collection('admin_audit').doc();
  await audit.set({actor: uid, action: 'mark_payout_paid', batchId, txId, createdAt: admin.firestore.FieldValue.serverTimestamp()});
  return {ok:true};
});


// --- Send push campaign (admin callable) ---
exports.sendCampaign = functions.https.onCall(async (data, context) => {
  const uid = await assertAdmin(context);
  const {title, body, category, city, trustMin} = data || {};
  if (!title || !body) throw new functions.https.HttpsError('invalid-argument','Missing title/body');
  const topics = [];
  if (category) {
    topics.push(`tasks_${category.toLowerCase()}`);
    if (city) topics.push(`tasks_${category.toLowerCase()}_${city.toLowerCase()}`);
  } else {
    // fallback: global topic per role or category broadcast
    topics.push('all_helpers');
  }
  for (const topic of topics) {
    await admin.messaging().send({
      notification: {title, body},
      data: {type:'system', audience: topic},
      topic
    });
  }
  const doc = {
    title, body, audience: topics.join(','), trustMin: trustMin||null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: uid,
  };
  await db.collection('campaigns').add(doc);
  return {ok:true, topics};
});
