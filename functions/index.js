/**
 * Security System Cloud Functions
 * Handles push notifications for security alerts
 */

const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// Set global options for cost control
setGlobalOptions({
    maxInstances: 10,
    timeoutSeconds: 60,
    memory: '256MB'
});

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Trigger when new alert is added to security pairings
exports.sendSecurityAlert = functions.database
    .ref('/security-pairings/{pairingCode}/alerts/{alertId}')
    .onCreate(async (snapshot, context) => {
        const { pairingCode, alertId } = context.params;
        const alert = snapshot.val();

        // Validate alert data
        if (!alert || !alert.objectLabel) {
            console.log('Invalid alert data, skipping notification');
            return null;
        }

        console.log(`New alert detected for pairing ${pairingCode}: ${alert.objectLabel}`);

        try {
            // Get monitor device FCM token
            const monitorSnapshot = await admin.database()
                .ref(`/security-pairings/${pairingCode}/devices/monitor`)
                .once('value');

            const monitorData = monitorSnapshot.val();
            if (!monitorData || !monitorData.fcmToken) {
                console.log('No monitor FCM token found for pairing:', pairingCode);
                return null;
            }

            console.log(`Found monitor token: ${monitorData.fcmToken.substring(0, 10)}...`);

            // Prepare notification message
            const confidencePercent = Math.round((alert.confidence || 0) * 100);
            const objectLabel = alert.objectLabel || 'Unknown Object';

            const message = {
                token: monitorData.fcmToken,
                notification: {
                    title: '🚨 Security Alert',
                    body: `${objectLabel} detected with ${confidencePercent}% confidence`,
                },
                data: {
                    pairingCode: pairingCode,
                    objectLabel: objectLabel,
                    confidence: String(alert.confidence || 0),
                    timestamp: String(alert.timestamp || Date.now()),
                    alertId: alertId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    type: 'security_alert'
                },
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'security_alerts',
                        priority: 'max',
                        sound: 'default',
                        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                        icon: 'notification_icon',
                        color: '#FF0000'
                    }
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                            badge: 1,
                            contentAvailable: true,
                            alert: {
                                title: '🚨 Security Alert',
                                body: `${objectLabel} detected with ${confidencePercent}% confidence`
                            }
                        }
                    }
                },
                webpush: {
                    notification: {
                        title: '🚨 Security Alert',
                        body: `${objectLabel} detected with ${confidencePercent}% confidence`,
                        icon: '/icons/icon-192.png',
                        badge: '/icons/icon-96.png',
                        vibrate: [200, 100, 200]
                    }
                }
            };

            // Send the notification
            const response = await admin.messaging().send(message);
            console.log('Successfully sent security alert notification:', response);

            // Optional: Update alert with notification status
            await snapshot.ref.update({
                notificationSent: true,
                notificationTime: admin.database.ServerValue.TIMESTAMP
            });

            return response;

        } catch (error) {
            console.error('Error sending security alert notification:', error);

            // Optional: Mark notification as failed
            try {
                await snapshot.ref.update({
                    notificationSent: false,
                    notificationError: error.message
                });
            } catch (updateError) {
                console.error('Error updating alert status:', updateError);
            }

            return null;
        }
    });

// Optional: Clean up old alerts (runs every 24 hours)
exports.cleanupOldAlerts = functions.pubsub
    .schedule('every 24 hours')
    .timeZone('America/New_York')
    .onRun(async (context) => {
        console.log('Running cleanup of old alerts...');

        try {
            const cutoffTime = Date.now() - (30 * 24 * 60 * 60 * 1000); // 30 days ago

            const pairingsSnapshot = await admin.database()
                .ref('security-pairings')
                .once('value');

            const cleanupPromises = [];

            pairingsSnapshot.forEach((pairingSnapshot) => {
                const pairingCode = pairingSnapshot.key;
                const alertsRef = admin.database().ref(`security-pairings/${pairingCode}/alerts`);

                // Remove alerts older than 30 days
                const cleanupPromise = alertsRef.orderByChild('timestamp')
                    .endAt(cutoffTime)
                    .once('value')
                    .then((oldAlertsSnapshot) => {
                        const removePromises = [];
                        oldAlertsSnapshot.forEach((alertSnapshot) => {
                            removePromises.push(alertSnapshot.ref.remove());
                        });
                        return Promise.all(removePromises);
                    });

                cleanupPromises.push(cleanupPromise);
            });

            await Promise.all(cleanupPromises);
            console.log('Old alerts cleanup completed successfully');

        } catch (error) {
            console.error('Error during alerts cleanup:', error);
        }
    });

// Optional: Function to test notifications
exports.testNotification = functions.https.onRequest(async (req, res) => {
    // For security, you might want to add authentication here
    const { pairingCode, fcmToken } = req.body;

    if (!pairingCode || !fcmToken) {
        return res.status(400).json({
            error: 'Missing pairingCode or fcmToken'
        });
    }

    try {
        const message = {
            token: fcmToken,
            notification: {
                title: '🔧 Test Notification',
                body: 'This is a test notification from your security system',
            },
            data: {
                pairingCode: pairingCode,
                type: 'test_notification',
                timestamp: String(Date.now())
            }
        };

        const response = await admin.messaging().send(message);

        res.json({
            success: true,
            messageId: response
        });

    } catch (error) {
        console.error('Test notification error:', error);
        res.status(500).json({
            error: 'Failed to send test notification',
            details: error.message
        });
    }
});
