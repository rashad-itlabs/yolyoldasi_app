import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/driver_repository.dart';
import '../bloc/driver_profile/driver_profile_bloc.dart';
import '../bloc/vehicles/vehicles_bloc.dart';

/// The car a driver offers seats in — `/vehicles` (API.md §8).
///
/// The first car created is what gives the account a driver profile, so this
/// is the entry point into driver mode.
class VehiclePage extends StatelessWidget {
  const VehiclePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VehiclesBloc>(
      create: (context) =>
          VehiclesBloc(drivers: context.read<DriverRepository>())
            ..add(const VehiclesRequested()),
      child: const _VehicleView(),
    );
  }
}

class _VehicleView extends StatelessWidget {
  const _VehicleView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<VehiclesBloc, VehiclesState>(
      listenWhen: (previous, current) =>
          previous.saveStatus != current.saveStatus ||
          previous.deleteStatus != current.deleteStatus ||
          previous.status != current.status,
      listener: (context, state) {
        if (state.saveStatus.isSuccess) {
          AppFeedback.success(context, l10n.vehicleSaved);
          // The first car flips `has_driver_profile` and creates the driver
          // profile, so both the session and that profile are now stale.
          context.read<SessionBloc>().add(const SessionRefreshed());
          context.read<DriverProfileBloc>().add(
            const DriverProfileRequested(force: true),
          );
          return;
        }

        final failure = state.failure;
        if (failure != null &&
            (state.saveStatus.isFailure || state.deleteStatus.isFailure)) {
          // Deleting a car an active ride still uses is a 422, and the
          // server's message says which ride.
          AppFeedback.error(context, failure.message(l10n));
        }
      },
      builder: (context, state) {
        if (state.status.isFirstLoad) {
          return AppScaffold(
            title: l10n.vehicleInfo,
            body: const LoadingState(),
          );
        }

        // The form opens straight away on the driver's car, or on a blank one
        // when they have none — a list of one is not worth a screen.
        return _VehicleForm(key: ValueKey(state.primary?.id), state: state);
      },
    );
  }
}

class _VehicleForm extends StatefulWidget {
  const _VehicleForm({super.key, required this.state});

  final VehiclesState state;

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _plate;
  late final TextEditingController _year;

  String? _brandError;
  String? _modelError;
  String? _plateError;
  String? _yearError;

  Vehicle get _vehicle => widget.state.primary ?? Vehicle.blank;

