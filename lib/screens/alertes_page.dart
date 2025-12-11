import 'package:flutter/material.dart';

class AlertesPage extends StatelessWidget {
  const AlertesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock business alerts data
    final alerts = [
      {
        'title': 'Stock faible',
        'message': 'Le produit "Shampoing Pro 500ml" est en rupture chez 3 clients.',
        'client': 'Supermarché Central, Pharmacie du Centre, Boutique Bio',
        'priority': 'high',
        'category': 'stock',
        'date': 'Aujourd\'hui',
      },
      {
        'title': 'Paiement en retard',
        'message': 'Facture #2847 impayée depuis 15 jours.',
        'client': 'Restaurant Le Gourmet',
        'priority': 'high',
        'category': 'payment',
        'date': 'Aujourd\'hui',
      },
      {
        'title': 'Visite manquée',
        'message': 'Visite planifiée non effectuée hier.',
        'client': 'Épicerie Fine Deluxe',
        'priority': 'medium',
        'category': 'visit',
        'date': 'Hier',
      },
      {
        'title': 'Objectif mensuel',
        'message': 'Vous êtes à 65% de votre objectif avec 10 jours restants.',
        'client': null,
        'priority': 'medium',
        'category': 'performance',
        'date': 'Cette semaine',
      },
      {
        'title': 'Client inactif',
        'message': 'Aucune commande depuis 45 jours.',
        'client': 'Magasin Sport Plus',
        'priority': 'low',
        'category': 'client',
        'date': 'Cette semaine',
      },
      {
        'title': 'Nouveau produit disponible',
        'message': 'Le catalogue a été mis à jour avec 12 nouveaux produits.',
        'client': null,
        'priority': 'low',
        'category': 'info',
        'date': 'Il y a 3 jours',
      },
    ];

    // Count alerts by priority
    final highPriority = alerts.where((a) => a['priority'] == 'high').length;
    final mediumPriority = alerts.where((a) => a['priority'] == 'medium').length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Alertes'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Priority Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  _buildPriorityBadge(
                    count: highPriority,
                    label: 'Urgentes',
                    color: Colors.red,
                  ),
                  const SizedBox(width: 12),
                  _buildPriorityBadge(
                    count: mediumPriority,
                    label: 'Moyennes',
                    color: Colors.orange,
                  ),
                  const Spacer(),
                  Text(
                    '${alerts.length} alertes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Alerts List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return _buildAlertCard(context, alert);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge({
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> alert) {
    IconData icon;
    Color iconColor;

    switch (alert['category']) {
      case 'stock':
        icon = Icons.inventory_2;
        iconColor = Colors.purple;
        break;
      case 'payment':
        icon = Icons.payment;
        iconColor = Colors.red;
        break;
      case 'visit':
        icon = Icons.location_off;
        iconColor = Colors.orange;
        break;
      case 'performance':
        icon = Icons.trending_up;
        iconColor = Colors.blue;
        break;
      case 'client':
        icon = Icons.person_off;
        iconColor = Colors.grey;
        break;
      case 'info':
      default:
        icon = Icons.info;
        iconColor = Colors.teal;
        break;
    }

    Color priorityColor;
    String priorityLabel;
    switch (alert['priority']) {
      case 'high':
        priorityColor = Colors.red;
        priorityLabel = 'Urgent';
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityLabel = 'Moyen';
        break;
      case 'low':
      default:
        priorityColor = Colors.grey;
        priorityLabel = 'Faible';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: alert['priority'] == 'high'
            ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and priority
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              priorityLabel,
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert['message'] as String,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      if (alert['client'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                alert['client'] as String,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        alert['date'] as String,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alerte marquée comme résolue'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text('Résoudre'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Voir détails: ${alert['title']}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text('Détails'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
