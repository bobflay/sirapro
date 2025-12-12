# Implémentation du Rapport de Visite - Documentation

## Vue d'ensemble

Ce document décrit l'implémentation complète du système de rapport de visite obligatoire pour l'application SiraPro. Le système garantit qu'aucune visite ne peut être marquée comme "Terminée" sans avoir rempli un rapport complet avec photos géolocalisées.

## Fonctionnalités Implémentées

### 1. Modèles de Données

#### VisitReport ([lib/models/visit_report.dart](lib/models/visit_report.dart))

Représente un rapport de visite complet avec tous les champs obligatoires :

**Photos géolocalisées (GeotaggedPhoto):**
- Chemin du fichier photo
- Timestamp (horodatage automatique)
- Coordonnées GPS (latitude/longitude)
- Description optionnelle

**Champs obligatoires du rapport:**
- ✓ Client/boutique (pré-rempli via le routing)
- ✓ Date et heure de début/fin (automatique)
- ✓ Position GPS au moment de la validation
- ✓ Photo façade (obligatoire, géolocalisée)
- ✓ Photo rayons/linéaires (obligatoire, géolocalisée)
- ✓ Photos supplémentaires (optionnelles)
- ✓ Présence du gérant (Oui/Non)
- ✓ Commande réalisée (Oui/Non)
  - Si Oui : montant approximatif
  - Référence commande (optionnel)

**Champs optionnels:**
- Ruptures observées (texte libre)
- Activité concurrente (texte libre)
- Commentaires libres du commercial

**Validation:**
- Méthode `isValid` vérifie tous les champs obligatoires
- Méthode `hasRequiredPhotos` vérifie la présence des 2 photos obligatoires
- Calcul automatique de la durée de visite

#### Visit ([lib/models/visit.dart](lib/models/visit.dart))

Représente une visite dans le cadre d'un routing :

**Statuts disponibles:**
- `planned` - Planifié
- `inProgress` - En cours
- `completed` - Terminée (avec rapport validé)
- `incomplete` - Incomplète (rapport non validé)
- `skipped` - Sautée
- `cancelled` - Annulée

**Champs clés:**
- Ordre de visite dans le routing (1, 2, 3, 4...)
- Position GPS du client
- Horaires planifiés et réels
- Rapport de visite (lien avec VisitReport)
- Méthode `canComplete` : vérifie si le rapport est valide avant de terminer

#### Route/Tournée ([lib/models/route.dart](lib/models/route.dart))

Représente une tournée de visites commerciales :

**Statuts:**
- `planned` - Planifiée
- `inProgress` - En cours
- `completed` - Terminée
- `paused` - En pause
- `cancelled` - Annulée

**Métriques automatiques:**
- Nombre total de visites
- Visites complétées/en cours/planifiées/incomplètes
- Pourcentage de progression (0-100%)
- Durée totale et temps passé en visite
- Prochaine visite à effectuer

### 2. Service de Capture Photo

#### PhotoCaptureService ([lib/services/photo_capture_service.dart](lib/services/photo_capture_service.dart))

Service complet pour la capture de photos géolocalisées :

**Fonctionnalités:**
- ✓ Vérification et demande des permissions (caméra + localisation)
- ✓ Capture photo avec la caméra
- ✓ Sélection photo depuis la galerie
- ✓ Géolocalisation automatique au moment de la capture
- ✓ Horodatage automatique
- ✓ Compression et redimensionnement des images (1920x1080, qualité 85%)
- ✓ Stockage sécurisé dans le dossier de l'application
- ✓ Nettoyage automatique des anciennes photos (configurable)

**Méthodes principales:**
```dart
// Capture photo avec caméra
Future<GeotaggedPhoto?> takePhoto({String? description})

// Sélection depuis galerie
Future<GeotaggedPhoto?> pickFromGallery({String? description})

// Obtenir position GPS actuelle
Future<Position?> getCurrentPosition()

// Vérifier/demander permissions
Future<bool> checkAndRequestPermissions()
```

### 3. Interface Utilisateur

#### VisitReportPage ([lib/screens/visit_report_page.dart](lib/screens/visit_report_page.dart))

Formulaire complet de rapport de visite avec validation :

**Sections du formulaire:**

1. **Informations Client** (lecture seule)
   - Nom de la boutique
   - Adresse
   - Heure de début de visite

2. **Photos Obligatoires**
   - Photo Façade (obligatoire)
   - Photo Rayons/Linéaires (obligatoire)
   - Affichage miniature avec GPS et timestamp
   - Possibilité de supprimer et reprendre

3. **Photos Supplémentaires** (optionnel)
   - Ajout illimité de photos
   - Stock, anomalies, etc.

