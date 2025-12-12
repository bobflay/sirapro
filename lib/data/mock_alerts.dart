import '../models/alert.dart';

/// Mock alerts data linked to clients
final List<Alert> mockAlerts = [
  // Urgent alerts
  Alert(
    id: 'alert-001',
    title: 'Rupture totale de Coca-Cola',
    description: 'Le client signale une rupture totale de Coca-Cola depuis 3 jours. '
        'Il s\'agit d\'un produit phare qui génère 30% de son CA. '
        'Le client menace de se tourner vers la concurrence si le problème persiste.',
    type: AlertType.ruptureGrave,
    priority: AlertPriority.urgent,
    clientId: '1',
    clientName: 'Supermarché Bonheur',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3600,
      longitude: -4.0083,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),

  Alert(
    id: 'alert-002',
    title: 'Litige sur paiement facture du mois dernier',
    description: 'Le client conteste le montant de la facture du mois dernier. '
        'Il affirme avoir reçu seulement 45 cartons au lieu des 50 facturés. '
        'Photos des bons de livraison disponibles. Montant en litige: 175,000 FCFA.',
    type: AlertType.litigeProbleme,
    priority: AlertPriority.urgent,
    clientId: '3',
    clientName: 'Demi-Gros Akissi',
    status: AlertStatus.inProgress,
    location: GpsLocation(
      latitude: 5.3267,
      longitude: -4.0305,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    comment: 'Commercial en cours de vérification avec le service logistique',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),

  Alert(
    id: 'alert-003',
    title: 'Risque de perte du client Cash & Carry Diallo',
    description: 'Client A très mécontent. La concurrence lui propose des prix 8% plus bas '
        'et une livraison en 24h au lieu de 48h. Le client envisage sérieusement de changer '
        'de fournisseur dès le mois prochain. CA annuel: 48M FCFA.',
    type: AlertType.risquePerte,
    priority: AlertPriority.urgent,
    clientId: '6',
    clientName: 'Cash & Carry Diallo',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.2832,
      longitude: -4.0180,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),

  // High priority alerts
  Alert(
    id: 'alert-004',
    title: 'Problème de disposition des produits au rayon',
    description: 'Les produits concurrents sont mieux placés (hauteur des yeux) que nos produits. '
        'Nos articles sont en bas du rayon, difficilement visibles. '
        'Le gérant demande une négociation sur l\'espace de présentation.',
    type: AlertType.problemeRayon,
    priority: AlertPriority.high,
    clientId: '1',
    clientName: 'Supermarché Bonheur',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3600,
      longitude: -4.0083,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),

  Alert(
    id: 'alert-005',
    title: 'Nouvelle opportunité: Extension du magasin',
    description: 'Le client prévoit d\'agrandir sa surface de vente de 40% dans 2 mois. '
        'Il cherche un fournisseur principal pour la nouvelle section boissons et snacks. '
        'Budget estimé: 15M FCFA pour le stock initial.',
    type: AlertType.opportunite,
    priority: AlertPriority.high,
    clientId: '2',
    clientName: 'Alimentation Chez Adjoua',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3364,
      longitude: -4.0742,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),

  Alert(
    id: 'alert-006',
    title: 'Rupture de plusieurs références d\'huile',
    description: 'Rupture simultanée de 3 références d\'huile (Dinor 5L, Violette 5L, et Golden 2L). '
        'Le client a dû refuser plusieurs ventes aujourd\'hui. '
        'Il demande une livraison en urgence.',
    type: AlertType.ruptureGrave,
    priority: AlertPriority.high,
    clientId: '4',
    clientName: 'Épicerie du Marché',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3515,
      longitude: -4.0228,
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
  ),

  Alert(
    id: 'alert-007',
    title: 'Demande spéciale: Produits pour événement',
    description: 'Le client organise une fête de quartier dans 10 jours et souhaite une commande '
        'spéciale de 200 cartons de boissons variées avec des conditions de paiement à 30 jours. '
        'Commande estimée: 3.5M FCFA.',
    type: AlertType.demandeSpeciale,
    priority: AlertPriority.high,
    clientId: '1',
    clientName: 'Supermarché Bonheur',
    status: AlertStatus.inProgress,
    comment: 'Demande transmise au service commercial pour validation',
    location: GpsLocation(
      latitude: 5.3600,
      longitude: -4.0083,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),

  // Medium priority alerts
  Alert(
    id: 'alert-008',
    title: 'Retard de paiement de 15 jours',
    description: 'Le client accuse un retard de paiement de 15 jours. '
        'Montant dû: 850,000 FCFA. Le gérant promet de régulariser sous 5 jours '
        'après réception d\'un paiement client important.',
    type: AlertType.litigeProbleme,
    priority: AlertPriority.medium,
    clientId: '4',
    clientName: 'Épicerie du Marché',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3515,
      longitude: -4.0228,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),

  Alert(
    id: 'alert-009',
    title: 'Demande de formation sur nouveaux produits',
    description: 'Le client souhaite une formation pour son personnel de vente sur les nouveaux '
        'produits de la gamme premium. Il veut mieux conseiller ses clients et augmenter ses ventes.',
    type: AlertType.demandeSpeciale,
    priority: AlertPriority.medium,
    clientId: '3',
    clientName: 'Demi-Gros Akissi',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3267,
      longitude: -4.0305,
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
  ),

  Alert(
    id: 'alert-010',
    title: 'Problème de dates de péremption courtes',
    description: 'Le client a reçu plusieurs lots de produits avec des dates de péremption '
        'à moins de 2 mois. Il demande un échange ou une remise compensatoire de 10%.',
    type: AlertType.problemeRayon,
    priority: AlertPriority.medium,
    clientId: '5',
    clientName: 'Mini Market Traoré',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.2789,
      longitude: -3.9884,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),

  Alert(
    id: 'alert-011',
    title: 'Opportunité de partenariat pour livraison groupée',
    description: 'Le client propose de coordonner ses commandes avec 3 autres boutiques du quartier '
        'pour bénéficier de tarifs de gros et partager les frais de livraison.',
    type: AlertType.opportunite,
    priority: AlertPriority.medium,
    clientId: '2',
    clientName: 'Alimentation Chez Adjoua',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3364,
      longitude: -4.0742,
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),

  // Low priority alerts
  Alert(
    id: 'alert-012',
    title: 'Suggestion d\'ajout de nouveaux produits',
    description: 'Le client suggère d\'ajouter des produits bio et naturels à notre catalogue. '
        'Il constate une demande croissante de sa clientèle pour ce type de produits.',
    type: AlertType.other,
    priority: AlertPriority.low,
    clientId: '1',
    clientName: 'Supermarché Bonheur',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.3600,
      longitude: -4.0083,
      timestamp: DateTime.now().subtract(const Duration(days: 7)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 7)),
  ),

  Alert(
    id: 'alert-013',
    title: 'Demande de matériel publicitaire',
    description: 'Le client demande des affiches, des présentoirs et des banderoles '
        'pour mieux mettre en valeur nos produits dans son magasin.',
    type: AlertType.demandeSpeciale,
    priority: AlertPriority.low,
    clientId: '6',
    clientName: 'Cash & Carry Diallo',
    status: AlertStatus.pending,
    location: GpsLocation(
      latitude: 5.2832,
      longitude: -4.0180,
      timestamp: DateTime.now().subtract(const Duration(days: 6)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 6)),
  ),

  // Resolved alerts (for history)
  Alert(
    id: 'alert-014',
    title: 'Rupture de Nescafé Classic résolu',
    description: 'Rupture de Nescafé Classic signalée il y a 3 jours. '
        'Livraison effectuée en urgence de 50 cartons.',
    type: AlertType.ruptureGrave,
    priority: AlertPriority.urgent,
    clientId: '3',
    clientName: 'Demi-Gros Akissi',
    status: AlertStatus.resolved,
    comment: 'Livraison urgente effectuée le lendemain. Client satisfait.',
    location: GpsLocation(
      latitude: 5.3267,
      longitude: -4.0305,
      timestamp: DateTime.now().subtract(const Duration(days: 8)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
    resolvedAt: DateTime.now().subtract(const Duration(days: 5)),
  ),

  Alert(
    id: 'alert-015',
    title: 'Problème de facturation corrigé',
    description: 'Erreur de facturation détectée: produits facturés en double. '
        'Montant: 245,000 FCFA.',
    type: AlertType.litigeProbleme,
    priority: AlertPriority.high,
    clientId: '6',
    clientName: 'Cash & Carry Diallo',
    status: AlertStatus.resolved,
    comment: 'Avoir émis et appliqué sur la facture suivante',
    location: GpsLocation(
      latitude: 5.2832,
      longitude: -4.0180,
      timestamp: DateTime.now().subtract(const Duration(days: 10)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    resolvedAt: DateTime.now().subtract(const Duration(days: 7)),
  ),

  Alert(
    id: 'alert-016',
    title: 'Nouvelle commande spéciale livrée',
    description: 'Commande spéciale pour ouverture d\'une nouvelle section du magasin. '
        'Montant: 2.8M FCFA.',
    type: AlertType.opportunite,
    priority: AlertPriority.high,
    clientId: '2',
    clientName: 'Alimentation Chez Adjoua',
    status: AlertStatus.resolved,
    comment: 'Commande livrée et payée. Client très satisfait, envisage de renouveler.',
    location: GpsLocation(
      latitude: 5.3364,
      longitude: -4.0742,
      timestamp: DateTime.now().subtract(const Duration(days: 15)),
    ),
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
    resolvedAt: DateTime.now().subtract(const Duration(days: 12)),
  ),
];

/// Get all alerts
List<Alert> getAllAlerts() {
  return List.from(mockAlerts);
}

/// Get alerts by status
List<Alert> getAlertsByStatus(AlertStatus status) {
  return mockAlerts.where((alert) => alert.status == status).toList();
}

/// Get pending alerts (not resolved)
List<Alert> getPendingAlerts() {
  return mockAlerts
      .where((alert) => alert.status != AlertStatus.resolved)
      .toList()
    ..sort((a, b) {
      // Sort by priority first (urgent > high > medium > low)
      final priorityComparison = a.priority.index.compareTo(b.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      // Then by creation date (most recent first)
      return b.createdAt.compareTo(a.createdAt);
    });
}

/// Get alerts by priority
List<Alert> getAlertsByPriority(AlertPriority priority) {
  return mockAlerts
      .where((alert) => alert.priority == priority)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Get alerts by client ID
List<Alert> getAlertsByClientId(String clientId) {
  return mockAlerts
      .where((alert) => alert.clientId == clientId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Get alerts by type
List<Alert> getAlertsByType(AlertType type) {
  return mockAlerts
      .where((alert) => alert.type == type)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Get urgent alerts (pending only)
List<Alert> getUrgentAlerts() {
  return mockAlerts
      .where((alert) =>
          alert.priority == AlertPriority.urgent &&
          alert.status != AlertStatus.resolved)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Get alert by ID
Alert? getAlertById(String id) {
  try {
    return mockAlerts.firstWhere((alert) => alert.id == id);
  } catch (e) {
    return null;
  }
}

/// Get alert count by status
Map<AlertStatus, int> getAlertCountByStatus() {
  return {
    AlertStatus.pending: mockAlerts
        .where((alert) => alert.status == AlertStatus.pending)
        .length,
    AlertStatus.inProgress: mockAlerts
        .where((alert) => alert.status == AlertStatus.inProgress)
        .length,
    AlertStatus.resolved: mockAlerts
        .where((alert) => alert.status == AlertStatus.resolved)
        .length,
  };
}

/// Get alert count by priority (excluding resolved)
Map<AlertPriority, int> getAlertCountByPriority() {
  final pending = mockAlerts.where((alert) => alert.status != AlertStatus.resolved);
  return {
    AlertPriority.urgent:
        pending.where((alert) => alert.priority == AlertPriority.urgent).length,
    AlertPriority.high:
        pending.where((alert) => alert.priority == AlertPriority.high).length,
    AlertPriority.medium:
        pending.where((alert) => alert.priority == AlertPriority.medium).length,
    AlertPriority.low:
        pending.where((alert) => alert.priority == AlertPriority.low).length,
  };
}

/// Search alerts by text (in title or description)
List<Alert> searchAlerts(String query) {
  final lowerQuery = query.toLowerCase();
  return mockAlerts
      .where((alert) =>
          alert.title.toLowerCase().contains(lowerQuery) ||
          alert.description.toLowerCase().contains(lowerQuery) ||
          (alert.clientName?.toLowerCase().contains(lowerQuery) ?? false))
      .toList()
    ..sort((a, b) {
      final priorityComparison = a.priority.index.compareTo(b.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return b.createdAt.compareTo(a.createdAt);
    });
}
