const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

initializeApp();

const db = getFirestore();
const region = "us-central1";

async function notifyUser({
  userId,
  notificationId,
  title,
  body,
  type,
  analyticsLabel,
  data,
}) {
  const notificationRef = db.collection("notifications").doc(notificationId);
  const userRef = db.collection("users").doc(userId);
  const userSnapshot = await userRef.get();
  const user = userSnapshot.data() || {};
  const tokens = [...new Set([
    ...(Array.isArray(user.fcmTokens) ? user.fcmTokens : []),
    ...(typeof user.fcmToken === "string" ? [user.fcmToken] : []),
  ].filter((token) => typeof token === "string" && token.length > 0))];

  await notificationRef.set({
    userId,
    title,
    body,
    type,
    ...data,
    timestamp: FieldValue.serverTimestamp(),
    isRead: false,
    pushStatus: tokens.length === 0 ? "no_device_token" : "sending",
  });

  if (tokens.length === 0) {
    logger.warn("Notification recorded but user has no registered FCM token.", {
      userId,
      notificationId,
    });
    return;
  }

  const result = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      ...Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, String(value)]),
      ),
      type,
      notificationId,
    },
    android: {
      priority: "high",
      notification: { channelId: "toolverse_notifications" },
      fcmOptions: { analyticsLabel },
    },
    webpush: {
      notification: {
        title,
        body,
        icon: "/favicon.png",
      },
      fcmOptions: { analyticsLabel },
    },
    apns: {
      payload: {
        aps: { sound: "default" },
      },
      fcmOptions: { analyticsLabel },
    },
  });

  const staleTokens = [];
  result.responses.forEach((response, index) => {
    if (
      !response.success &&
      (response.error?.code === "messaging/invalid-registration-token" ||
        response.error?.code === "messaging/registration-token-not-registered")
    ) {
      staleTokens.push(tokens[index]);
    }
  });

  if (staleTokens.length > 0) {
    const tokenCleanup = {
      fcmTokens: FieldValue.arrayRemove(...staleTokens),
    };
    if (staleTokens.includes(user.fcmToken)) {
      tokenCleanup.fcmToken = FieldValue.delete();
    }
    await userRef.update(tokenCleanup);
  }

  await notificationRef.update({
    pushStatus: result.successCount > 0 ? "sent" : "failed",
    pushSentCount: result.successCount,
    pushFailureCount: result.failureCount,
  });
  logger.info("Push notification processed.", {
    userId,
    notificationId,
    analyticsLabel,
    successCount: result.successCount,
    failureCount: result.failureCount,
  });
}

exports.notifyOwnerWhenItemIsAdded = onDocumentCreated(
  {
    document: "items/{itemId}",
    region,
  },
  async (event) => {
    const item = event.data?.data();
    const itemId = event.params.itemId;
    const ownerId = item?.ownerId;

    if (typeof ownerId !== "string" || ownerId.length === 0 || ownerId === "seed") {
      logger.warn("Item created without a registered owner.", { itemId });
      return;
    }

    await notifyUser({
      userId: ownerId,
      notificationId: `item_listed_${itemId}`,
      title: "Your item is listed",
      body: `${item.name || "Your item"} is now available for neighbors to borrow.`,
      type: "status",
      analyticsLabel: "toolverse_item_listed",
      data: { itemId },
    });
  },
);

exports.notifyUsersWhenBookingIsCreated = onDocumentCreated(
  {
    document: "bookings/{bookingId}",
    region,
  },
  async (event) => {
    const booking = event.data?.data();
    const bookingId = event.params.bookingId;
    if (!booking) {
      logger.error("Booking document has no data.", { bookingId });
      return;
    }

    const itemId = booking.itemId;
    const borrowerId = booking.borrowerId;
    if (typeof itemId !== "string" || typeof borrowerId !== "string") {
      logger.error("Booking is missing itemId or borrowerId.", { bookingId });
      return;
    }

    const itemSnapshot = await db.collection("items").doc(itemId).get();
    const ownerId = itemSnapshot.data()?.ownerId;
    if (!itemSnapshot.exists || typeof ownerId !== "string" || ownerId.length === 0) {
      logger.error("Could not resolve booking item owner.", { bookingId, itemId });
      return;
    }

    const itemName = booking.itemName || "An item";
    const notificationData = { bookingId, itemId };
    const deliveries = [
      notifyUser({
        userId: borrowerId,
        notificationId: `booking_created_${bookingId}`,
        title: "Borrow request sent",
        body: `Your request for ${itemName} was sent to the owner.`,
        type: "booking",
        analyticsLabel: "toolverse_booking_confirmation",
        data: notificationData,
      }),
    ];

    if (ownerId !== borrowerId) {
      deliveries.push(
        notifyUser({
          userId: ownerId,
          notificationId: `booking_request_${bookingId}`,
          title: "New booking request",
          body: `${itemName} has a new borrow request.`,
          type: "booking",
          analyticsLabel: "toolverse_booking_request",
          data: notificationData,
        }),
      );
    }

    await Promise.all(deliveries);
  },
);