4. **Compte Rendu**
   - Présence du gérant (Oui/Non) *
   - Commande réalisée (Oui/Non) *
   - Montant commande (si Oui) *
   - Référence commande (optionnel)
   - Ruptures observées (optionnel)
   - Activité concurrente (optionnel)
   - Commentaires libres (optionnel)

**Validation automatique:**
- ❌ Impossible de valider sans photo façade
- ❌ Impossible de valider sans photo rayons
- ❌ Impossible de valider sans indiquer présence gérant
- ❌ Impossible de valider sans indiquer si commande réalisée
- ❌ Si commande = Oui, montant obligatoire
- ✅ Capture GPS automatique au moment de la validation

#### TourneeDetailPageNew ([lib/screens/tournee_detail_page_new.dart](lib/screens/tournee_detail_page_new.dart))

Page de gestion de tournée avec intégration complète :

**Fonctionnalités:**
- Affichage de la progression (X/Y visites, pourcentage)
- Liste ordonnée des visites avec statut visuel
- Démarrage automatique de visite
- Ouverture du formulaire de rapport
- **Validation : impossible de marquer "Terminée" sans rapport complet**
- Affichage du résumé du rapport une fois validé
- Badge d'avertissement si rapport incomplet
- Indication de la durée de chaque visite

**Actions disponibles:**
- Démarrer la visite (si planifiée)
- Remplir le rapport (si en cours ou planifiée)
- Voir le rapport (si rapport existant)

### 4. Permissions Système

#### iOS ([ios/Runner/Info.plist](ios/Runner/Info.plist))

Permissions configurées avec descriptions en français :

```xml
<!-- Localisation -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Cette application nécessite l'accès à votre position pour afficher votre localisation sur la carte et enregistrer la position GPS des clients.</string>

<!-- Caméra -->
<key>NSCameraUsageDescription</key>
<string>Cette application nécessite l'accès à la caméra pour prendre des photos lors des visites clients (façade, rayons, etc.).</string>

<!-- Photos -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Cette application nécessite l'accès à vos photos pour sélectionner des images à joindre aux rapports de visite.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Cette application souhaite sauvegarder des photos dans votre galerie.</string>
```

#### Android ([android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml))

Permissions configurées :

```xml
<!-- Localisation -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Caméra -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Photos -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                 android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

<!-- Features (optionnel) -->
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

### 5. Dépendances Ajoutées

Packages Flutter installés ([pubspec.yaml](pubspec.yaml)):

```yaml
dependencies:
  image_picker: ^1.0.7          # Capture photo caméra/galerie
  geolocator: ^11.0.0           # Géolocalisation GPS
  permission_handler: ^11.2.0   # Gestion des permissions
  path_provider: ^2.1.2         # Stockage fichiers
  path: ^1.9.0                  # Manipulation chemins fichiers
```

## Flux de Travail

### Scénario Nominal

1. **Commercial ouvre la tournée du jour**
   - Voit la liste des visites planifiées
   - Progression affichée (0/4 visites)

2. **Démarre une visite**
   - Tape sur une visite → Menu d'actions
   - Sélectionne "Démarrer la visite"
   - Statut passe à "En cours"
   - Heure de début enregistrée automatiquement

3. **Remplit le rapport de visite**
   - Tape sur "Remplir le rapport"
   - Formulaire s'ouvre avec infos client pré-remplies

4. **Prend les photos obligatoires**
   - Tape "Prendre une photo" pour façade
   - Caméra s'ouvre, prend la photo
   - GPS et timestamp enregistrés automatiquement
   - Répète pour photo rayons
   - (Optionnel) Ajoute des photos supplémentaires

5. **Remplit le compte rendu**
   - Sélectionne présence gérant (Oui/Non)
   - Indique si commande réalisée (Oui/Non)
   - Si Oui : saisit montant
   - Ajoute observations (ruptures, concurrence, commentaires)

6. **Valide le rapport**
   - Tape "Valider la visite"
   - Système vérifie tous les champs obligatoires
   - Capture GPS de validation
   - Heure de fin enregistrée
   - Statut visite passe à "Terminée"
   - Retour à la liste des visites
   - Progression mise à jour (1/4 visites)

### Gestion des Erreurs

**Photo sans GPS:**
- Photos acceptées même si GPS indisponible
- Avertissement dans les logs
- Latitude/Longitude = null

**Permissions refusées:**
- Message d'erreur clair à l'utilisateur
- Impossible de prendre des photos
- Suggestion d'aller dans les paramètres

**Rapport incomplet:**
- ❌ Bouton "Valider" affiche message d'erreur
- Message indique quel champ est manquant
- Visite reste en statut "En cours"
- Badge "Rapport incomplet" affiché dans la liste

**Pas de connexion réseau:**
- Photos stockées localement
- Synchronisation ultérieure (à implémenter)

## Architecture des Données

### Structure de Stockage

```
Application Documents/
└── photos/
    ├── photo_2024-12-12T10-30-45.jpg
    ├── photo_2024-12-12T10-31-12.jpg
    └── ...
