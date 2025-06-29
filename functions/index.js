/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// --- Triggers to manage the 'participantIds' array for the Activity Screen ---
exports.onTaskCreateForActivity = functions.firestore
    .document("tasks/{taskId}")
    .onCreate((snap, context) => {
      const task = snap.data();
      // On creation, the only participant is the poster
      return snap.ref.set({
        participantIds: [task.posterId],
      }, {merge: true});
    });

exports.onTaskUpdateForActivity = functions.firestore
    .document("tasks/{taskId}")
    .onUpdate((change, context) => {
      const before = change.before.data();
      const after = change.after.data();

      // When a helper is assigned for the first time, add them to the array
      if (!before.assignedHelperId && after.assignedHelperId) {
        return change.after.ref.update({
          participantIds: admin.firestore.FieldValue.arrayUnion(after.assignedHelperId),
        });
      }
      return null;
    });

// --- All your other Cloud Functions (onUserCreate, sendAndSaveNotification, etc.)
// from the previous update should be included here as well. ---

// ===================================================================
// User Management Functions
// ===================================================================
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
  // ... (Full function from previous response)
});

// ===================================================================
// Notification Functions
// ===================================================================
const sendAndSaveNotification = async (userId, title, body, dataPayload = {}) => {
  // ... (Full function from previous response)
};

exports.sendChatNotification = functions.firestore.document("chats/{chatId}/messages/{messageId}").onCreate(async (snap, context) => {
  // ... (Full function from previous response)
});

exports.sendOfferNotification = functions.firestore.document("tasks/{taskId}/offers/{offerId}").onCreate(async (snap, context) => {
  // ... (Full function from previous response)
});

// ... (And so on for all other functions)
