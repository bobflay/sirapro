import 'package:flutter/material.dart';
import 'package:sirapro/screens/create_client_page.dart';
import 'package:sirapro/screens/client_detail_page.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/data/mock_clients.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late List<Client> _clients;
  late List<Client> _filteredClients;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'Tous';
  String _selectedTypeFilter = 'Tous';
  String _selectedPotentielFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _clients = MockClients.getClients();
    _filteredClients = _clients;
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterClients() {
    setState(() {
      _filteredClients = _clients.where((client) {
        // Search filter
        final searchLower = _searchController.text.toLowerCase();
        final matchesSearch = searchLower.isEmpty ||
            client.boutiqueName.toLowerCase().contains(searchLower) ||
            client.gerantName.toLowerCase().contains(searchLower) ||
            client.phone.toLowerCase().contains(searchLower) ||
            client.quartier.toLowerCase().contains(searchLower) ||
            client.ville.toLowerCase().contains(searchLower);

        // Status filter
        final matchesStatus = _selectedStatusFilter == 'Tous' ||
            (_selectedStatusFilter == 'Actif' && client.isActive) ||
            (_selectedStatusFilter == 'En attente' && !client.isActive);

        // Type filter
        final matchesType = _selectedTypeFilter == 'Tous' ||
            client.type == _selectedTypeFilter;

        // Potentiel filter
        final matchesPotentiel = _selectedPotentielFilter == 'Tous' ||
            client.potentiel == _selectedPotentielFilter;

        return matchesSearch && matchesStatus && matchesType && matchesPotentiel;
      }).toList();
    });
  }

  int get _activeCount => _clients.where((c) => c.isActive).length;
  int get _pendingCount => _clients.where((c) => !c.isActive).length;

  Future<void> _navigateToCreateClient() async {
    final newClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateClientPage(),
      ),
    );

    if (newClient != null && mounted) {
      setState(() {
        _clients.insert(0, newClient);
        _filterClients();
      });
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
      setState(() {
        _clients[index] = updatedClient;
      });
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
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
                          '$_activeCount',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Clients actifs',
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
                          '$_pendingCount',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'En attente',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un client...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('Tous (${_filteredClients.length})'),
                      selected: _selectedStatusFilter == 'Tous' &&
                          _selectedTypeFilter == 'Tous' &&
                          _selectedPotentielFilter == 'Tous',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = 'Tous';
                          _selectedTypeFilter = 'Tous';
                          _selectedPotentielFilter = 'Tous';
                          _filterClients();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Actif'),
                      selected: _selectedStatusFilter == 'Actif',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = selected ? 'Actif' : 'Tous';
                          _filterClients();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('En attente'),
                      selected: _selectedStatusFilter == 'En attente',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = selected ? 'En attente' : 'Tous';
                          _filterClients();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      child: Chip(
                        label: Text(_selectedTypeFilter == 'Tous' ? 'Type' : _selectedTypeFilter),
                        avatar: const Icon(Icons.arrow_drop_down, size: 18),
                      ),
                      onSelected: (value) {
                        setState(() {
                          _selectedTypeFilter = value;
                          _filterClients();
                        });
                      },
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
                        label: Text(_selectedPotentielFilter == 'Tous' ? 'Potentiel' : 'Pot. ${_selectedPotentielFilter}'),
                        avatar: const Icon(Icons.arrow_drop_down, size: 18),
                      ),
                      onSelected: (value) {
                        setState(() {
                          _selectedPotentielFilter = value;
                          _filterClients();
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'Tous', child: Text('Tous')),
                        const PopupMenuItem(value: 'A', child: Text('A')),
                        const PopupMenuItem(value: 'B', child: Text('B')),
                        const PopupMenuItem(value: 'C', child: Text('C')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Clients List Header
              Row(
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
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredClients.isEmpty
                    ? Center(
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
                      )
                    : ListView.builder(
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          final originalIndex = _clients.indexOf(client);
                          return _buildClientCard(context, client, originalIndex);
                        },
                      ),
              ),
            ],
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForType(client.type),
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                ),
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
                              '${client.quartier}, ${client.ville}',
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: client.isActive
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              client.status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: client.isActive ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                          if (client.frequenceVisite != null) ...[
                            const SizedBox(width: 8),
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
