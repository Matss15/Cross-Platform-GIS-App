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

async function askGemini({apiKey, model, prompt, image}) {
  const parts = [{text: prompt}];
  if (image.startsWith('data:image/')) {
    const [header, encoded] = image.split(',', 2);
    parts.push({
      inlineData: {
        mimeType: header.replace('data:', '').replace(';base64', ''),
        data: encoded,
      },
    });
  }
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      contents: [{role: 'user', parts}],
      generationConfig: {temperature: 0, responseMimeType: 'application/json'},
    }),
  });
  if (!response.ok) throw new Error(`Gemini returned ${response.status}`);
  const payload = await response.json();
  const raw = payload.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || '')
    .join('');
  return JSON.parse(raw || '{}');
}

// AI scope is citizen government-ID validation only. It never approves an account.
exports.reviewCitizenIdWithAi = onDocumentCreated(
  {document: 'users/{userId}', secrets: ['AI_REVIEW_API_KEY']},
  async (event) => {
    const profile = event.data?.data();
    const apiKey = process.env.AI_REVIEW_API_KEY;
    if (!profile || profile.role !== 'resident' || !apiKey) return;
    const image = typeof profile.governmentIdImage === 'string' ? profile.governmentIdImage : '';
    if (!image.startsWith('data:image/')) return;
    const model = process.env.AI_REVIEW_MODEL || 'gemini-2.0-flash';
    try {
      const review = await askGemini({
        apiKey,
        model,
        image,
        prompt: `Review this ${profile.governmentIdType || 'government ID'} image for registration. Return JSON only with documentType, readable (boolean), appearsGovernmentIssued (boolean), confidence (0 to 1), concerns (array), recommendation (manual_review, request_clearer_id, likely_valid, likely_invalid). Advisory only; do not make an identity decision.`,
      });
      const confidence = Number(review.confidence);
      await event.data.ref.update({governmentIdAiReview: {
        status: 'completed',
        documentType: String(review.documentType || 'unclear'),
        readable: review.readable === true,
        appearsGovernmentIssued: review.appearsGovernmentIssued === true,
        confidence: Number.isFinite(confidence) ? Math.max(0, Math.min(1, confidence)) : 0,
        concerns: Array.isArray(review.concerns) ? review.concerns.slice(0, 8).map(String) : [],
        recommendation: String(review.recommendation || 'manual_review'),
        model,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      }});
    } catch (error) {
      logger.error('Citizen ID AI review failed', {userId: event.params.userId, error});
      await event.data.ref.update({governmentIdAiReview: {status: 'error', recommendation: 'manual_review', reviewedAt: admin.firestore.FieldValue.serverTimestamp()}});
    }
  },
);
