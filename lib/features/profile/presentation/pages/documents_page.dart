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

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.isUploading,
    required this.locked,
  });

  final VerificationDocument document;
  final bool isUploading;
  final bool locked;

  /// Collects the front and, for the two-sided types, the back — then sends
  /// both in the single `POST /driver/documents` the API expects.
  Future<void> _upload(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<DriverProfileBloc>();

    final front = await PhotoPicker.pick(context);
    if (front == null || !context.mounted) return;

    UploadFile? back;
    if (document.needsBackSide) {
      final second = await PhotoPicker.pick(context);
      if (!context.mounted) return;
      if (second == null) {
        // Sending only one side of a two-sided document would be rejected, so
        // the upload is abandoned rather than half-sent.
        AppFeedback.error(context, l10n.docBackSideRequired);
        return;
      }
      back = UploadFile.fromExtension(
        bytes: second.bytes,
        extension: second.extension,
        baseName: '${document.type.apiValue}_back',
      );
    }

    bloc.add(
      DriverDocumentUploaded(
        type: document.type,
        file: UploadFile.fromExtension(
          bytes: front.bytes,
          extension: front.extension,
          baseName: '${document.type.apiValue}_front',
        ),
        backFile: back,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

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

          if (!locked) ...[
            VGap.lg,
            AppButton.secondary(
              label: document.isUploaded
                  ? l10n.changePhoto
                  : l10n.uploadDocument,
              icon: Icons.upload_file_rounded,
              size: AppButtonSize.compact,
              isLoading: isUploading,
              onPressed: () => _upload(context),
            ),
            if (document.needsBackSide) ...[
              VGap.sm,
              Text(
                l10n.docBothSides,
                style: context.text.labelSmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
