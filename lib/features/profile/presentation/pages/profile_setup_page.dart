import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/upload_file.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/photo_picker.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../rides/presentation/widgets/city_picker_sheet.dart';
import '../../domain/entities/user_enums.dart';
import '../../domain/repositories/user_repository.dart';
import '../bloc/profile_form/profile_form_bloc.dart';

/// Collected right after the first sign-in: name, photo and a short bio.
///
/// Only the name is mandatory — `POST /auth/firebase` makes `full_name`
/// optional, so this is where a new account gets one, through `PATCH /me`.
class ProfileSetupPage extends StatelessWidget {
  const ProfileSetupPage({super.key, this.isEditing = false});

  /// When `true` the page is reached from the profile tab instead of the
  /// sign-up flow: it gets a back button and a different title.
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final user = context.read<SessionBloc>().state.user;

    return BlocProvider<ProfileFormBloc>(
      create: (context) =>
          ProfileFormBloc(users: context.read<UserRepository>())
            ..add(ProfileFormStarted(user)),
      child: _ProfileSetupView(isEditing: isEditing),
    );
  }
}

class _ProfileSetupView extends StatefulWidget {
  const _ProfileSetupView({required this.isEditing});

  final bool isEditing;

  @override
  State<_ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<_ProfileSetupView> {
  late final TextEditingController _nameController;
  late final TextEditingController _aboutController;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProfileFormBloc>().state;
    _nameController = TextEditingController(text: state.fullName);
    _aboutController = TextEditingController(text: state.about);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final bloc = context.read<ProfileFormBloc>();
    final photo = await PhotoPicker.pick(context);
    if (photo == null) return;

    bloc.add(
      ProfilePhotoPicked(
        UploadFile.fromExtension(
          bytes: photo.bytes,
          extension: photo.extension,
          baseName: 'avatar',
        ),
      ),
    );
  }

