import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sirapro/screens/create_client_page.dart';
import 'package:sirapro/screens/client_detail_page.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/services/client_service.dart';
import 'package:sirapro/services/api_service.dart';

const String _baseUrl = 'https://sira.xpertbot.online';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedTypeFilter = 'Tous';
  String _selectedPotentielFilter = 'Tous';

  // Loading and error states
  bool _isInitialLoading = true;
  bool _isSearching = false;
  String? _errorMessage;

  // Pagination
  final ClientService _clientService = ClientService();
  int _currentPage = 1;
  bool _hasMorePages = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  int _totalClients = 0;

  // Debounce timer for search
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadClients(isInitial: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search to avoid too many API calls
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _loadClients();
    });
    // Update UI to show clear button
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreClients();
    }
  }

  String? get _currentSearch {
    final text = _searchController.text.trim();
    return text.isEmpty ? null : text;
  }

  String? get _currentType {
    return _selectedTypeFilter == 'Tous' ? null : _selectedTypeFilter;
  }

  void _applyLocalFilters() {
    setState(() {
      if (_selectedPotentielFilter == 'Tous') {
        _filteredClients = List.from(_clients);
      } else {
        _filteredClients = _clients
            .where((client) => client.potentiel == _selectedPotentielFilter)
            .toList();
      }
    });
  }

  Future<void> _loadClients({bool isInitial = false}) async {
    setState(() {
      if (isInitial) {
        _isInitialLoading = true;
      } else {
        _isSearching = true;
      }
      _errorMessage = null;
    });

    try {
      final response = await _clientService.getClients(
        page: 1,
        search: _currentSearch,
        type: _currentType,
      );
      if (mounted) {
        setState(() {
          _clients = response.clients;
          _currentPage = 1;
          _hasMorePages = response.hasMore;
          _totalClients = response.meta.total;
          _isInitialLoading = false;
          _isSearching = false;
        });
        _applyLocalFilters();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isInitialLoading = false;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue lors du chargement des clients';
          _isInitialLoading = false;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadMoreClients() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _clientService.getClients(
        page: _currentPage + 1,
        search: _currentSearch,
        type: _currentType,
      );
      if (mounted) {
        setState(() {
          _clients.addAll(response.clients);
          _currentPage++;
          _hasMorePages = response.hasMore;
          _isLoadingMore = false;
        });
        _applyLocalFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshClients() async {
    setState(() {
      _currentPage = 1;
      _hasMorePages = true;
    });
    await _loadClients();
  }

  void _onTypeFilterChanged(String value) {
    setState(() {
      _selectedTypeFilter = value;
    });
    _loadClients();
  }

  void _onPotentielFilterChanged(String value) {
    setState(() {
      _selectedPotentielFilter = value;
    });
    _applyLocalFilters();
  }

  void _clearFilters() {
    setState(() {
      _selectedTypeFilter = 'Tous';
      _selectedPotentielFilter = 'Tous';
      _searchController.clear();
    });
    _searchDebounce?.cancel();
    _loadClients();
  }

  bool get _hasActiveFilters =>
      _selectedTypeFilter != 'Tous' ||
      _selectedPotentielFilter != 'Tous' ||
      _searchController.text.isNotEmpty;

  Future<void> _navigateToCreateClient() async {
    final newClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateClientPage(),
      ),
    );

    if (newClient != null && mounted) {
      // Refresh the list to include the new client
      _refreshClients();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client "${newClient.boutiqueName}" ajouté avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _navigateToClientDetail(Client client, int index) async {
    final updatedClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailPage(client: client),
      ),
    );

    if (updatedClient != null && mounted) {
      final clientIndex = _clients.indexWhere((c) => c.id == updatedClient.id);
      if (clientIndex != -1) {
        setState(() {
          _clients[clientIndex] = updatedClient;
        });
        _applyLocalFilters();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Clients'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshClients,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _clients.isEmpty
                ? _buildErrorWidget()
                : RefreshIndicator(
                    onRefresh: _refreshClients,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Card
                          _buildSummaryCard(),
                          const SizedBox(height: 24),

                          // Search Bar
                          _buildSearchBar(),
                          const SizedBox(height: 16),

                          // Filter Chips
                          _buildFilterChips(),
                          const SizedBox(height: 16),

                          // Clients List Header
                          _buildListHeader(),
                          const SizedBox(height: 12),

                          // Clients List
                          Expanded(
                            child: _buildClientsList(),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateClient,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau Client'),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadClients(isInitial: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$_totalClients',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total clients',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Container(
            height: 60,
            width: 1,
            color: Colors.grey[300],
          ),
          Column(
            children: [
              Text(
                '${_filteredClients.length}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Affichés',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher par nom, gérant, téléphone...',
        prefixIcon: _isSearching
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _searchDebounce?.cancel();
                  _loadClients();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: const Text('Effacer filtres'),
                avatar: const Icon(Icons.clear, size: 18),
                onPressed: _clearFilters,
              ),
            ),
          PopupMenuButton<String>(
            child: Chip(
              label: Text(_selectedTypeFilter == 'Tous' ? 'Type' : _selectedTypeFilter),
              avatar: const Icon(Icons.arrow_drop_down, size: 18),
              backgroundColor: _selectedTypeFilter != 'Tous'
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                  : null,
            ),
            onSelected: _onTypeFilterChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Tous', child: Text('Tous')),
              const PopupMenuItem(value: 'Boutique', child: Text('Boutique')),
              const PopupMenuItem(value: 'Supermarché', child: Text('Supermarché')),
              const PopupMenuItem(value: 'Demi-grossiste', child: Text('Demi-grossiste')),
              const PopupMenuItem(value: 'Grossiste', child: Text('Grossiste')),
              const PopupMenuItem(value: 'Distributeur', child: Text('Distributeur')),
            ],
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            child: Chip(
              label: Text(_selectedPotentielFilter == 'Tous' ? 'Potentiel' : 'Pot. $_selectedPotentielFilter'),
              avatar: const Icon(Icons.arrow_drop_down, size: 18),
              backgroundColor: _selectedPotentielFilter != 'Tous'
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                  : null,
            ),
            onSelected: _onPotentielFilterChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Tous', child: Text('Tous')),
              const PopupMenuItem(value: 'A', child: Text('A - Haut potentiel')),
              const PopupMenuItem(value: 'B', child: Text('B - Potentiel moyen')),
              const PopupMenuItem(value: 'C', child: Text('C - Faible potentiel')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Liste des Clients',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          '${_filteredClients.length} résultat(s)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildClientsList() {
    if (_isSearching && _clients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun client trouvé',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez de modifier vos filtres',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          itemCount: _filteredClients.length + (_isLoadingMore ? 1 : 0) + (_hasMorePages && !_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _filteredClients.length && _isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (index == _filteredClients.length && _hasMorePages && !_isLoadingMore) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: TextButton(
                    onPressed: _loadMoreClients,
                    child: const Text('Charger plus...'),
                  ),
                ),
              );
            }
            if (index >= _filteredClients.length) return const SizedBox.shrink();

            final client = _filteredClients[index];
            return _buildClientCard(context, client, index);
          },
        ),
        // Subtle loading overlay when searching (doesn't block interaction)
        if (_isSearching && _clients.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Theme.of(context).primaryColor,
            ),
          ),
      ],
    );
  }

  Widget _buildClientAvatar(BuildContext context, Client client) {
    const double avatarSize = 72.0;

    // If client has photos, display the first photo
    if (client.photos.isNotEmpty) {
      final firstPhoto = client.photos.first;
      final photoUrl = firstPhoto.url.startsWith('http')
          ? firstPhoto.url
          : '$_baseUrl${firstPhoto.url}';

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: Image.network(
            photoUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon on error
              return Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconForType(client.type),
                  color: Theme.of(context).primaryColor,
                  size: 36,
                ),
              );
            },
          ),
        ),
      );
    }

    // Default: show icon based on client type
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getIconForType(client.type),
        color: Theme.of(context).primaryColor,
        size: 36,
      ),
    );
  }

  Widget _buildClientCard(BuildContext context, Client client, int index) {
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
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToClientDetail(client, index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildClientAvatar(context, client),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.boutiqueName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (client.potentiel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getPotentielColor(client.potentiel!).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                client.potentiel!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getPotentielColor(client.potentiel!),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        client.type,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              client.gerantName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              client.fullAddress,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            client.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (client.hasOpenAlert)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning, size: 12, color: Colors.red),
                                  SizedBox(width: 4),
                                  Text(
                                    'Alerte',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (client.frequenceVisite != null) ...[
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              client.frequenceVisite!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                          if (client.lastVisitDate != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatLastVisit(client.lastVisitDate!),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastVisit(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return "Aujourd'hui";
    } else if (difference == 1) {
      return 'Hier';
    } else if (difference < 7) {
      return 'Il y a $difference jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Supermarché':
        return Icons.store;
      case 'Grossiste':
        return Icons.warehouse;
      case 'Demi-grossiste':
        return Icons.inventory_2;
      case 'Distributeur':
        return Icons.local_shipping;
      default:
        return Icons.shopping_bag;
    }
  }

  Color _getPotentielColor(String potentiel) {
    switch (potentiel) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.orange;
      case 'C':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
