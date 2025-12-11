import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock notifications data
    final notifications = [
      {
        'title': 'Nouveau client ajouté',
        'message': 'Le client "Boutique Fashion" a été ajouté à votre liste.',
        'time': 'Il y a 2 heures',
        'type': 'info',
        'read': false,
      },
      {
        'title': 'Visite en retard',
        'message': 'La visite chez "Supermarché Central" est en retard de 30 minutes.',
        'time': 'Il y a 3 heures',
        'type': 'warning',
        'read': false,
      },
      {
        'title': 'Commande confirmée',
        'message': 'La commande #1234 de "Pharmacie du Centre" a été confirmée.',
        'time': 'Il y a 5 heures',
        'type': 'success',
        'read': false,
      },
      {
        'title': 'Synchronisation réussie',
        'message': 'Toutes vos données ont été synchronisées avec le serveur.',
        'time': 'Hier, 18:30',
        'type': 'info',
        'read': true,
      },
      {
        'title': 'Rappel de tournée',
        'message': 'N\'oubliez pas votre tournée prévue pour demain matin.',
        'time': 'Hier, 14:00',
        'type': 'reminder',
        'read': true,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Toutes les notifications marquées comme lues'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Tout lire',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${notifications.where((n) => n['read'] == false).length} non lues',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${notifications.length} notifications au total',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Notifications list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationCard(context, notification);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, Map<String, dynamic> notification) {
    IconData icon;
    Color iconColor;

    switch (notification['type']) {
      case 'warning':
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        break;
      case 'success':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'reminder':
        icon = Icons.schedule;
        iconColor = Colors.blue;
        break;
      case 'info':
      default:
        icon = Icons.info;
        iconColor = Colors.blue;
        break;
    }

    final isRead = notification['read'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: isRead
            ? null
            : Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification['title'] as String,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'] as String,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notification['time'] as String,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notification: ${notification['title']}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}
