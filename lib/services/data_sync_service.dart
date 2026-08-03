import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'client_service.dart';
import 'home_service.dart';
import 'offline_queue_service.dart';
import 'product_service.dart';
import 'routing_api_service.dart';
import 'wallet_service.dart';

/// Synchronisation complète de l'app :
///
/// 1. **Envoi d'abord** — les saisies locales en attente (visites, commandes,
///    clients, rapports) sont rejouées vers le serveur ;
/// 2. **Téléchargement ensuite** — les données nécessaires au travail hors
///    ligne (clients, catalogue produits, tournée, tableau de bord…) sont
///    rapatriées et mises en cache.
///
/// L'ordre envoi → téléchargement est essentiel : les données téléchargées
/// incluent ainsi les saisies locales fraîchement envoyées et ne peuvent pas
/// les écraser.
class DataSyncService {
  static DataSyncService? _instance;

  factory DataSyncService() {
    _instance ??= DataSyncService._internal();
    return _instance!;
  }

  DataSyncService._internal();

  /// Avancement global (0..1) — à brancher sur une barre de progression.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// Étape en cours, lisible par l'utilisateur.
  final ValueNotifier<String> currentStep = ValueNotifier<String>('');

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  /// Limite par étape : une étape qui traîne ne doit pas bloquer l'écran
  /// de chargement indéfiniment.
  static const Duration _stepTimeout = Duration(seconds: 25);

  /// Garde-fou de pagination.
  static const int _maxPages = 50;

  /// Lance la synchronisation complète. Retourne false si au moins une
  /// étape a échoué (les autres continuent malgré tout).
  Future<bool> fullSync() async {
    if (isSyncing.value) return false;
    isSyncing.value = true;
    progress.value = 0;
    var allOk = true;

    try {
      // 1. Envoi des saisies locales — TOUJOURS avant le téléchargement.
      currentStep.value = 'Envoi des saisies en attente…';
      try {
        await OfflineQueueService().flush().timeout(_stepTimeout * 2);
      } catch (e) {
        debugPrint('[DataSync] flush failed: $e');
        allOk = false;
      }
      progress.value = 0.15;

      // 2. Téléchargement des données de travail.
      final steps = <String, Future<void> Function()>{
        'Profil utilisateur': () async {
          await AuthService().refreshUserData();
        },
        'Clients': _pullAllClients,
        'Catalogue produits': _pullAllProducts,
        'Catégories': () async {
          await ProductService().listCategories(topLevel: true);
        },
        'Tournée du jour': () async {
          await RoutingApiService().getTodayRouting();
        },
        'Tableau de bord': () async {
          await HomeService().getHomeData();
        },
        'Portefeuille': () async {
          await WalletService().getWallet();
        },
      };

      var done = 0;
      for (final entry in steps.entries) {
        currentStep.value = 'Téléchargement : ${entry.key}…';
        try {
          await entry.value().timeout(_stepTimeout);
        } catch (e) {
          debugPrint('[DataSync] "${entry.key}" failed: $e');
          allOk = false;
        }
        done++;
        progress.value = 0.15 + 0.85 * (done / steps.length);
      }

      currentStep.value = allOk
          ? 'Synchronisation terminée'
          : 'Terminé — certaines données n\'ont pas pu être téléchargées';
      progress.value = 1;
      return allOk;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Toutes les pages de clients (mêmes paramètres que l'écran Clients,
  /// pour que les clés de cache correspondent).
  Future<void> _pullAllClients() async {
    final service = ClientService();
    var page = 1;
    var hasMore = true;
    while (hasMore && page <= _maxPages) {
      final response = await service.getClients(page: page);
      hasMore = response.hasMore;
      page++;
    }
  }

  /// Tout le catalogue produits (mêmes paramètres que l'écran Commande).
  Future<void> _pullAllProducts() async {
    final service = ProductService();
    var page = 1;
    var hasMore = true;
    while (hasMore && page <= _maxPages) {
      final response = await service.listProducts(page: page);
      hasMore = response.hasMorePages;
      page++;
    }
  }
}