  Future<void> _pickCity(City? current) async {
    final bloc = context.read<ProfileFormBloc>();
    final city = await CityPickerSheet.show(
      context,
      title: context.l10n.city,
      selectedCityId: current?.id,
    );
    if (city != null) bloc.add(ProfileCityChanged(city));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return BlocConsumer<ProfileFormBloc, ProfileFormState>(
      listenWhen: (previous, current) =>
          previous.savedUser != current.savedUser ||
          previous.status != current.status ||
          previous.photoStatus != current.photoStatus,
      listener: (context, state) {
        // Whoever saved it — the PATCH or the photo upload — the session owns
        // the user, so the fresh copy is handed straight to it.
        final saved = state.savedUser;
        if (saved != null) {
          context.read<SessionBloc>().add(SessionUserUpdated(saved));
        }

        if (state.status.isSuccess) {
          AppFeedback.success(context, l10n.profileSaved);
          // On first-run setup the router redirects on its own once the
          // profile is complete; an edit has somewhere to go back to.
          if (widget.isEditing) Navigator.of(context).maybePop();
          return;
        }

        final failure = state.failure;
        if ((state.status.isFailure || state.photoStatus.isFailure) &&
            failure != null) {
          AppFeedback.error(context, failure.message(l10n));
        }
      },
      builder: (context, state) {
        final bloc = context.read<ProfileFormBloc>();

        return DismissKeyboard(
          child: AppScaffold(
            title: widget.isEditing ? l10n.editProfile : null,
            showBackButton: widget.isEditing,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.xxl,
                Gap.page,
                Gap.xxxl,
              ),
              children: [
                if (!widget.isEditing) ...[
                  Text(
                    l10n.profileSetupTitle,
                    style: context.text.displaySmall,
                  ),
                  VGap.sm,
                  Text(
                    l10n.profileSetupSubtitle,
                    style: context.text.bodyLarge?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  VGap.xxxl,
                ],

                Center(
                  child: Stack(
                    children: [
                      AppAvatar(
                        name: state.fullName,
                        photoUrl: state.photoUrl,
                        size: Sizes.avatarXl,
                        onTap: state.photoStatus.isBusy ? null : _pickPhoto,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.surfaceElevated,
                          ),
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: context.colors.primary,
                            child: state.photoStatus.isBusy
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.onPrimary,
                                    ),
                                  )
                                : Icon(
                                    Icons.photo_camera_rounded,
                                    size: 15,
                                    color: context.colors.onPrimary,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                VGap.md,
                Center(
                  child: TextButton(
                    onPressed: state.photoStatus.isBusy ? null : _pickPhoto,
                    child: Text(
                      state.photoUrl == null ? l10n.addPhoto : l10n.changePhoto,
                    ),
                  ),
                ),

                VGap.xxl,
                AppTextField(
                  controller: _nameController,
                  label: l10n.fullName,
                  hint: l10n.fullNameHint,
                  isRequired: true,
                  maxLength: AppRules.maxFullNameLength,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  errorText: state.errorFor('full_name'),
                  autofillHints: const [AutofillHints.name],
                  onChanged: (value) => bloc.add(ProfileFullNameChanged(value)),
                ),

                VGap.xl,
                FieldLabel(text: l10n.gender),
                VGap.sm,
                // Chips rather than a segmented control: "Bildirmək istəmirəm"
                // is far longer than the other two and would be truncated in
                // an equal-width segment.
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final option in <(Gender, String)>[
                      (Gender.male, l10n.male),
                      (Gender.female, l10n.female),
                      (Gender.unspecified, l10n.genderUnspecified),
                    ])
                      ChoiceChip(
                        selected: state.gender == option.$1,
                        onSelected: (_) =>
                            bloc.add(ProfileGenderChanged(option.$1)),
                        label: Text(option.$2),
                      ),
                  ],
                ),

                VGap.xl,
                AppPickerField(
                  label: l10n.city,
                  icon: Icons.location_city_rounded,
                  isRequired: false,
                  value: state.city?.nameFor(l10n.languageCode),
                  placeholder: l10n.selectCity,
                  onTap: () => _pickCity(state.city),
                  trailing: state.city == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () =>
                              bloc.add(const ProfileCityChanged(null)),
                        ),
                ),

                VGap.xl,
                _BirthYearField(
                  value: state.birthYear,
                  onChanged: (year) => bloc.add(ProfileBirthYearChanged(year)),
                ),

                VGap.xl,
                AppTextField(
                  controller: _aboutController,
                  label: l10n.about,
                  hint: l10n.aboutHint,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: AppRules.maxAboutLength,
                  showCounter: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (value) => bloc.add(ProfileAboutChanged(value)),
                ),
              ],
            ),
            // Pinned, like every other form in the app: with the keyboard open
            // the primary action must not be somewhere below the fold.
            bottomBar: BottomActionBar(
              child: AppButton(
                label: widget.isEditing ? l10n.save : l10n.continueLabel,
                onPressed: state.canSubmit
                    ? () {
                        context.hideKeyboard();
                        bloc.add(const ProfileFormSubmitted());
                      }
                    : null,
                isLoading: state.status.isBusy,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `birth_year` is 1930 – (current year − 16) on the API, so the picker never
/// offers a year the server would reject.
class _BirthYearField extends StatelessWidget {
  const _BirthYearField({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppPickerField(
      label: l10n.birthYear,
      icon: Icons.cake_outlined,
      isRequired: false,
      value: value?.toString(),
      placeholder: l10n.optional,
      trailing: value == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final years = [
          for (var y = AppRules.maxBirthYear; y >= AppRules.minBirthYear; y--)
            y,
        ];
        final picked = await AppFeedback.sheet<int>(
          context,
          builder: (sheetContext) => SheetScaffold(
            title: l10n.birthYear,
            child: SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text('${years[index]}'),
                  selected: years[index] == value,
                  onTap: () => Navigator.of(sheetContext).pop(years[index]),
                ),
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
