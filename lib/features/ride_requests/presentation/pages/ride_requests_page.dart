import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/repositories/ride_request_repository.dart';
import '../bloc/ride_requests/ride_requests_bloc.dart';
import '../widgets/create_ride_request_sheet.dart';
import '../widgets/ride_request_card.dart';

/// What the passenger is still waiting for.
///
/// Reached from the profile tab and from the notification that a matching ride
/// appeared. Its real job is to be somewhere the passenger can come back to:
/// a request posted from an empty search result should not vanish into a
/// system the user cannot see.
class RideRequestsPage extends StatelessWidget {
  const RideRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RideRequestsBloc>(
      create: (context) =>
          RideRequestsBloc(requests: context.read<RideRequestRepository>())
            ..add(const RideRequestsRequested()),
      child: const _RideRequestsView(),
    );
  }
}

class _RideRequestsView extends StatelessWidget {
  const _RideRequestsView();

  Future<void> _create(BuildContext context) async {
    final bloc = context.read<RideRequestsBloc>();
    final analytics = context.read<Analytics>();

    final draft = await CreateRideRequestSheet.show(
      context,
      initial: const RideRequestDraft(),
    );
    if (draft == null) return;

    analytics.log(
      Ev.rideRequestCreated,
      params: {
        'from_city_id': draft.fromCityId,
        'to_city_id': draft.toCityId,
        'seats': draft.seats,
        'flexible_days': draft.flexibleDays,
        'origin': 'requests_page',
      },
    );

    bloc.add(RideRequestSubmitted(draft));
  }

  Future<void> _cancel(BuildContext context, RideRequest request) async {
    final l10n = context.l10n;
    final bloc = context.read<RideRequestsBloc>();

    final confirmed = await AppFeedback.confirm(
      context,
      title: l10n.rideRequestCancelConfirm,
      confirmLabel: l10n.rideRequestCancel,
      isDestructive: true,
    );
    if (confirmed) bloc.add(RideRequestCancelled(request.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.myRideRequests,
      body: BlocConsumer<RideRequestsBloc, RideRequestsState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure ||
            previous.actionStatus != current.actionStatus,
        listener: (context, state) {
          final failure = state.failure;
          if (failure != null) {
            AppFeedback.error(context, failure.message(l10n));
            context.read<RideRequestsBloc>().add(
              const RideRequestsFailureCleared(),
            );
            return;
          }

          if (state.actionStatus.isSuccess) {
            // Two different messages on purpose. Finding a ride straight away
            // is a far better outcome than being put on a waiting list, and
            // saying the same thing for both would waste the good case.
            AppFeedback.success(
              context,
              state.hasMatches
                  ? l10n.rideRequestMatches
                  : l10n.rideRequestCreated,
            );
            context.read<RideRequestsBloc>().add(
              const RideRequestsFailureCleared(),
            );
          }
        },
        builder: (context, state) {
          if (state.status.isFirstLoad) return const LoadingState();

          if (state.status.isFailure && state.requests.isEmpty) {
            return ErrorState(
              failure: state.failure,
              onRetry: () => context.read<RideRequestsBloc>().add(
                const RideRequestsRequested(),
              ),
            );
          }

          if (state.isEmpty) {
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: l10n.noRideRequests,
              message: l10n.noRideRequestsBody,
              actionLabel: l10n.createRideRequest,
              onAction: () => _create(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context.read<RideRequestsBloc>().add(
              const RideRequestsRequested(refresh: true),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.xxxl,
              ),
              itemCount: state.requests.length + 1,
              separatorBuilder: (_, _) => VGap.md,
              itemBuilder: (context, index) {
                if (index == state.requests.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: Gap.md),
                    child: AppButton.secondary(
                      label: l10n.createRideRequest,
                      icon: Icons.add_rounded,
                      onPressed: () => _create(context),
                    ),
                  );
                }

                final request = state.requests[index];

                return RideRequestCard(
                  request: request,
                  showPassenger: false,
                  trailing: request.canBeCancelled
                      ? AppButton.secondary(
                          label: l10n.rideRequestCancel,
                          size: AppButtonSize.compact,
                          isLoading: state.isBusy(request.id),
                          onPressed: () => _cancel(context, request),
                        )
                      : Text(
                          _statusLabel(context, request),
                          style: context.text.labelMedium?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(BuildContext context, RideRequest request) {
    final l10n = context.l10n;

    // An open row whose date has gone by reads as expired even before the
    // server's nightly sweep gets to it — the list stays honest overnight.
    if (request.status.isOpen && request.hasExpired) {
      return l10n.rideRequestStatusExpired;
    }

    return switch (request.status) {
      RideRequestStatus.open => l10n.rideRequestStatusOpen,
      RideRequestStatus.fulfilled => l10n.rideRequestStatusFulfilled,
      RideRequestStatus.cancelled => l10n.rideRequestStatusCancelled,
      RideRequestStatus.expired => l10n.rideRequestStatusExpired,
    };
  }
}
