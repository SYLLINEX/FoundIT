const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

exports.pushOnNotificationCreate = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    region: 'asia-southeast1',
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = data.user_id;
    if (!userId) return;

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data() || {};
    const tokens = Array.isArray(userData.fcm_tokens)
      ? userData.fcm_tokens.filter((t) => typeof t === 'string' && t.trim().length > 0)
      : [];

    if (!tokens.length) return;

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: data.title || 'FoundIT',
        body: data.body || '',
      },
      data: {
        type: String(data.type || 'general'),
        related_item_id: String(data.related_item_id || ''),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'found_it_alerts',
          sound: 'default',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    const invalidTokens = [];
    response.responses.forEach((r, idx) => {
      if (!r.success) {
        const code = r.error?.code || '';
        if (
          code.includes('registration-token-not-registered') ||
          code.includes('invalid-registration-token')
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await admin.firestore().collection('users').doc(userId).set(
        {
          fcm_tokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        },
        { merge: true }
      );
    }
  }
);
