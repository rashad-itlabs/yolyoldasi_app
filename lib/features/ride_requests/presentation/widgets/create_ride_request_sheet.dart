import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../../../cities/presentation/bloc/cities_bloc.dart';
import '../../../rides/presentation/widgets/city_picker_sheet.dart';
import '../../domain/entities/ride_request.dart';

/// "Tell drivers what you need."
///
/// Opened from the empty search result — the moment this whole feature exists
/// for. Until now a passenger who found nothing had nothing to do but leave;
/// the sheet turns that dead end into demand a driver can answer.
///
/// It is deliberately short. The passenger has already typed a route and a date
/// into the search form, so both arrive pre-filled and the only real decision
/// left is how flexible the date is.
class CreateRideRequestSheet extends StatefulWidget {
  const CreateRideRequestSheet({super.key, required this.initial});

  final RideRequestDraft initial;

  /// Returns the completed draft, or null if the passenger backed out.
  static Future<RideRequestDraft?> show(
    BuildContext context, {
    required RideRequestDraft initial,
  }) {
    // Opened on its own route, so the cities bloc has to be handed down rather
    // than inherited — same as `CityPickerSheet.show`.
    final cities = context.read<CitiesBloc>();

    return AppFeedback.sheet<RideRequestDraft>(
      context,
      builder: (_) => BlocProvider<CitiesBloc>.value(
        value: cities,
        child: CreateRideRequestSheet(initial: initial),
      ),
    );
  }

  @override
  State<CreateRideRequestSheet> createState() => _CreateRideRequestSheetState();
}

class _CreateRideRequestSheetState extends State<CreateRideRequestSheet> {
  late RideRequestDraft _draft = widget.initial;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _note.text = widget.initial.note;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickCity({required bool isOrigin}) async {
    final l10n = context.l10n;
    final city = await CityPickerSheet.show(
      context,
      title: isOrigin ? l10n.from : l10n.to,
      excludeCityId: isOrigin ? _draft.toCityId : _draft.fromCityId,
      selectedCityId: isOrigin ? _draft.fromCityId : _draft.toCityId,
    );
    if (city == null) return;

    setState(() {
      _draft = isOrigin
          ? _draft.copyWith(fromCityId: () => city.id)
          : _draft.copyWith(toCityId: () => city.id);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.wantedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      // The same horizon the search form and the publish form use.
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _draft = _draft.copyWith(wantedDate: () => picked));
  }

  void _submit() {
    Navigator.of(context).pop(_draft.copyWith(note: _note.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    // Names come from the cached city list, the same source the search form
    // uses — `null` only while `/cities` is still in flight.
    final cities = context.read<CityRepository>();
    final code = l10n.languageCode;

    String cityName(int? id) => cities.byId(id)?.nameFor(code) ?? '—';

    return SheetScaffold(
      title: l10n.createRideRequestTitle,
      subtitle: l10n.createRideRequestBody,
      action: AppButton(
        label: l10n.createRideRequest,
        icon: Icons.campaign_outlined,
        onPressed: _draft.isComplete ? _submit : null,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: l10n.from,
                    value: cityName(_draft.fromCityId),
                    icon: Icons.trip_origin_rounded,
                    onTap: () => _pickCity(isOrigin: true),
                  ),
                ),
                HGap.md,
                Expanded(
                  child: _PickerField(
                    label: l10n.to,
                    value: cityName(_draft.toCityId),
                    icon: Icons.place_outlined,
                    onTap: () => _pickCity(isOrigin: false),
                  ),
                ),
              ],
            ),
            VGap.lg,

            _PickerField(
              label: l10n.wantedDate,
              value: _draft.wantedDate == null
                  ? '—'
                  : fmt.dayLabel(_draft.wantedDate!),
              icon: Icons.event_rounded,
              onTap: _pickDate,
            ),
            VGap.lg,

            // The setting that decides whether the request matches anything at
            // all. Defaulted to ±1 day rather than exact: for someone heading
            // to their home district Friday and Saturday are interchangeable,
            // and an exact date collapses the number of matches.
            Text(l10n.flexibleDays, style: context.text.labelLarge),
            VGap.sm,
            Wrap(
              spacing: Gap.sm,
              children: [
                for (final days in const [0, 1, 2, 3])
                  ChoiceChip(
                    label: Text(l10n.flexibleDaysLabel(days)),
                    selected: _draft.flexibleDays == days,
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(flexibleDays: days)),
                  ),
              ],
            ),
            VGap.lg,

            Text(l10n.howManySeats, style: context.text.labelLarge),
            VGap.sm,
            Wrap(
              spacing: Gap.sm,
              children: [
                for (var count = 1; count <= AppRules.maxSeatsPerRide; count++)
                  ChoiceChip(
                    label: Text('$count'),
                    selected: _draft.seats == count,
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(seats: count)),
                  ),
              ],
            ),
            VGap.lg,

            AppTextField(
              controller: _note,
              label: l10n.rideNote,
              hint: l10n.requestNoteHint,
              maxLines: 3,
              minLines: 2,
              maxLength: AppRules.maxRequestNoteLength,
            ),
            VGap.md,
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens a picker. Same shape as the search form's, so
/// the two read as one family.
///
/// Stateful only to own its controller: building one inside `build` would hand
/// out a fresh, undisposed object on every rebuild, and the sheet rebuilds on
/// every chip tap.
class _PickerField extends StatefulWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PickerField> createState() => _PickerFieldState();
}

class _PickerFieldState extends State<_PickerField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_PickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      readOnly: true,
      onTap: widget.onTap,
      prefixIcon: widget.icon,
      controller: _controller,
    );
  }
}