```

### Format JSON des Modèles

**VisitReport:**
```json
{
  "id": "report-1",
  "visitId": "visit-1",
  "clientId": "client-1",
  "clientName": "Supermarché Central",
  "startTime": "2024-12-12T08:30:00Z",
  "endTime": "2024-12-12T09:15:00Z",
  "validationLatitude": 5.3600,
  "validationLongitude": -4.0083,
  "validationTime": "2024-12-12T09:15:00Z",
  "facadePhoto": {
    "path": "/path/to/photo.jpg",
    "timestamp": "2024-12-12T08:35:00Z",
    "latitude": 5.3600,
    "longitude": -4.0083
  },
  "shelfPhoto": { ... },
  "additionalPhotos": [ ... ],
  "gerantPresent": true,
  "orderPlaced": true,
  "orderAmount": 150000,
  "orderReference": "CMD-2024-001",
  "stockShortages": "Produit A, Produit B",
  "competitorActivity": "Nouveau concurrent à proximité",
  "comments": "Client satisfait",
  "status": "validated",
  "createdAt": "2024-12-12T08:30:00Z",
  "updatedAt": "2024-12-12T09:15:00Z"
}
```

## Tests et Validation

### Tests Manuels Recommandés

1. **Test des permissions**
   - ✓ Première ouverture : demande permissions
   - ✓ Refus permissions : message d'erreur approprié
   - ✓ Acceptation permissions : fonctionnement normal

2. **Test photos**
   - ✓ Capture avec caméra
   - ✓ Sélection depuis galerie
   - ✓ GPS enregistré correctement
   - ✓ Timestamp correct
   - ✓ Suppression de photo
   - ✓ Photos multiples

3. **Test validation**
   - ✓ Validation impossible sans photo façade
   - ✓ Validation impossible sans photo rayons
   - ✓ Validation impossible sans gérant présent
   - ✓ Validation impossible sans commande réalisée
   - ✓ Si commande Oui : montant obligatoire
   - ✓ Validation réussie : visite terminée

4. **Test intégration tournée**
   - ✓ Démarrage visite : statut "En cours"
   - ✓ Rapport validé : statut "Terminée"
   - ✓ Progression mise à jour
   - ✓ Durée calculée correctement

### Points d'Attention

⚠️ **Stockage local uniquement**
- Les photos et rapports sont stockés localement
- Nécessite implémentation de synchronisation serveur

⚠️ **Taille des photos**
- Compression à 85% de qualité
- Redimensionnement à 1920x1080 max
- Surveiller l'espace disque

⚠️ **Batterie**
- GPS consomme de la batterie
- Position capturée uniquement lors des photos et validation

## Prochaines Étapes Suggérées

### 1. Synchronisation Backend
- Upload des photos vers serveur
- Sauvegarde des rapports en base de données
- Gestion mode offline/online

### 2. Optimisations
- Cache des photos pour affichage rapide
- Compression progressive selon qualité réseau
- Retry automatique en cas d'échec upload

### 3. Fonctionnalités Additionnelles
- Signature électronique du gérant
- Scan code-barres produits
- Historique des visites précédentes
- Statistiques et rapports
- Export PDF du rapport

### 4. Améliorations UX
- Prévisualisation photo avant validation
- Mode appareil photo intégré (sans quitter l'app)
- Détection automatique si déjà sur place (geofencing)
- Notifications de rappel pour rapports incomplets

## Support et Maintenance

### Fichiers Clés

| Fichier | Rôle |
|---------|------|
| [lib/models/visit_report.dart](lib/models/visit_report.dart) | Modèle rapport de visite |
| [lib/models/visit.dart](lib/models/visit.dart) | Modèle visite |
| [lib/models/route.dart](lib/models/route.dart) | Modèle tournée |
| [lib/services/photo_capture_service.dart](lib/services/photo_capture_service.dart) | Service capture photo GPS |
| [lib/screens/visit_report_page.dart](lib/screens/visit_report_page.dart) | UI formulaire rapport |
| [lib/screens/tournee_detail_page_new.dart](lib/screens/tournee_detail_page_new.dart) | UI gestion tournée |

### Logs et Debugging

Les services utilisent `print()` pour les erreurs. Pour production, remplacer par un système de logging approprié (ex: `logger` package).

### Compatibilité

- ✅ iOS 14.0+
- ✅ Android API 21+ (Android 5.0+)
- ✅ Flutter 3.5.0+

---

**Date de création:** 12 décembre 2024
**Version:** 1.0.0
**Auteur:** Implémentation par Claude Code