  @override
  void initState() {
    super.initState();
    final vehicle = _vehicle;
    _brand = TextEditingController(text: vehicle.brand);
    _model = TextEditingController(text: vehicle.model);
    _plate = TextEditingController(text: vehicle.plate ?? '');
    _year = TextEditingController(text: vehicle.year?.toString() ?? '');

    // Seeds the bloc's draft from the loaded car, so the colour and seat
    // controls below have something to bind to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VehiclesBloc>().add(VehicleEditStarted(vehicle));
      }
    });
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _plate.dispose();
    _year.dispose();
    super.dispose();
  }

  String? _msg(String? key) => key == null ? null : context.l10n.byKey(key);

  void _save() {
    setState(() {
      _brandError = _msg(Validators.required(_brand.text));
      _modelError = _msg(Validators.required(_model.text));
      // `plate` and `year` are optional on the API, so only a malformed value
      // is rejected here.
      _plateError = _msg(Validators.plate(_plate.text));
      _yearError = _msg(Validators.vehicleYear(_year.text));
    });
    if ([
      _brandError,
      _modelError,
      _plateError,
      _yearError,
    ].any((e) => e != null)) {
      return;
    }

    context.hideKeyboard();
    final bloc = context.read<VehiclesBloc>();
    bloc.add(
      VehicleFieldChanged(
        brand: _brand.text.trim(),
        model: _model.text.trim(),
        plate: Validators.normalizePlate(_plate.text),
        year: int.tryParse(_year.text.trim()),
      ),
    );
    bloc.add(const VehicleSubmitted());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final code = l10n.languageCode;

    return BlocBuilder<VehiclesBloc, VehiclesState>(
      builder: (context, state) {
        final bloc = context.read<VehiclesBloc>();
        final draft = state.draft ?? _vehicle;

        return DismissKeyboard(
          child: AppScaffold(
            title: l10n.vehicleInfo,
            actions: [
              if (draft.isPersisted)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: palette.danger,
                  ),
                  tooltip: l10n.delete,
                  onPressed: state.deleteStatus.isInProgress
                      ? null
                      : () => _confirmDelete(context, draft.id),
                ),
            ],
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.xxxl,
              ),
              children: [
                AppTextField(
                  controller: _brand,
                  label: l10n.vehicleBrand,
                  hint: l10n.vehicleBrandHint,
                  isRequired: true,
                  maxLength: 255,
                  errorText: _brandError ?? state.errorFor('brand'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (value) {
                    setState(() => _brandError = null);
                    bloc.add(VehicleFieldChanged(brand: value));
                  },
                ),
                VGap.lg,
                AppTextField(
                  controller: _model,
                  label: l10n.vehicleModel,
                  hint: l10n.vehicleModelHint,
                  isRequired: true,
                  maxLength: 255,
                  errorText: _modelError ?? state.errorFor('model'),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  onChanged: (value) {
                    setState(() => _modelError = null);
                    bloc.add(VehicleFieldChanged(model: value));
                  },
                ),
                VGap.lg,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: _plate,
                        label: l10n.vehiclePlate,
                        hint: l10n.vehiclePlateHint,
                        isRequired: false,
                        errorText: _plateError ?? state.errorFor('plate'),
                        inputFormatters: [PlateInputFormatter()],
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          setState(() => _plateError = null);
                          bloc.add(VehicleFieldChanged(plate: value));
                        },
                      ),
                    ),
                    HGap.md,
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _year,
                        label: l10n.vehicleYear,
                        hint: '2020',
                        isRequired: false,
                        errorText: _yearError ?? state.errorFor('year'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          setState(() => _yearError = null);
                          bloc.add(
                            VehicleFieldChanged(year: int.tryParse(value)),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                VGap.sm,
                Text(
                  l10n.plateVisibleToYou,
                  style: context.text.labelSmall?.copyWith(
                    color: palette.textTertiary,
                  ),
                ),

                VGap.xl,
                Text(
                  l10n.vehicleColor,
                  style: context.text.labelMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                VGap.md,
                Wrap(
                  spacing: Gap.md,
                  runSpacing: Gap.md,
                  children: [
                    for (final key in VehicleColors.keys)
                      _ColorSwatch(
                        colorKey: key,
                        label: VehicleColors.nameFor(key, code),
                        selected: state.colorKey == key,
                        onTap: () =>
                            bloc.add(VehicleFieldChanged(colorKey: key)),
                      ),
                  ],
                ),

                VGap.xl,
                Text(
                  l10n.vehicleSeats,
                  style: context.text.labelMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                VGap.xs,
                Text(
                  l10n.seatsIncludeDriver,
                  style: context.text.bodySmall?.copyWith(
                    color: palette.textTertiary,
                  ),
                ),
                VGap.md,
                Center(
                  child: CounterStepper(
                    value: draft.seats,
                    min: AppRules.minVehicleSeats,
                    max: AppRules.maxVehicleSeats,
                    semanticLabel: l10n.vehicleSeats,
                    onChanged: (value) =>
                        bloc.add(VehicleFieldChanged(seats: value)),
                  ),
                ),
              ],
            ),
            bottomBar: BottomActionBar(
              child: AppButton(
                label: l10n.saveVehicle,
                isLoading: state.saveStatus.isBusy,
                onPressed: _save,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, int vehicleId) async {
    final l10n = context.l10n;
    final bloc = context.read<VehiclesBloc>();

    final confirmed = await AppFeedback.confirm(
      context,
      title: l10n.delete,
      message: l10n.deleteRideWithBookings,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (confirmed) bloc.add(VehicleDeleted(vehicleId));
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.colorKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String colorKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final swatch = Color(VehicleColors.swatches[colorKey]!);

    return Semantics(
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Motion.fast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: swatch,
                border: Border.all(
                  color: selected ? context.colors.primary : palette.border,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color:
                          ThemeData.estimateBrightnessForColor(swatch) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 54,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: selected
                      ? context.colors.primary
                      : palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
