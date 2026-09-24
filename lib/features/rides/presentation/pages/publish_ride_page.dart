import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/route_timeline.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../../../profile/domain/entities/user_enums.dart';
import '../../../profile/presentation/bloc/driver_profile/driver_profile_bloc.dart';
import '../../domain/entities/route_demand.dart';
import '../../domain/repositories/demand_repository.dart';
import '../../domain/repositories/ride_repository.dart';
import '../bloc/publish_ride/publish_ride_bloc.dart';
import '../widgets/city_picker_sheet.dart';

/// Three-step publish form: route → schedule → details.
///
/// Backed by `POST /rides`, or `PUT /rides/{id}` when [rideId] is set. API.md
/// §9 lists exactly which fields an edit may touch, and the route and vehicle
/// are not among them — the first step is read-only when editing.
class PublishRidePage extends StatelessWidget {
  const PublishRidePage({super.key, this.rideId, this.prefill});

  /// When set, the form edits that listing instead of creating a new one.
  final int? rideId;

  /// A route the driver already picked elsewhere — from a passenger's request
  /// or from the demand list. Ignored while editing, where the route is fixed.
  final RidePrefill? prefill;

  @override
  Widget build(BuildContext context) {
    // Several screens lead here — the FAB, the demand strip, a passenger's
    // request — so the approval rule is enforced at the form rather than at
    // each button. Editing is exempt: the listing already exists.
    if (rideId == null) {
      final driverState = context.watch<DriverProfileBloc>().state;
      if (driverState.profile == null) {
        return AppScaffold(
          title: context.l10n.publishRide,
          body: driverState.status.isFailure
              ? ErrorState(failure: driverState.failure)
              : const LoadingState(),
        );
      }
      if (!driverState.canPublishRides) return const _PublishLocked();
    }

    final driver = context.read<DriverProfileBloc>().state.profile;

    return BlocProvider<PublishRideBloc>(
      create: (context) =>
          PublishRideBloc(rides: context.read<RideRepository>())..add(
            PublishRideStarted(
              rideId: rideId,
              prefill: prefill,
              // A driver with one car never sees a picker.
              vehicleId: driver?.vehicle?.id,
              instantBookingDefault: driver?.instantBookingDefault ?? false,
            ),
          ),
      child: _PublishRideView(isEditing: rideId != null),
    );
  }
}

/// Shown in place of the form while the driver has no car or their documents
/// are not approved yet — says which, and leads to the fix.
class _PublishLocked extends StatefulWidget {
  const _PublishLocked();

  @override
  State<_PublishLocked> createState() => _PublishLockedState();
}

