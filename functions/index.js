const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendBfpEmergencyPush = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const notification = event.data?.data();
    if (!notification || notification.type !== 'emergency') return;

    const userRef = admin.firestore().doc(`users/${notification.uid}`);
    const userSnapshot = await userRef.get();
    const tokens = userSnapshot.data()?.fcmTokens || [];
    if (!tokens.length) return;

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: notification.title || 'BFP emergency alert',
        body: notification.body || 'Open BFP Rosario GIS for incident details.',
      },
      data: {
        type: 'emergency',
        incidentId: notification.incidentId || '',
        priority: notification.priority || 'High',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'emergency_alerts',
          sound: 'default',
          priority: 'max',
        },
      },
    });

    const invalidTokens = [];
    response.responses.forEach((result, index) => {
      const code = result.error?.code || '';
      if (code.includes('registration-token-not-registered') ||
          code.includes('invalid-registration-token')) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length) {
      await userRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }

    logger.info('BFP emergency push sent', {
      notificationId: event.params.notificationId,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  },
);
