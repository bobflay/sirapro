import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agent_kpi.dart';
import '../services/agents_dashboard_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class AgentsDashboardPage extends StatefulWidget {
  const AgentsDashboardPage({super.key});

  @override
  State<AgentsDashboardPage> createState() => _AgentsDashboardPageState();
}

class _AgentsDashboardPageState extends State<AgentsDashboardPage> {
  final AgentsDashboardService _dashboardService = AgentsDashboardService();
  final _searchController = TextEditingController();

  AgentsDashboardData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;

  // Period selection
  _PeriodOption _selectedPeriod = _PeriodOption.currentMonth;
  DateTime _customStart = DateTime.now();
  DateTime _customEnd = DateTime.now();

  // Search/filter
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  (String, String) _getPeriodDates() {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    switch (_selectedPeriod) {
      case _PeriodOption.today:
        return (fmt.format(now), fmt.format(now));
      case _PeriodOption.currentWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (fmt.format(monday), fmt.format(now));
      case _PeriodOption.currentMonth:
        return (fmt.format(DateTime(now.year, now.month, 1)), fmt.format(now));
      case _PeriodOption.custom:
        return (fmt.format(_customStart), fmt.format(_customEnd));
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final (start, end) = _getPeriodDates();
      final data = await _dashboardService.getDashboardData(
        startDate: start,
        endDate: end,
      );
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du chargement des données';
          _isLoading = false;
        });
      }
    }
  }

  List<AgentKpi> get _filteredAgents {
    if (_dashboardData == null) return [];
    if (_searchQuery.isEmpty) return _dashboardData!.agents;
    return _dashboardData!.agents
        .where((a) =>
            a.userName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _selectCustomPeriod() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _selectedPeriod = _PeriodOption.custom;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tableau de Bord Agents'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _PeriodChip(
              label: "Aujourd'hui",
              selected: _selectedPeriod == _PeriodOption.today,
              onTap: () {
                setState(() => _selectedPeriod = _PeriodOption.today);
                _loadData();
              },
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: 'Cette semaine',
              selected: _selectedPeriod == _PeriodOption.currentWeek,
              onTap: () {
                setState(() => _selectedPeriod = _PeriodOption.currentWeek);
                _loadData();
              },
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: 'Ce mois',
              selected: _selectedPeriod == _PeriodOption.currentMonth,
              onTap: () {
                setState(() => _selectedPeriod = _PeriodOption.currentMonth);
                _loadData();
              },
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: _selectedPeriod == _PeriodOption.custom
                  ? '${DateFormat('dd/MM').format(_customStart)} - ${DateFormat('dd/MM').format(_customEnd)}'
                  : 'Personnalisé',
              selected: _selectedPeriod == _PeriodOption.custom,
              onTap: _selectCustomPeriod,
              icon: Icons.date_range,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un agent...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _dashboardData!;
    final filtered = _filteredAgents;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Period label
          if (data.periodLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                data.periodLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.darkGray,
                ),
              ),
            ),

          // Global KPI summary
          _GlobalKpiCard(global: data.global),
          const SizedBox(height: 12),

          // KPI targets reference
          _KpiTargetsCard(),
          const SizedBox(height: 12),

          // Agents count label
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${filtered.length} agent${filtered.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.accent,
              ),
            ),
          ),

          // Agent cards
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Aucun agent trouvé',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            )
          else
            ...filtered.map((agent) => _AgentKpiCard(agent: agent)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Global KPI summary card
// ──────────────────────────────────────────────
class _GlobalKpiCard extends StatelessWidget {
  final GlobalKpi global;
  const _GlobalKpiCard({required this.global});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Vue Globale — ${global.totalAgents} Agent${global.totalAgents > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _GlobalKpiTile(
                label: 'VP Total',
                value: '${global.totalVp}',
                icon: Icons.calendar_today,
              ),
              _GlobalKpiTile(
                label: 'VE Total',
                value: '${global.totalVe}',
                icon: Icons.check_circle_outline,
              ),
              _GlobalKpiTile(
                label: 'VE Moy.',
                value: '${global.avgVeRate.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                isRate: true,
                rate: global.avgVeRate,
                target: KpiTargets.veTarget,
              ),
              _GlobalKpiTile(
                label: 'TC Moy.',
                value: '${global.avgTcRate.toStringAsFixed(1)}%',
                icon: Icons.shopping_cart,
                isRate: true,
                rate: global.avgTcRate,
                target: KpiTargets.tcTarget,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _GlobalKpiTile(
                label: 'FA Moy.',
                value: '${global.avgFaRate.toStringAsFixed(1)}%',
                icon: Icons.repeat,
                isRate: true,
                rate: global.avgFaRate,
                target: KpiTargets.faTarget,
              ),
              _GlobalKpiTile(
                label: 'RV Moy.',
                value: global.avgRv.toStringAsFixed(1),
                icon: Icons.inventory_2,
              ),
              _GlobalKpiTile(
                label: 'CA Total',
                value: _formatCA(global.totalCa),
                icon: Icons.attach_money,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white30, height: 1),
          const SizedBox(height: 10),
          // CA breakdown
          Row(
            children: [
              _CaTile(label: 'Lait', value: global.totalCaLait),
              _CaTile(label: 'Spaguetti', value: global.totalCaSpaguetti),
              _CaTile(label: 'Tom+Riz', value: global.totalCaTomateRiz),
              _CaTile(label: 'Divers', value: global.totalCaDivers),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatCA(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _GlobalKpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isRate;
  final double? rate;
  final double? target;

  const _GlobalKpiTile({
    required this.label,
    required this.value,
    required this.icon,
    this.isRate = false,
    this.rate,
    this.target,
  });

  Color get _valueColor {
    if (!isRate || rate == null || target == null) return Colors.white;
    if (rate! >= target!) return const Color(0xFF81C784);
    if (rate! >= target! * 0.8) return const Color(0xFFFFD54F);
    return const Color(0xFFEF9A9A);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white60, size: 12),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: _valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaTile extends StatelessWidget {
  final String label;
  final double value;
  const _CaTile({required this.label, required this.value});

  String get _formatted {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          Text(
            _formatted,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// KPI Targets reference card
// ──────────────────────────────────────────────
class _KpiTargetsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: AppColors.secondary, size: 16),
              SizedBox(width: 6),
              Text(
                'Objectifs KPI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _TargetChip(label: 'VE', target: '${KpiTargets.veTarget.toInt()}%'),
              _TargetChip(label: 'TC', target: '${KpiTargets.tcTarget.toInt()}%'),
              _TargetChip(label: 'FA', target: '${KpiTargets.faTarget.toInt()}%'),
              _TargetChip(
                  label: 'RV (Btq)',
                  target: KpiTargets.rvTargetBtq.toStringAsFixed(0)),
              _TargetChip(
                  label: 'RV (OM)',
                  target: KpiTargets.rvTargetOm.toStringAsFixed(0)),
              _TargetChip(
                  label: 'CA Lait',
                  target: '${KpiTargets.caLaitTarget.toInt()}%'),
              _TargetChip(
                  label: 'CA Spag.',
                  target: '${KpiTargets.caSpaguettiTarget.toInt()}%'),
              _TargetChip(
                  label: 'CA Tom+Riz',
                  target: '${KpiTargets.caTomateRizTarget.toInt()}%'),
              _TargetChip(
                  label: 'CA Divers',
                  target: '${KpiTargets.caDiversTarget.toInt()}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final String target;
  const _TargetChip({required this.label, required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryVeryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.darkGray),
            ),
            TextSpan(
              text: target,
              style: const TextStyle(
                color: AppColors.secondaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Per-agent KPI card
// ──────────────────────────────────────────────
class _AgentKpiCard extends StatefulWidget {
  final AgentKpi agent;
  const _AgentKpiCard({required this.agent});

  @override
  State<_AgentKpiCard> createState() => _AgentKpiCardState();
}

class _AgentKpiCardState extends State<_AgentKpiCard> {
  bool _expanded = false;

  Color _kpiColor(double value, double target) {
    if (value >= target) return AppColors.success;
    if (value >= target * 0.8) return AppColors.secondary;
    return AppColors.primary;
  }

  Color _rvColor(double rv) {
    final avg = (KpiTargets.rvTargetBtq + KpiTargets.rvTargetOm) / 2;
    if (rv >= avg) return AppColors.success;
    if (rv >= avg * 0.8) return AppColors.secondary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryVeryLight,
                    backgroundImage: a.userPhoto != null && a.userPhoto!.isNotEmpty
                        ? NetworkImage(a.userPhoto!)
                        : null,
                    child: a.userPhoto == null || a.userPhoto!.isEmpty
                        ? Text(
                            a.userName.isNotEmpty
                                ? a.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // Name + quick stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _QuickBadge(
                              label: 'VP ${a.vp}',
                              color: AppColors.gray,
                            ),
                            const SizedBox(width: 4),
                            _QuickBadge(
                              label:
                                  'VE ${a.veRate.toStringAsFixed(0)}%',
                              color: _kpiColor(
                                  a.veRate, KpiTargets.veTarget),
                            ),
                            const SizedBox(width: 4),
                            _QuickBadge(
                              label:
                                  'TC ${a.tcRate.toStringAsFixed(0)}%',
                              color: _kpiColor(
                                  a.tcRate, KpiTargets.tcTarget),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // CA total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCA(a.caTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.accent,
                        ),
                      ),
                      const Text(
                        'CA Total',
                        style: TextStyle(fontSize: 10, color: AppColors.gray),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.gray,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // KPI grid (always visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _KpiCell(
                      symbol: 'VP',
                      name: 'Visite Prog.',
                      value: '${a.vp}',
                      unit: 'AN',
                      color: AppColors.darkGray,
                    ),
                    _KpiCell(
                      symbol: 'VE',
                      name: 'Visite Eff.',
                      value: '${a.veRate.toStringAsFixed(1)}%',
                      unit: '%',
                      color: _kpiColor(a.veRate, KpiTargets.veTarget),
                      targetLabel: '≥${KpiTargets.veTarget.toInt()}%',
                    ),
                    _KpiCell(
                      symbol: 'TC',
                      name: 'Taux Conv.',
                      value: '${a.tcRate.toStringAsFixed(1)}%',
                      unit: '%',
                      color: _kpiColor(a.tcRate, KpiTargets.tcTarget),
                      targetLabel: '≥${KpiTargets.tcTarget.toInt()}%',
                    ),
                    _KpiCell(
                      symbol: 'FA',
                      name: 'Fréq. Achat',
                      value: '${a.faRate.toStringAsFixed(1)}%',
                      unit: '%',
                      color: _kpiColor(a.faRate, KpiTargets.faTarget),
                      targetLabel: '≥${KpiTargets.faTarget.toInt()}%',
                    ),
                    _KpiCell(
                      symbol: 'RV',
                      name: 'Réf. Vendues',
                      value: a.rv.toStringAsFixed(1),
                      unit: 'AN',
                      color: _rvColor(a.rv),
                      targetLabel: '≥${KpiTargets.rvTargetOm.toInt()}',
                    ),
                  ],
                ),

                // Expanded CA breakdown
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chiffres d\'Affaires',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CaCell(
                        label: 'Lait Liquide',
                        value: a.caLait,
                        total: a.caTotal,
                        target: KpiTargets.caLaitTarget,
                      ),
                      _CaCell(
                        label: 'Spaguetti',
                        value: a.caSpaguetti,
                        total: a.caTotal,
                        target: KpiTargets.caSpaguettiTarget,
                      ),
                      _CaCell(
                        label: 'Tom+Riz',
                        value: a.caTomateRiz,
                        total: a.caTotal,
                        target: KpiTargets.caTomateRizTarget,
                      ),
                      _CaCell(
                        label: 'Divers',
                        value: a.caDivers,
                        total: a.caTotal,
                        target: KpiTargets.caDiversTarget,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // CA progress bars
                  _CaProgressBar(
                    label: 'Lait',
                    value: a.caLait,
                    total: a.caTotal,
                    target: KpiTargets.caLaitTarget,
                    color: const Color(0xFF42A5F5),
                  ),
                  const SizedBox(height: 4),
                  _CaProgressBar(
                    label: 'Spaguetti',
                    value: a.caSpaguetti,
                    total: a.caTotal,
                    target: KpiTargets.caSpaguettiTarget,
                    color: const Color(0xFFAB47BC),
                  ),
                  const SizedBox(height: 4),
                  _CaProgressBar(
                    label: 'Tom+Riz',
                    value: a.caTomateRiz,
                    total: a.caTotal,
                    target: KpiTargets.caTomateRizTarget,
                    color: const Color(0xFFEF5350),
                  ),
                  const SizedBox(height: 4),
                  _CaProgressBar(
                    label: 'Divers',
                    value: a.caDivers,
                    total: a.caTotal,
                    target: KpiTargets.caDiversTarget,
                    color: AppColors.secondary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCA(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K FCFA';
    return '${value.toStringAsFixed(0)} FCFA';
  }
}

class _QuickBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _QuickBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String symbol;
  final String name;
  final String value;
  final String unit;
  final Color color;
  final String? targetLabel;

  const _KpiCell({
    required this.symbol,
    required this.name,
    required this.value,
    required this.unit,
    required this.color,
    this.targetLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            symbol,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: AppColors.gray),
          ),
          if (targetLabel != null)
            Text(
              targetLabel!,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.gray,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _CaCell extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final double target;

  const _CaCell({
    required this.label,
    required this.value,
    required this.total,
    required this.target,
  });

  double get _percent => total > 0 ? (value / total) * 100 : 0;

  Color get _color {
    if (_percent >= target) return AppColors.success;
    if (_percent >= target * 0.8) return AppColors.secondary;
    return AppColors.primary;
  }

  String get _formatted {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            _formatted,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: AppColors.gray),
          ),
          Text(
            '${_percent.toStringAsFixed(0)}% (≥${target.toInt()}%)',
            style: const TextStyle(fontSize: 9, color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}

class _CaProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final double target;
  final Color color;

  const _CaProgressBar({
    required this.label,
    required this.value,
    required this.total,
    required this.target,
    required this.color,
  });

  double get _percent => total > 0 ? (value / total) * 100 : 0;
  bool get _meetsTarget => _percent >= target;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.darkGray),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              // Target marker
              FractionallySizedBox(
                widthFactor: (target / 100).clamp(0, 1),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 2,
                    height: 14,
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // Actual value
              FractionallySizedBox(
                widthFactor: (_percent / 100).clamp(0, 1),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: _meetsTarget
                        ? AppColors.success.withValues(alpha: 0.8)
                        : color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '${_percent.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _meetsTarget ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Period chip
// ──────────────────────────────────────────────
class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.lightGray,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppColors.darkGray,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.darkGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PeriodOption { today, currentWeek, currentMonth, custom }
