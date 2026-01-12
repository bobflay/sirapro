/// Request model for creating a new alert via POST /api/clients/{client_id}/alerts
class CreateAlertRequest {
  /// Alert type (required)
  /// One of: rupture_grave, litige_probleme, probleme_rayon, risque_perte, demande_speciale, opportunite, autre
  final String type;

  /// Custom type description (optional, required if type is 'autre')
  final String? customType;

  /// Alert comment/description (required)
  final String comment;

  /// Latitude (required, between -90 and 90)
  final double latitude;

  /// Longitude (required, between -180 and 180)
  final double longitude;

  /// Visit ID (optional, links alert to a visit)
  final int? visitId;

  /// Visit report ID (optional, links alert to a visit report)
  final int? visitReportId;

  CreateAlertRequest({
    required this.type,
    this.customType,
    required this.comment,
    required this.latitude,
    required this.longitude,
    this.visitId,
    this.visitReportId,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type,
      'comment': comment,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (customType != null && customType!.isNotEmpty) {
      json['custom_type'] = customType;
    }
    if (visitId != null) {
      json['visit_id'] = visitId;
    }
    if (visitReportId != null) {
      json['visit_report_id'] = visitReportId;
    }

    return json;
  }

  /// Validate the request before sending
  /// Returns a list of validation errors, empty if valid
  List<String> validate() {
    final errors = <String>[];

    final validTypes = [
      'rupture_grave',
      'litige_probleme',
      'probleme_rayon',
      'risque_perte',
      'demande_speciale',
      'opportunite',
      'autre',
    ];
    if (!validTypes.contains(type)) {
      errors.add('Type d\'alerte invalide');
    }

    if (type == 'autre' && (customType == null || customType!.isEmpty)) {
      errors.add('Le type personnalisé est requis pour le type "autre"');
    }

    if (comment.isEmpty) {
      errors.add('Le commentaire est requis');
    }

    if (latitude < -90 || latitude > 90) {
      errors.add('Latitude invalide (doit être entre -90 et 90)');
    }

    if (longitude < -180 || longitude > 180) {
      errors.add('Longitude invalide (doit être entre -180 et 180)');
    }

    return errors;
  }

  /// Map French type labels to API values
  static String typeToApiValue(String frenchLabel) {
    switch (frenchLabel) {
      case 'Rupture grave':
        return 'rupture_grave';
      case 'Litige / problème de paiement':
        return 'litige_probleme';
      case 'Problème important au rayon':
        return 'probleme_rayon';
      case 'Risque de perte du client':
        return 'risque_perte';
      case 'Demande spéciale du client':
        return 'demande_speciale';
      case 'Nouvelle opportunité importante':
        return 'opportunite';
      case 'Autre':
        return 'autre';
      default:
        return 'autre';
    }
  }

  /// Map API values to French type labels
  static String apiValueToType(String apiValue) {
    switch (apiValue) {
      case 'rupture_grave':
        return 'Rupture grave';
      case 'litige_probleme':
        return 'Litige / problème de paiement';
      case 'probleme_rayon':
        return 'Problème important au rayon';
      case 'risque_perte':
        return 'Risque de perte du client';
      case 'demande_speciale':
        return 'Demande spéciale du client';
      case 'opportunite':
        return 'Nouvelle opportunité importante';
      case 'autre':
        return 'Autre';
      default:
        return 'Autre';
    }
  }

  /// Get all available alert types in French
  static List<String> get alertTypesFrench => [
        'Rupture grave',
        'Litige / problème de paiement',
        'Problème important au rayon',
        'Risque de perte du client',
        'Demande spéciale du client',
        'Nouvelle opportunité importante',
        'Autre',
      ];

  @override
  String toString() {
    return 'CreateAlertRequest(type: $type, comment: $comment)';
  }
}
