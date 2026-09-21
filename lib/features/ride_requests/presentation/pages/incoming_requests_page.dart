import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../rides/presentation/bloc/publish_ride/publish_ride_bloc.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/ride_request_repository.dart';
import '../bloc/incoming_requests/incoming_requests_bloc.dart';
import '../widgets/ride_request_card.dart';

/// Who is looking for a seat on the routes this driver runs.
///
/// The answer to the question publishing used to be: a guess. Every row here is
/// a named person with a date and a seat count — a far stronger reason to post
/// a listing than "43 people searched this week".
class IncomingRequestsPage extends StatelessWidget {
  const IncomingRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IncomingRequestsBloc>(
      create: (context) =>
          IncomingRequestsBloc(requests: context.read<RideRequestRepository>())
            ..add(const IncomingRequestsRequested()),
      child: const _IncomingRequestsView(),
    );
  }
}

class _IncomingRequestsView extends StatefulWidget {
  const _IncomingRequestsView();

  @override
  State<_IncomingRequestsView> createState() => _IncomingRequestsViewState();
}

class _IncomingRequestsViewState extends State<_IncomingRequestsView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) {
      context.read<IncomingRequestsBloc>().add(
        const IncomingRequestsMoreRequested(),
      );
    }
  }

  /// Opens the publish form with this request's route already filled in.
  ///
  /// The whole point of the screen: the driver should never have to retype
  /// what the passenger already told us.
  void _publishFor(BuildContext context, RideRequest request) {
    context.push(
      Routes.publishRide,
      extra: RidePrefill(
        fromCityId: request.fromCity.id,
        toCityId: request.toCity.id,
        date: request.wantedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.incomingRideRequests,
      body: BlocBuilder<IncomingRequestsBloc, IncomingRequestsState>(
        builder: (context, state) {
          if (state.status.isFirstLoad) return const LoadingState();

          if (state.status.isFailure && state.requests.isEmpty) {
            return ErrorState(
              failure: state.failure,
              onRetry: () => context.read<IncomingRequestsBloc>().add(
                const IncomingRequestsRequested(),
              ),
            );
          }

          if (state.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: l10n.noIncomingRideRequests,
              message: l10n.noIncomingRideRequestsBody,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context.read<IncomingRequestsBloc>().add(
              const IncomingRequestsRequested(refresh: true),
            ),
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.xxxl,
              ),
              itemCount: state.requests.length + 1,
              separatorBuilder: (_, _) => VGap.md,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: _SummaryCard(
                      requests: state.requests.length,
                      seats: state.totalSeatsWanted,
                    ),
                  );
                }

                final request = state.requests[index - 1];

                return RideRequestCard(
                  request: request,
                  trailing: AppButton(
                    label: l10n.publishForThisRequest,
                    icon: Icons.add_road_rounded,
                    size: AppButtonSize.compact,
                    onPressed: () => _publishFor(context, request),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// The one line worth putting above the list: how much demand is sitting here.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.requests, required this.seats});

  final int requests;
  final int seats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: context.colors.primary),
          HGap.lg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.demandRequests(requests), style: context.text.titleSmall),
                VGap.xs,
                Text(
                  l10n.seats(seats),
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
