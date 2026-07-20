import 'package:flutter/material.dart';

import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_statistics_tab.dart';

/// Tabbed shell for the new Statistics feature. Exactly one tab in this
/// milestone — Lure Statistics — structured to accommodate additional tabs
/// later (e.g. General Catch / Fishing Statistics, `docs/roadmap.md` §3.3),
/// per MFS-019 FR-2.
///
/// Unlike `LureToolsPage` (TD-016), which exists specifically as the one
/// place two otherwise-independent features are allowed to meet, this shell
/// and its tab(s) all belong to the `statistics` feature — see TD-019's Key
/// Design Decision 7.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key, required this.repository});

  final LureStatisticsRepository repository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tilastot'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Viehetilastot', icon: Icon(Icons.bar_chart))],
          ),
        ),
        body: TabBarView(children: [LureStatisticsTab(repository: repository)]),
      ),
    );
  }
}
