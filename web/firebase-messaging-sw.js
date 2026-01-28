importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAMTRkNcgtEbI1mUEGtfC8rhb9MEDmfjE0",
  authDomain: "sira-67284.firebaseapp.com",
  projectId: "sira-67284",
  storageBucket: "sira-67284.firebasestorage.app",
  messagingSenderId: "297037244393",
  appId: "1:297037244393:web:7c3842776b6b41a7fe0d78",
  measurementId: "G-YGVCFTD21J"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event);

  event.notification.close();

  // Handle navigation based on notification data
  const data = event.notification.data;
  let url = '/';

  if (data && data.type) {
    // Customize URL based on notification type
    switch (data.type) {
      case 'order':
        url = `/orders/${data.id}`;
        break;
      case 'visit':
        url = `/visits/${data.id}`;
        break;
      default:
        url = '/';
    }
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open, focus it
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.focus();
          return client.navigate(url);
        }
      }
      // Otherwise, open a new window
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
