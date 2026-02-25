/// KPI targets for performance evaluation
class KpiTargets {
  static const double veTarget = 90.0; // Visite Effective %
  static const double tcTarget = 70.0; // Taux de Conversion %
  static const double faTarget = 90.0; // Fréquence d'Achat %
  static const double rvTargetBtq = 8.0; // Références Vendues (Boutique)
  static const double rvTargetOm = 7.0; // Références Vendues (Ouverture Marché)
  static const double caLaitTarget = 40.0; // CA Lait liquide %
  static const double caSpaguettiTarget = 40.0; // CA Spaguetti %
  static const double caTomateRizTarget = 30.0; // CA Tomate + Riz carton %
  static const double caDiversTarget = 30.0; // CA Divers %
}

/// KPI data for a single agent over a given period
class AgentKpi {
  final int userId;
  final String userName;
  final String? userPhoto;

  // VP - Visite Programmée: planned PDV visits
  final int vp;

  // VE - Visite Effective: actual visits completed
  final int ve;

  // VE rate = VE / VP * 100
  final double veRate;

  // TC - Taux de Conversion: PDVs that placed an order / VE
  final int tc;
  final double tcRate;

  // FA - Fréquence d'Achat: PDVs that ordered at least once / VP (boolean per client/month)
  final int fa;
  final double faRate;

  // RV - Références Vendues: avg product references per order = cumul produits / TC
  final double rv;

  // CA by product category (in FCFA)
  final double caLait;
  final double caSpaguetti;
  final double caTomateRiz;
  final double caDivers;
  final double caTotal;

  AgentKpi({
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.vp,
    required this.ve,
    required this.veRate,
    required this.tc,
    required this.tcRate,
    required this.fa,
    required this.faRate,
    required this.rv,
    required this.caLait,
    required this.caSpaguetti,
    required this.caTomateRiz,
    required this.caDivers,
    required this.caTotal,
  });

