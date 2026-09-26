import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/upload_file.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/photo_picker.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/user_enums.dart';
import '../bloc/driver_profile/driver_profile_bloc.dart';

/// Driver verification — `GET /driver/profile` and `POST /driver/documents`
/// (API.md §7).
///
/// There is no separate "submit for review" call: the profile's status is
/// derived from the four documents, so uploading the last one is the
/// submission. Re-uploading a rejected document goes through the same endpoint
/// and puts it back to `pending`.
class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<DriverProfileBloc, DriverProfileState>(
      listenWhen: (previous, current) =>
          previous.uploadStatus != current.uploadStatus,
      listener: (context, state) {
        final failure = state.failure;
        if (state.uploadStatus.isFailure && failure != null) {
          AppFeedback.error(context, failure.message(l10n));
        } else if (state.uploadStatus.isSuccess) {
          AppFeedback.success(context, l10n.documentsSubmitted);
        }
      },
      builder: (context, state) {
        if (state.status.isFirstLoad) {
          return AppScaffold(
            title: l10n.documentsTitle,
            body: const LoadingState(),
          );
        }

        final profile = state.profileOrInitial;
        final status = profile.status;

        return AppScaffold(
          title: l10n.documentsTitle,
          body: RefreshIndicator(
            onRefresh: () async => context.read<DriverProfileBloc>().add(
              const DriverProfileRequested(force: true),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.lg,
                Gap.page,
                Gap.xxxl,
              ),
              children: [
                _StatusBanner(profile: profile),

                if (!profile.hasVehicle) ...[
                  VGap.lg,
                  AppCard(
                    onTap: () => context.push(Routes.vehicle),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          color: context.palette.textSecondary,
                        ),
                        HGap.lg,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.vehicleInfo,
                                style: context.text.titleSmall,
                              ),
                              Text(
                                l10n.noVehicle,
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.palette.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ],

                VGap.xl,
                for (final document in profile.documents) ...[
                  _DocumentTile(
                    // Keeps the photos picked so far attached to their
                    // document when the list rebuilds around them.
                    key: ValueKey(document.type),
                    document: document,
                    isUploading: state.isUploading(document.type),
                    // A document under review or already approved is not
                    // re-uploadable; a rejected one is, through the same call.
                    locked:
                        document.status.isPending || document.status.isApproved,
                  ),
                  VGap.md,
                ],

                VGap.lg,
                Text(
                  l10n.documentsNoPreview,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          bottomBar: status.isApproved
              ? null
              : BottomActionBar(
                  caption: Text(
                    l10n.documentsApprovedCount(
                      profile.uploadedDocumentCount,
                      AppRules.requiredDocumentCount,
                    ),
                    style: context.text.bodySmall,
                  ),
                  child: LinearProgressIndicator(
                    value: profile.completionFraction,
                    minHeight: 6,
                    borderRadius: Radii.pillAll,
                  ),
                ),
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = profile.status;

    if (status.isPending) {
      return InfoBanner(
        tone: BannerTone.info,
        icon: Icons.hourglass_top_rounded,
        title: l10n.verificationPending,
        message: l10n.verificationPendingBody,
      );
    }
    if (status.isApproved) {
      return InfoBanner(
        tone: BannerTone.success,
        icon: Icons.verified_rounded,
        title: l10n.verificationApproved,
        message: l10n.phoneVerified,
      );
    }
    if (status.isRejected) {
      // The per-document reason is more useful than the profile-level one, so
      // the rejected documents are named.
      final rejected = profile.rejectedDocuments
          .map((d) => d.rejectionReason)
          .whereType<String>()
          .join('\n');
      return InfoBanner(
        tone: BannerTone.danger,
        icon: Icons.report_gmailerrorred_rounded,
        title: l10n.verificationRejected,
        message: rejected.isNotEmpty
            ? rejected
            : profile.rejectionReason ?? l10n.verificationRejectedBody,
      );
    }
    return InfoBanner(
      tone: BannerTone.warning,
      icon: Icons.info_outline_rounded,
      message: l10n.documentsSubtitle,
    );
  }
}

/// One of the four documents: its status, and — while it can still be sent —
/// a slot per side to fill before sending.
///
/// The sides are picked one at a time and held here until both are in. The
/// first version opened the picker twice in a row with nothing to say which
/// side it wanted, so drivers photographed the front twice or backed out of
/// the second prompt and lost the first photo with it.
class _DocumentTile extends StatefulWidget {
  const _DocumentTile({
    super.key,
    required this.document,
    required this.isUploading,
    required this.locked,
  });

  final VerificationDocument document;
  final bool isUploading;
  final bool locked;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  /// What the document endpoint takes (API.md §7). Anything else is converted
  /// before it is held, so a slot only ever shows what will be sent.
  static const _accepted = {'jpg', 'png'};

  PickedPhoto? _front;
  PickedPhoto? _back;

  VerificationDocument get _document => widget.document;

  bool get _ready =>
      _front != null && (!_document.needsBackSide || _back != null);

  @override
  void didUpdateWidget(covariant _DocumentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new upload landed — the photos held here are the ones just sent.
    if (oldWidget.document.uploadedAt != _document.uploadedAt ||
        oldWidget.document.status != _document.status) {
      _front = null;
      _back = null;
    }
  }

  Future<void> _pick({required bool back}) async {
    final l10n = context.l10n;

    final picked = await PhotoPicker.pick(context);
    if (picked == null || !mounted) return;

    final photo = await PhotoPicker.ensureFormat(picked, accepted: _accepted);
    if (!mounted) return;
    if (photo == null) {
      AppFeedback.error(context, l10n.docUnsupportedFormat);
      return;
    }

    setState(() => back ? _back = photo : _front = photo);
  }

  void _send() {
    final front = _front;
    if (front == null) return;
    final back = _back;
    final type = _document.type.apiValue;

    context.read<DriverProfileBloc>().add(
      DriverDocumentUploaded(
        type: _document.type,
        file: UploadFile.fromExtension(
          bytes: front.bytes,
          extension: front.extension,
          baseName: '${type}_front',
        ),
        backFile: _document.needsBackSide && back != null
            ? UploadFile.fromExtension(
                bytes: back.bytes,
                extension: back.extension,
                baseName: '${type}_back',
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final document = _document;

    final (title, description) = switch (document.type) {
      DocumentType.idCard => (l10n.docIdCard, l10n.docIdCardDesc),
      DocumentType.driverLicense => (
        l10n.docDriverLicense,
        l10n.docDriverLicenseDesc,
      ),
      DocumentType.vehicleRegistration => (
        l10n.docVehicleRegistration,
        l10n.docVehicleRegistrationDesc,
      ),
      DocumentType.insurance => (l10n.docInsurance, l10n.docInsuranceDesc),
    };

    final (statusLabel, statusTone) = switch (document.status) {
      VerificationStatus.approved => (l10n.docStatusApproved, ChipTone.success),
      VerificationStatus.pending => (l10n.docStatusPending, ChipTone.warning),
      VerificationStatus.rejected => (l10n.docStatusRejected, ChipTone.danger),
      VerificationStatus.notUploaded => (
        l10n.docStatusNotUploaded,
        ChipTone.neutral,
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    VGap.xs,
                    Text(description, style: context.text.bodySmall),
                  ],
                ),
              ),
              HGap.md,
              StatusChip(label: statusLabel, tone: statusTone, dense: true),
            ],
          ),

          if (document.uploadedAt != null) ...[
            VGap.sm,
            Text(
              context.fmt.dayDotTime(document.uploadedAt!),
              style: context.text.labelSmall?.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ],

          if (document.rejectionReason != null) ...[
            VGap.md,
            Text(
              '${l10n.rejectionReason}: ${document.rejectionReason}',
              style: context.text.bodySmall?.copyWith(color: palette.danger),
            ),
          ],

          if (!widget.locked) ...[
            VGap.lg,
            Row(
              children: [
                Expanded(
                  child: _SideSlot(
                    label: document.needsBackSide
                        ? l10n.docFrontSide
                        : l10n.docPhoto,
                    photo: _front,
                    enabled: !widget.isUploading,
                    onTap: () => _pick(back: false),
                  ),
                ),
                if (document.needsBackSide) ...[
                  HGap.md,
                  Expanded(
                    child: _SideSlot(
                      label: l10n.docBackSide,
                      photo: _back,
                      enabled: !widget.isUploading,
                      onTap: () => _pick(back: true),
                    ),
                  ),
                ],
              ],
            ),
            if (document.needsBackSide && !_ready) ...[
              VGap.sm,
              Text(
                l10n.docBothSides,
                style: context.text.labelSmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ],
            VGap.md,
            AppButton(
              label: l10n.submitForReview,
              icon: Icons.upload_file_rounded,
              size: AppButtonSize.compact,
              isLoading: widget.isUploading,
              onPressed: _ready ? _send : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// One side of a document: an empty frame asking for a photo, or the photo
/// that will be sent, tappable to replace it.
class _SideSlot extends StatelessWidget {
  const _SideSlot({
    required this.label,
    required this.photo,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final PickedPhoto? photo;
  final bool enabled;
  final VoidCallback onTap;

  /// ID-1, the size of an ID card and a driving licence.
  static const double _cardRatio = 85.6 / 54;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final photo = this.photo;
    final hasPhoto = photo != null;

    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: enabled ? onTap : null,
        borderRadius: Radii.mdAll,
        child: AspectRatio(
          aspectRatio: _cardRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: Radii.mdAll,
              border: Border.all(
                color: hasPhoto ? palette.success : palette.borderStrong,
                width: hasPhoto ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: Radii.mdAll,
              child: hasPhoto
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          photo.bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                        Positioned(
                          top: Gap.xs,
                          right: Gap.xs,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: palette.success,
                            size: 22,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ColoredBox(
                            color: palette.overlay,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.sm,
                                vertical: Gap.xs,
                              ),
                              child: Text(
                                '$label · ${l10n.docTapToChange}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(Gap.sm),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: palette.textSecondary,
                          ),
                          VGap.xs,
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall,
                          ),
                          Text(
                            l10n.docAddPhoto,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
