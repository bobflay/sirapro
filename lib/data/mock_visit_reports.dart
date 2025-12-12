import '../models/visit_report.dart';

/// Liste de rapports de visite pour démonstration
final List<VisitReport> mockVisitReports = [
  // Reports for client-001 (Boutique Chez Adjoua)
  VisitReport(
    id: 'report-001',
    visitId: 'visit-001',
    clientId: 'client-001',
    clientName: 'Boutique Chez Adjoua',
    startTime: DateTime.now().subtract(const Duration(days: 7, hours: 2)),
    endTime: DateTime.now().subtract(const Duration(days: 7, hours: 1, minutes: 45)),
    validationLatitude: 5.3364,
    validationLongitude: -4.0742,
    validationTime: DateTime.now().subtract(const Duration(days: 7, hours: 1, minutes: 45)),
    facadePhoto: GeotaggedPhoto(
      path: '/mock/photos/facade_001.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 7, hours: 2)),
      latitude: 5.3364,
      longitude: -4.0742,
      description: 'Façade de la boutique',
    ),
    shelfPhoto: GeotaggedPhoto(
      path: '/mock/photos/shelf_001.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 7, hours: 1, minutes: 50)),
      latitude: 5.3364,
      longitude: -4.0742,
      description: 'Rayons boissons',
    ),
    additionalPhotos: [
      GeotaggedPhoto(
        path: '/mock/photos/stock_001.jpg',
        timestamp: DateTime.now().subtract(const Duration(days: 7, hours: 1, minutes: 55)),
        latitude: 5.3364,
        longitude: -4.0742,
        description: 'Stock en entrepôt',
      ),
    ],
    gerantPresent: true,
    orderPlaced: true,
    orderAmount: 57800,
    orderReference: 'order-001',
    stockShortages: 'Rupture Sprite, Fanta Orange',
    competitorActivity: 'Concurrent actif sur Coca-Cola avec -10%',
    comments: 'Bonne visite, client satisfait. Besoin de livraison rapide.',
    status: VisitReportStatus.validated,
    createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(days: 7, hours: 1, minutes: 45)),
  ),
  VisitReport(
    id: 'report-002',
    visitId: 'visit-002',
    clientId: 'client-001',
    clientName: 'Boutique Chez Adjoua',
    startTime: DateTime.now().subtract(const Duration(days: 14, hours: 3)),
    endTime: DateTime.now().subtract(const Duration(days: 14, hours: 2, minutes: 30)),
    validationLatitude: 5.3364,
    validationLongitude: -4.0742,
    validationTime: DateTime.now().subtract(const Duration(days: 14, hours: 2, minutes: 30)),
    facadePhoto: GeotaggedPhoto(
      path: '/mock/photos/facade_002.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 14, hours: 3)),
      latitude: 5.3364,
      longitude: -4.0742,
      description: 'Façade',
    ),
    shelfPhoto: GeotaggedPhoto(
      path: '/mock/photos/shelf_002.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 14, hours: 2, minutes: 40)),
      latitude: 5.3364,
      longitude: -4.0742,
      description: 'Rayons',
    ),
    additionalPhotos: [],
    gerantPresent: false,
    orderPlaced: false,
    comments: 'Gérant absent, repasserai demain',
    status: VisitReportStatus.validated,
    createdAt: DateTime.now().subtract(const Duration(days: 14, hours: 3)),
    updatedAt: DateTime.now().subtract(const Duration(days: 14, hours: 2, minutes: 30)),
  ),
  VisitReport(
    id: 'report-003',
    visitId: 'visit-003',
    clientId: 'client-001',
    clientName: 'Boutique Chez Adjoua',
    startTime: DateTime.now().subtract(const Duration(days: 21, hours: 2)),
    endTime: DateTime.now().subtract(const Duration(days: 21, hours: 1, minutes: 20)),
    validationLatitude: 5.3364,
    validationLongitude: -4.0742,
    validationTime: DateTime.now().subtract(const Duration(days: 21, hours: 1, minutes: 20)),
    facadePhoto: GeotaggedPhoto(
      path: '/mock/photos/facade_003.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 21, hours: 2)),
      latitude: 5.3364,
      longitude: -4.0742,
      description: 'Façade boutique',
    ),
    shelfPhoto: GeotaggedPhoto(
      path: '/mock/photos/shelf_003.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 21, hours: 1, minutes: 30)),
      latitude: 5.3364,
      longitude: -4.0742,
      description: 'Rayons produits',
    ),
    additionalPhotos: [
      GeotaggedPhoto(
        path: '/mock/photos/promo_003.jpg',
        timestamp: DateTime.now().subtract(const Duration(days: 21, hours: 1, minutes: 35)),
        latitude: 5.3364,
        longitude: -4.0742,
        description: 'Affichage promotionnel',
      ),
    ],
    gerantPresent: true,
    orderPlaced: true,
    orderAmount: 42500,
    orderReference: 'order-002',
    stockShortages: 'Pas de rupture',
    competitorActivity: 'RAS',
    comments: 'Client fidèle, très satisfait du service',
    status: VisitReportStatus.validated,
    createdAt: DateTime.now().subtract(const Duration(days: 21, hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(days: 21, hours: 1, minutes: 20)),
  ),

  // Reports for client-002 (Supermarché Belle Vue)
  VisitReport(
    id: 'report-004',
    visitId: 'visit-004',
    clientId: 'client-002',
    clientName: 'Supermarché Belle Vue',
    startTime: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
    endTime: DateTime.now().subtract(const Duration(days: 3, hours: 3, minutes: 10)),
    validationLatitude: 5.3400,
    validationLongitude: -4.0300,
    validationTime: DateTime.now().subtract(const Duration(days: 3, hours: 3, minutes: 10)),
    facadePhoto: GeotaggedPhoto(
      path: '/mock/photos/facade_004.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
      latitude: 5.3400,
      longitude: -4.0300,
      description: 'Façade supermarché',
    ),
    shelfPhoto: GeotaggedPhoto(
      path: '/mock/photos/shelf_004.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 3, minutes: 20)),
      latitude: 5.3400,
      longitude: -4.0300,
      description: 'Rayon boissons',
    ),
    additionalPhotos: [],
    gerantPresent: true,
    orderPlaced: true,
    orderAmount: 125000,
    orderReference: 'order-003',
    stockShortages: 'Rupture Eau Cristal',
    competitorActivity: 'Nouvelle marque de jus installée',
    comments: 'Grosse commande, demande livraison sous 48h',
    status: VisitReportStatus.validated,
    createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
    updatedAt: DateTime.now().subtract(const Duration(days: 3, hours: 3, minutes: 10)),
  ),

  // Reports for client-003 (Boutique Al Baraka)
  VisitReport(
    id: 'report-005',
    visitId: 'visit-005',
    clientId: 'client-003',
    clientName: 'Boutique Al Baraka',
    startTime: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
    endTime: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 25)),
    validationLatitude: 5.3515,
    validationLongitude: -4.0228,
    validationTime: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 25)),
    facadePhoto: GeotaggedPhoto(
      path: '/mock/photos/facade_005.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      latitude: 5.3515,
      longitude: -4.0228,
      description: 'Façade',
    ),
    shelfPhoto: GeotaggedPhoto(
      path: '/mock/photos/shelf_005.jpg',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 30)),
      latitude: 5.3515,
      longitude: -4.0228,
      description: 'Rayons',
    ),
    additionalPhotos: [
      GeotaggedPhoto(
        path: '/mock/photos/issue_005.jpg',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 35)),
        latitude: 5.3515,
        longitude: -4.0228,
        description: 'Produits périmés à retirer',
      ),
    ],
    gerantPresent: true,
    orderPlaced: true,
    orderAmount: 78000,
    stockShortages: 'Rupture Huile DINOR',
    competitorActivity: 'Concurrent absent',
    comments: 'Quelques produits proches de la date de péremption signalés',
    status: VisitReportStatus.validated,
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 25)),
  ),
];

/// Récupère tous les rapports de visite
List<VisitReport> getAllVisitReports() {
  return List.from(mockVisitReports);
}

/// Récupère les rapports de visite d'un client spécifique
List<VisitReport> getVisitReportsByClient(String clientId) {
  return mockVisitReports
      .where((report) => report.clientId == clientId)
      .toList()
    ..sort((a, b) => b.startTime.compareTo(a.startTime)); // Plus récents en premier
}

/// Récupère un rapport de visite par son ID
VisitReport? getVisitReportById(String reportId) {
  try {
    return mockVisitReports.firstWhere((report) => report.id == reportId);
  } catch (e) {
    return null;
  }
}

/// Récupère les rapports de visite par statut
List<VisitReport> getVisitReportsByStatus(VisitReportStatus status) {
  return mockVisitReports.where((report) => report.status == status).toList();
}

/// Compte le nombre de rapports par client
Map<String, int> getVisitReportsCountByClient() {
  final Map<String, int> counts = {};
  for (var report in mockVisitReports) {
    counts[report.clientId] = (counts[report.clientId] ?? 0) + 1;
  }
  return counts;
}
