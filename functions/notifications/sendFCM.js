async function sendFCMNotification(fcmToken, parsedNotification, uid, notificationId) {
    if (!fcmToken) {
        console.warn(`No FCM token for user ${uid}`);
        return;
    }

    const message = {
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            channel_id: 'focusfuel_channel',  // custom channel
          }
        },
        notification: {
          title: parsedNotification.title || "Stay Hard",
          body: parsedNotification.content || "Your daily dose of motivation is here!"
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'chat',  // for Flutter routing
          notificationId: notificationId,
          userId: uid,
        }
    };

    // sending the notification to FCM servers, remote message listeners are set up in the main.dart
    const { admin } = require("../utils/firebase");
    await admin.messaging().send(message);
};

module.exports = {sendFCMNotification};