  factory AgentKpi.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? json;
    return AgentKpi(
      userId: json['id'] as int? ?? json['user_id'] as int? ?? 0,
      userName: json['name'] as String? ?? json['user_name'] as String? ?? '',
      userPhoto: json['photo'] as String?,
      vp: kpis['vp'] as int? ?? 0,
      ve: kpis['ve'] as int? ?? 0,
      veRate: (kpis['ve_rate'] as num?)?.toDouble() ?? 0.0,
      tc: kpis['tc'] as int? ?? 0,
      tcRate: (kpis['tc_rate'] as num?)?.toDouble() ?? 0.0,
      fa: kpis['fa'] as int? ?? 0,
      faRate: (kpis['fa_rate'] as num?)?.toDouble() ?? 0.0,
      rv: (kpis['rv'] as num?)?.toDouble() ?? 0.0,
      caLait: (kpis['ca_lait'] as num?)?.toDouble() ?? 0.0,
      caSpaguetti: (kpis['ca_spaguetti'] as num?)?.toDouble() ?? 0.0,
      caTomateRiz: (kpis['ca_tomate_riz'] as num?)?.toDouble() ?? 0.0,
      caDivers: (kpis['ca_divers'] as num?)?.toDouble() ?? 0.0,
      caTotal: (kpis['ca_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Global aggregated KPIs across all agents
class GlobalKpi {
  final int totalAgents;
  final int totalVp;
  final int totalVe;
  final double avgVeRate;
  final double avgTcRate;
  final double avgFaRate;
  final double avgRv;
  final double totalCaLait;
  final double totalCaSpaguetti;
  final double totalCaTomateRiz;
  final double totalCaDivers;
  final double totalCa;

  GlobalKpi({
    required this.totalAgents,
    required this.totalVp,
    required this.totalVe,
    required this.avgVeRate,
    required this.avgTcRate,
    required this.avgFaRate,
    required this.avgRv,
    required this.totalCaLait,
    required this.totalCaSpaguetti,
    required this.totalCaTomateRiz,
    required this.totalCaDivers,
    required this.totalCa,
  });

  factory GlobalKpi.fromAgents(List<AgentKpi> agents) {
    if (agents.isEmpty) {
      return GlobalKpi(
        totalAgents: 0,
        totalVp: 0,
        totalVe: 0,
        avgVeRate: 0,
        avgTcRate: 0,
        avgFaRate: 0,
        avgRv: 0,
        totalCaLait: 0,
        totalCaSpaguetti: 0,
        totalCaTomateRiz: 0,
        totalCaDivers: 0,
        totalCa: 0,
      );
    }

    final totalVp = agents.fold<int>(0, (sum, a) => sum + a.vp);
    final totalVe = agents.fold<int>(0, (sum, a) => sum + a.ve);

    return GlobalKpi(
      totalAgents: agents.length,
      totalVp: totalVp,
      totalVe: totalVe,
      avgVeRate: agents.fold<double>(0, (sum, a) => sum + a.veRate) / agents.length,
      avgTcRate: agents.fold<double>(0, (sum, a) => sum + a.tcRate) / agents.length,
      avgFaRate: agents.fold<double>(0, (sum, a) => sum + a.faRate) / agents.length,
      avgRv: agents.fold<double>(0, (sum, a) => sum + a.rv) / agents.length,
      totalCaLait: agents.fold<double>(0, (sum, a) => sum + a.caLait),
      totalCaSpaguetti: agents.fold<double>(0, (sum, a) => sum + a.caSpaguetti),
      totalCaTomateRiz: agents.fold<double>(0, (sum, a) => sum + a.caTomateRiz),
      totalCaDivers: agents.fold<double>(0, (sum, a) => sum + a.caDivers),
      totalCa: agents.fold<double>(0, (sum, a) => sum + a.caTotal),
    );
  }

  factory GlobalKpi.fromJson(Map<String, dynamic> json) {
    return GlobalKpi(
      totalAgents: json['total_agents'] as int? ?? 0,
      totalVp: json['total_vp'] as int? ?? 0,
      totalVe: json['total_ve'] as int? ?? 0,
      avgVeRate: (json['avg_ve_rate'] as num?)?.toDouble() ?? 0.0,
      avgTcRate: (json['avg_tc_rate'] as num?)?.toDouble() ?? 0.0,
      avgFaRate: (json['avg_fa_rate'] as num?)?.toDouble() ?? 0.0,
      avgRv: (json['avg_rv'] as num?)?.toDouble() ?? 0.0,
      totalCaLait: (json['total_ca_lait'] as num?)?.toDouble() ?? 0.0,
      totalCaSpaguetti: (json['total_ca_spaguetti'] as num?)?.toDouble() ?? 0.0,
      totalCaTomateRiz: (json['total_ca_tomate_riz'] as num?)?.toDouble() ?? 0.0,
      totalCaDivers: (json['total_ca_divers'] as num?)?.toDouble() ?? 0.0,
      totalCa: (json['total_ca'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Full dashboard response
class AgentsDashboardData {
  final List<AgentKpi> agents;
  final GlobalKpi global;
  final String periodLabel;
  final String periodStart;
  final String periodEnd;

  AgentsDashboardData({
    required this.agents,
    required this.global,
    required this.periodLabel,
    required this.periodStart,
    required this.periodEnd,
  });

  factory AgentsDashboardData.fromJson(Map<String, dynamic> json) {
    final agentsList = (json['agents'] as List<dynamic>? ?? [])
        .map((e) => AgentKpi.fromJson(e as Map<String, dynamic>))
        .toList();

    final globalData = json['global'] as Map<String, dynamic>?;
    final global = globalData != null
        ? GlobalKpi.fromJson(globalData)
        : GlobalKpi.fromAgents(agentsList);

    final period = json['period'] as Map<String, dynamic>? ?? {};

    return AgentsDashboardData(
      agents: agentsList,
      global: global,
      periodLabel: period['label'] as String? ?? '',
      periodStart: period['start'] as String? ?? '',
      periodEnd: period['end'] as String? ?? '',
    );
  }
}
