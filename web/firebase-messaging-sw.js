
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBU1-wU6Scs4YthhTM65AQOMXoclQlqW9E",
  appId: "1:1077366281264:web:9a6999529174c36d3d09f5",
  messagingSenderId: "1077366281264",
  projectId: "toolverse-kesh",
  authDomain: "toolverse-kesh.firebaseapp.com",
  storageBucket: "toolverse-kesh.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log(
    "[firebase-messaging-sw.js] Received background message:",
    payload
  );

  const notificationTitle =
    payload.notification?.title ||
    payload.data?.title ||
    "ToolVerse Notification";

  const notificationOptions = {
    body:
      payload.notification?.body ||
      payload.data?.body ||
      "You have a new update.",
    icon: "/favicon.png",
    data: payload.data || {},
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});