class _PublishLockedState extends State<_PublishLocked> {
  @override
  void initState() {
    super.initState();
    // The profile was read at sign-in; an admin may have approved the
    // documents since. A fresh read turns this screen into the form by itself.
    context.read<DriverProfileBloc>().add(
      const DriverProfileRequested(force: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = context.read<DriverProfileBloc>().state.profileOrInitial;

    if (!profile.hasVehicle) {
      return AppScaffold(
        title: l10n.publishRide,
        body: EmptyState(
          icon: Icons.directions_car_outlined,
          title: l10n.vehicleInfo,
          message: l10n.noVehicle,
          actionLabel: l10n.saveVehicle,
          onAction: () => context.pushReplacement(Routes.vehicle),
        ),
      );
    }

    final (icon, title, message) = switch (profile.status) {
      VerificationStatus.pending => (
        Icons.hourglass_top_rounded,
        l10n.verificationPending,
        l10n.verificationPendingBody,
      ),
      VerificationStatus.rejected => (
        Icons.assignment_late_outlined,
        l10n.verificationRejected,
        l10n.verificationRejectedBody,
      ),
      _ => (
        Icons.assignment_outlined,
        l10n.documentsTitle,
        l10n.documentsSubtitle,
      ),
    };

    return AppScaffold(
      title: l10n.publishRide,
      body: EmptyState(
        icon: icon,
        title: title,
        message: message,
        actionLabel: profile.status == VerificationStatus.pending
            ? l10n.documents
            : l10n.uploadDocument,
        onAction: () => context.pushReplacement(Routes.documents),
      ),
    );
  }
}

class _PublishRideView extends StatelessWidget {
  const _PublishRideView({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<PublishRideBloc, PublishRideState>(
      listenWhen: (previous, current) =>
          previous.submitStatus != current.submitStatus,
      listener: (context, state) {
        final published = state.publishedRide;
        if (state.submitStatus.isSuccess && published != null) {
          HapticFeedback.mediumImpact();
          AppFeedback.success(
            context,
            isEditing
                ? l10n.rideUpdated
                // A weekly repeat creates several listings in one submit, and
                // saying "ride published" would understate what just happened.
                : l10n.ridesPublished(state.draft.repeatWeeks),
          );

          context.read<Analytics>().log(
            Ev.publishCompleted,
            params: {
              'from_city_id': state.draft.fromCityId,
              'to_city_id': state.draft.toCityId,
              'seats': state.draft.totalSeats,
              'price': state.draft.pricePerSeat,
              'women_only': state.draft.womenOnly,
              'repeat_weeks': state.draft.repeatWeeks,
              'instant_booking': state.draft.instantBooking,
            },
          );
          if (isEditing) {
            context.pop();
          } else {
            // Replace the form with the listing it just created.
            context.pushReplacement(Routes.rideDetail(published.id));
          }
          return;
        }
        final failure = state.failure;
        if (state.submitStatus.isFailure && failure != null) {
          AppFeedback.error(context, failure.message(l10n));
        }
      },
      builder: (context, state) {
        final bloc = context.read<PublishRideBloc>();
        final isFirst = state.step == PublishStep.route;

        if (state.loadStatus.isFirstLoad && isEditing) {
          return AppScaffold(title: l10n.editRide, body: const LoadingState());
        }
        if (state.loadStatus.isFailure) {
          return AppScaffold(
            title: l10n.editRide,
            body: ErrorState(failure: state.failure),
          );
        }

        return DismissKeyboard(
          child: PopScope(
            canPop: isFirst,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                bloc.add(PublishRideStepChanged(state.step.previous!));
              }
            },
            child: AppScaffold(
              title: isEditing ? l10n.editRide : l10n.publishRide,
              leading: IconButton(
                icon: Icon(
                  isFirst ? Icons.close_rounded : Icons.arrow_back_rounded,
                ),
                onPressed: () {
                  if (isFirst) {
                    context.pop();
                  } else {
                    bloc.add(PublishRideStepChanged(state.step.previous!));
                  }
                },
              ),
              appBarBottom: PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    0,
                    Gap.page,
                    Gap.md,
                  ),
                  child: StepProgress(
                    current: state.step.number,
                    total: PublishStep.count,
                  ),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.normal,
                      switchInCurve: Motion.emphasized,
                      child: switch (state.step) {
                        PublishStep.route => const _RouteStep(key: ValueKey(0)),
                        PublishStep.schedule => const _ScheduleStep(
                          key: ValueKey(1),
                        ),
                        PublishStep.details => _DetailsStep(
                          key: const ValueKey(2),
                          isEditing: isEditing,
                        ),
                      },
                    ),
                  ),
                  BottomActionBar(
                    caption: Text(
                      l10n.stepOf(state.step.number, PublishStep.count),
                      style: context.text.bodySmall,
                    ),
                    child: AppButton(
                      label: state.isLastStep ? l10n.publish : l10n.next,
                      trailingIcon: state.isLastStep
                          ? null
                          : Icons.arrow_forward_rounded,
                      isLoading: state.submitStatus.isBusy,
                      onPressed: state.canContinue
                          ? () => state.isLastStep
                                ? bloc.add(const PublishRideSubmitted())
                                : bloc.add(
                                    PublishRideStepChanged(state.step.next!),
                                  )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ step one
class _RouteStep extends StatelessWidget {
  const _RouteStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = l10n.languageCode;
    final cities = context.read<CityRepository>();

    return BlocBuilder<PublishRideBloc, PublishRideState>(
      builder: (context, state) {
        final bloc = context.read<PublishRideBloc>();
        final draft = state.draft;
        final from = cities.byId(draft.fromCityId);
        final to = cities.byId(draft.toCityId);
        final distance = City.distanceKm(from, to);
        final duration = City.estimatedDrive(from, to);
        final locked = !state.canEditRoute;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.xl,
            Gap.page,
            Gap.xxl,
          ),
          children: [
            Text(l10n.routeStep, style: context.text.headlineSmall),
            VGap.sm,
            Text(l10n.selectCity, style: context.text.bodyMedium),
            VGap.xxl,

            if (locked) ...[
              InfoBanner(tone: BannerTone.info, message: l10n.routeNotEditable),
              VGap.lg,
            ],

            AppPickerField(
              label: l10n.fromCity,
              icon: Icons.trip_origin_rounded,
              value: from?.nameFor(code),
              placeholder: l10n.selectCity,
              enabled: !locked,
              onTap: () async {
                final city = await CityPickerSheet.show(
                  context,
                  title: l10n.fromCity,
                  excludeCityId: draft.toCityId,
                  selectedCityId: draft.fromCityId,
                );
                if (city != null) {
                  bloc.add(PublishRideFieldChanged(fromCityId: city.id));
                }
              },
            ),
            VGap.sm,
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: l10n.swapCities,
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: locked
                    ? null
                    : () => bloc.add(const PublishRideRouteSwapped()),
              ),
            ),
            AppPickerField(
              label: l10n.toCity,
              icon: Icons.place_rounded,
              value: to?.nameFor(code),
              placeholder: l10n.selectCity,
              enabled: !locked,
              onTap: () async {
                final city = await CityPickerSheet.show(
                  context,
                  title: l10n.toCity,
                  excludeCityId: draft.fromCityId,
                  selectedCityId: draft.toCityId,
                );
                if (city != null) {
                  bloc.add(PublishRideFieldChanged(toCityId: city.id));
                }
              },
            ),

            if (!locked) ...[VGap.xl, const _VehiclePicker()],

            if (distance != null && duration != null) ...[
              VGap.xxl,
              AppCard(
                color: context.palette.surfaceSunken,
                elevated: false,
                child: Row(
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 18,
                      color: context.palette.textSecondary,
                    ),
                    HGap.md,
                    Expanded(
                      child: Text(
                        '≈ ${distance.round()} km',
                        style: context.text.bodyMedium,
                      ),
                    ),
                    Text(
                      context.fmt.duration(duration),
                      style: context.text.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Only shown when the driver has more than one car — `vehicle_id` is required
/// by `POST /rides`, and a single car is already preselected.
class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<DriverProfileBloc, DriverProfileState>(
      builder: (context, driverState) {
        final vehicle = driverState.profile?.vehicle;
        if (vehicle == null) {
          return InfoBanner(
            tone: BannerTone.warning,
            title: l10n.vehicleInfo,
            message: l10n.noVehicle,
            action: AppButton.ghost(
              label: l10n.saveVehicle,
              onPressed: () => context.push(Routes.vehicle),
            ),
          );
        }

        return AppCard(
          color: context.palette.surfaceSunken,
          elevated: false,
          child: Row(
            children: [
              Icon(
                Icons.directions_car_filled_outlined,
                size: 20,
                color: context.palette.textSecondary,
              ),
              HGap.md,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.summary, style: context.text.bodyLarge),
                    Text(
                      l10n.seatsIncludeDriver,
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              VehicleColorDot(colorValue: vehicle.color),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ step two
class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final cities = context.read<CityRepository>();

    return BlocBuilder<PublishRideBloc, PublishRideState>(
      builder: (context, state) {
        final bloc = context.read<PublishRideBloc>();
        final draft = state.draft;

        Future<void> pickDate() async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: draft.date ?? now,
            firstDate: DateTime(now.year, now.month, now.day),
            // The API sets no upper bound on `departure_at` beyond "future".
            lastDate: now.add(const Duration(days: 365)),
            helpText: l10n.selectDate,
          );
          if (picked != null) {
            bloc.add(PublishRideFieldChanged(date: picked));
          }
        }

        Future<void> pickTime() async {
          final current = draft.timeOfDayMinutes;
          final picked = await showTimePicker(
            context: context,
            initialTime: current == null
                ? const TimeOfDay(hour: 8, minute: 0)
                : TimeOfDay(hour: current ~/ 60, minute: current % 60),
            helpText: l10n.selectTime,
            builder: (context, child) => MediaQuery(
              // Azerbaijan uses the 24-hour clock.
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          );
          if (picked != null) {
            bloc.add(
              PublishRideFieldChanged(
                timeOfDayMinutes: picked.hour * 60 + picked.minute,
              ),
            );
          }
        }

        final departure = draft.departureAt;
        final isPast = departure != null && departure.isBefore(DateTime.now());
        final from = cities.byId(draft.fromCityId);
        final to = cities.byId(draft.toCityId);

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.xl,
            Gap.page,
            Gap.xxl,
          ),
          children: [
            Text(l10n.scheduleStep, style: context.text.headlineSmall),
            VGap.sm,
            Text(l10n.departure, style: context.text.bodyMedium),
            VGap.xxl,

            AppPickerField(
              label: l10n.date,
              icon: Icons.calendar_today_rounded,
              value: draft.date == null ? null : fmt.fullDate(draft.date!),
              placeholder: l10n.selectDate,
              onTap: pickDate,
            ),
            VGap.lg,
            AppPickerField(
              label: l10n.time,
              icon: Icons.schedule_rounded,
              value: draft.timeOfDayMinutes == null
                  ? null
                  : _formatMinutes(draft.timeOfDayMinutes!),
              placeholder: l10n.selectTime,
              errorText: isPast ? l10n.pastDateError : null,
              onTap: pickTime,
            ),

            VGap.xl,
            Text(
              l10n.time,
              style: context.text.labelMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            VGap.sm,
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                // Quick picks cover the overwhelmingly common departures.
                for (final minutes in const [
                  360,
                  420,
                  480,
                  540,
                  720,
                  960,
                  1080,
                ])
                  ActionChip(
                    onPressed: () => bloc.add(
                      PublishRideFieldChanged(timeOfDayMinutes: minutes),
                    ),
                    label: Text(_formatMinutes(minutes)),
                    backgroundColor: draft.timeOfDayMinutes == minutes
                        ? context.colors.primaryContainer
                        : null,
                  ),
              ],
            ),

            if (departure != null && !isPast && from != null && to != null) ...[
              VGap.xxl,
              AppCard(
                child: RouteTimeline(
                  fromCity: from,
                  toCity: to,
                  departureAt: departure,
                  compact: true,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------- step three
class _DetailsStep extends StatefulWidget {
  const _DetailsStep({super.key, this.isEditing = false});

  /// Editing one listing must never fan out into a weekly series, so the
  /// repeat picker is hidden here.
  final bool isEditing;

  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  late final TextEditingController _priceController;
  late final TextEditingController _pickupController;
  late final TextEditingController _dropoffController;
  late final TextEditingController _noteController;

  /// The server's answer for the current route, once it arrives.
  PriceSuggestion? _suggestion;

  /// The route the answer belongs to, so a changed route refetches and an
  /// unchanged one does not.
  (int, int)? _suggestionRoute;

  @override
  void initState() {
    super.initState();
    final draft = context.read<PublishRideBloc>().state.draft;
    _priceController = TextEditingController(text: _money(draft.pricePerSeat));
    _pickupController = TextEditingController(text: draft.pickupPoint);
    _dropoffController = TextEditingController(text: draft.dropoffPoint);
    _noteController = TextEditingController(text: draft.note);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _money(double? value) {
    if (value == null) return '';
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  /// Fetches the route's price hint once, from inside `build`.
  ///
  /// Called during build but never emits during it: the request is fired on
  /// the next microtask and `setState` runs when it lands. Cheaper than a bloc
  /// for what is one read whose only consumers are two widgets on this step.
  void _ensureSuggestion(int? fromCityId, int? toCityId) {
    if (fromCityId == null || toCityId == null) return;

    final route = (fromCityId, toCityId);
    if (_suggestionRoute == route) return;
    _suggestionRoute = route;

    final demand = context.read<DemandRepository>();

    Future<void>.microtask(() async {
      final result = await demand.priceFor(
        fromCityId: fromCityId,
        toCityId: toCityId,
      );
      if (!mounted || _suggestionRoute != route) return;

      // A failure leaves `_suggestion` null and the local distance estimate
      // stands in — a missing hint is not worth an error message.
      if (result case Ok(:final value)) setState(() => _suggestion = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final cities = context.read<CityRepository>();

    return BlocBuilder<PublishRideBloc, PublishRideState>(
      builder: (context, state) {
        final bloc = context.read<PublishRideBloc>();
        final draft = state.draft;

        // The women-only switch is the driver's own gender, not a preference
        // — and the server refuses it for anyone else.
        final isWomanDriver = context.select<SessionBloc, bool>(
          (bloc) => bloc.state.user?.gender.isFemale ?? false,
        );

        // Asked for once per route and cached. The server answers from real
        // listings on this route where it can and falls back to distance where
        // it cannot, so the hint is the market's own number rather than ours.
        _ensureSuggestion(draft.fromCityId, draft.toCityId);

        // Until the request lands — and on a server that does not know the
        // endpoint — the local distance estimate stands in, so the field is
        // never left without a hint.
        final suggested =
            _suggestion?.suggested ??
            City.suggestedPrice(
              cities.byId(draft.fromCityId),
              cities.byId(draft.toCityId),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.xl,
            Gap.page,
            Gap.xxl,
          ),
          children: [
            Text(l10n.detailsStep, style: context.text.headlineSmall),
            VGap.xxl,

            Text(
              l10n.seatsAvailable,
              style: context.text.labelMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            VGap.md,
            Center(
              child: CounterStepper(
                value: draft.totalSeats,
                min: AppRules.minSeatsPerRide,
                max: AppRules.maxSeatsPerRide,
                semanticLabel: l10n.seatsAvailable,
                onChanged: (value) =>
                    bloc.add(PublishRideFieldChanged(totalSeats: value)),
              ),
            ),

            VGap.xxl,
            AppTextField(
              controller: _priceController,
              label: l10n.pricePerSeat,
              hint: l10n.priceHint,
              isRequired: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              errorText: state.errorFor('price_per_seat'),
              suffix: Padding(
                padding: const EdgeInsets.only(right: Gap.lg),
                child: Text(
                  l10n.currency,
                  style: context.text.labelLarge?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              onChanged: (value) => bloc.add(
                PublishRideFieldChanged(
                  pricePerSeat: double.tryParse(value.replaceAll(',', '.')),
                ),
              ),
            ),
            if (suggested != null) ...[
              VGap.sm,
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 15,
                    color: palette.textTertiary,
                  ),
                  HGap.sm,
                  Expanded(
                    child: Text(
                      '${l10n.pricePerSeat}: ≈ ${fmt.price(suggested)}',
                      style: context.text.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _priceController.text = _money(suggested);
                      bloc.add(
                        PublishRideFieldChanged(pricePerSeat: suggested),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.apply),
                  ),
                ],
              ),
            ],

            // ------------------------------------------------- earnings
            // The whole motivation, in one line. A driver who never sees the
            // number does not feel it: the trip is happening either way, the
            // seats are empty either way, and we take no commission on
            // filling them.
            if (draft.pricePerSeat != null) ...[
              VGap.lg,
              _EarningsCard(
                seats: draft.totalSeats,
                pricePerSeat: draft.pricePerSeat!,
                fuelEstimate: _suggestion?.fuelEstimate,
              ),
            ],

            VGap.xl,
            AppTextField(
              controller: _pickupController,
              label: l10n.pickupPoint,
              hint: l10n.pickupPointHint,
              prefixIcon: Icons.my_location_rounded,
              maxLength: AppRules.maxPointLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) =>
                  bloc.add(PublishRideFieldChanged(pickupPoint: value)),
            ),

            VGap.xl,
            AppTextField(
              controller: _dropoffController,
              label: l10n.dropoffPoint,
              hint: l10n.dropoffPointHint,
              prefixIcon: Icons.place_outlined,
              maxLength: AppRules.maxPointLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) =>
                  bloc.add(PublishRideFieldChanged(dropoffPoint: value)),
            ),

            VGap.xl,
            AppTextField(
              controller: _noteController,
              label: l10n.rideNote,
              hint: l10n.rideNoteHint,
              maxLines: 4,
              minLines: 3,
              maxLength: AppRules.maxNoteLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) =>
                  bloc.add(PublishRideFieldChanged(note: value)),
            ),

            VGap.xl,
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.sm,
              ),
              child: SwitchListTile.adaptive(
                value: draft.instantBooking,
                onChanged: (value) =>
                    bloc.add(PublishRideFieldChanged(instantBooking: value)),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.instantBooking,
                  style: context.text.titleSmall,
                ),
                subtitle: Text(
                  l10n.instantBookingDesc,
                  style: context.text.bodySmall,
                ),
              ),
            ),

            // ----------------------------------------------- women only
            // Offered only to a woman driver: the server refuses it for
            // anyone else (API.md §21), and a switch that produces a 422 is
            // worse than no switch at all.
            if (isWomanDriver) ...[
              VGap.md,
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.sm,
                ),
                child: SwitchListTile.adaptive(
                  value: draft.womenOnly,
                  onChanged: (value) =>
                      bloc.add(PublishRideFieldChanged(womenOnly: value)),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.womenOnly, style: context.text.titleSmall),
                  subtitle: Text(
                    l10n.womenOnlyHint,
                    style: context.text.bodySmall,
                  ),
                ),
              ),
            ],

            // -------------------------------------------- weekly repeat
            // The weekly commuter is the driver worth keeping, and making
            // them refill this form every Friday is how they are lost.
            // Hidden while editing: changing one listing must never fan out
            // into eight.
            if (!widget.isEditing) ...[
              VGap.xl,
              Text(l10n.repeatWeeks, style: context.text.labelLarge),
              VGap.sm,
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final weeks in const [1, 2, 4, 8])
                    ChoiceChip(
                      label: Text(l10n.repeatWeeksLabel(weeks)),
                      selected: draft.repeatWeeks == weeks,
                      onSelected: (_) =>
                          bloc.add(PublishRideFieldChanged(repeatWeeks: weeks)),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// "3 × 15 ₼ = 45 ₼", with the fuel it offsets underneath.
///
/// Deliberately not framed as income. The honest pitch is that the cost of a
/// trip already being made gets shared — which is also why the no-commission
/// line sits right here, where the driver is looking at the number.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.seats,
    required this.pricePerSeat,
    this.fuelEstimate,
  });

  final int seats;
  final double pricePerSeat;
  final double? fuelEstimate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final total = pricePerSeat * seats;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, color: context.colors.primary),
              HGap.md,
              Expanded(
                child: Text(l10n.earningsTitle, style: context.text.titleSmall),
              ),
              Text(
                fmt.price(total),
                style: context.text.titleMedium?.copyWith(
                  color: context.colors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          VGap.sm,
          Text(
            l10n.earningsLine(seats, fmt.price(pricePerSeat), fmt.price(total)),
            style: context.text.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (fuelEstimate != null) ...[
            VGap.xs,
            Text(
              '${l10n.earningsFuelNote}: ≈ ${fmt.price(fuelEstimate!)}',
              style: context.text.bodySmall?.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ],
          VGap.sm,
          Text(
            l10n.earningsFree,
            style: context.text.labelMedium?.copyWith(color: palette.success),
          ),
        ],
      ),
    );
  }
}
