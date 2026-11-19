import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry_view.dart';
import '../widgets/status_pill.dart';
import '../widgets/vehicle_list_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    // La consulta es compartida: al volver a abrir la búsqueda arranca vacía.
    ref.read(searchQueryProvider.notifier).state = '';
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = query.trim();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: AppText.bodyLg.copyWith(color: c.text),
          decoration: const InputDecoration(
            hintText: 'Patente, marca o responsable',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: _onQueryChanged,
          onSubmitted: (value) {
            _debounce?.cancel();
            ref.read(searchQueryProvider.notifier).state = value.trim();
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              tooltip: 'Borrar búsqueda',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: query.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.search_rounded,
                title: 'Buscá un vehículo',
                message: 'Por patente, marca, modelo, responsable o ciudad.',
              ),
            )
          : ref
                .watch(vehicleSearchProvider(query))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => ErrorRetryView(
                    message: 'No se pudo buscar',
                    onRetry: () => ref.invalidate(vehicleSearchProvider(query)),
                  ),
                  data: (results) => _Results(query: query, results: results),
                ),
    );
  }
}

class _Results extends StatelessWidget {
  final String query;
  final List<Vehicle> results;

  const _Results({required this.query, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No encontramos "$query"',
          message: 'Revisá cómo está escrito o probá con otro dato.',
        ),
      );
    }
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.s5,
        Space.s2,
        Space.s5,
        Space.s10,
      ),
      children: [
        Text(
          results.length == 1 ? '1 resultado' : '${results.length} resultados',
          style: AppText.caption.copyWith(color: c.textMuted),
        ),
        const Gap(Space.s2),
        AppCard.list(
          children: [
            for (final vehicle in results)
              VehicleListTile(
                vehicle: vehicle,
                highlight: query,
                trailing: StatusPill.vehicle(vehicle.status),
                onTap: () => context.push('/vehicle/${vehicle.id}'),
              ),
          ],
        ),
      ],
    );
  }
}
