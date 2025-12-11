import 'package:flutter/material.dart';
import 'package:sirapro/screens/create_client_page.dart';
import 'package:sirapro/screens/client_detail_page.dart';
import 'package:sirapro/models/client.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late List<Client> _clients;

  @override
  void initState() {
    super.initState();
    _clients = _getInitialClients();
  }

  List<Client> _getInitialClients() {
    return [
      Client(
        id: '1',
        boutiqueName: 'Supermarché Bonheur',
        type: 'Supermarché',
        gerantName: 'Kouassi Yao Jean',
        phone: '+225 07 12 34 56 78',
        address: 'Rue du Commerce',
        quartier: 'Cocody Riviera',
        ville: 'Abidjan',
        zone: 'Abidjan - Cocody',
        potentiel: 'A',
        frequenceVisite: 'Hebdomadaire',
        status: 'Actif',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      Client(
        id: '2',
        boutiqueName: 'Alimentation Chez Adjoua',
        type: 'Boutique',
        gerantName: 'Adjoua Kouamé Marie',
        phone: '+225 05 98 76 54 32',
        whatsapp: '+225 05 98 76 54 32',
        address: 'Boulevard de la Paix',
        quartier: 'Yopougon Siporex',
        ville: 'Abidjan',
        zone: 'Abidjan - Yopougon',
        potentiel: 'B',
        frequenceVisite: 'Bimensuelle',
        status: 'Actif',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      Client(
        id: '3',
        boutiqueName: 'Demi-Gros Akissi',
        type: 'Demi-grossiste',
        gerantName: 'Akissi N\'Guessan Awa',
        phone: '+225 07 11 22 33 44',
        email: 'akissi.nguessan@email.ci',
        address: 'Avenue Houphouët-Boigny',
        quartier: 'Plateau',
        ville: 'Abidjan',
        zone: 'Abidjan - Plateau',
        potentiel: 'A',
        frequenceVisite: 'Hebdomadaire',
        status: 'Actif',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
      ),
      Client(
        id: '4',
        boutiqueName: 'Épicerie du Marché',
        type: 'Boutique',
        gerantName: 'Koné Mamadou Ibrahim',
        phone: '+225 01 55 66 77 88',
        address: 'Près du Grand Marché',
        quartier: 'Adjamé',
        ville: 'Abidjan',
        zone: 'Abidjan - Adjamé',
        potentiel: 'B',
        frequenceVisite: 'Bimensuelle',
        status: 'Actif',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      Client(
        id: '5',
        boutiqueName: 'Mini Market Traoré',
        type: 'Boutique',
        gerantName: 'Traoré Sékou Oumar',
        phone: '+225 07 44 33 22 11',
        address: 'Rue des Jardins',
        quartier: 'Marcory Zone 4',
        ville: 'Abidjan',
        zone: 'Abidjan - Marcory',
        potentiel: 'C',
        frequenceVisite: 'Mensuelle',
        status: 'Actif',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
      Client(
        id: '6',
        boutiqueName: 'Cash & Carry Diallo',
        type: 'Grossiste',
        gerantName: 'Diallo Fatoumata Binta',
        phone: '+225 05 77 88 99 00',
        whatsapp: '+225 05 77 88 99 00',
        email: 'cashcarry.diallo@gmail.com',
        address: 'Zone Industrielle',
        quartier: 'Treichville',
        ville: 'Abidjan',
        zone: 'Abidjan - Treichville',
        potentiel: 'A',
        frequenceVisite: 'Hebdomadaire',
        status: 'Actif',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 180)),
      ),
      Client(
        id: '7',
        boutiqueName: 'Boutique Bamba',
        type: 'Boutique',
        gerantName: 'Bamba Lacina',
        phone: '+225 01 00 11 22 33',
        address: 'Carrefour Principal',
        quartier: 'Abobo Gare',
        ville: 'Abidjan',
        zone: 'Abidjan - Abobo',
        status: 'En attente',
        isActive: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Client(
        id: '8',
        boutiqueName: 'Magasin Ouattara',
        type: 'Boutique',
        gerantName: 'Ouattara Siaka Dramane',
        phone: '+225 07 22 33 44 55',
        address: 'Avenue de la République',
        quartier: 'Centre-ville',
        ville: 'Bouaké',
        zone: 'Bouaké - Centre',
        status: 'En attente',
        isActive: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
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

              // Clients List
              const Text(
                'Liste des Clients',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    return _buildClientCard(context, client, index);
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
