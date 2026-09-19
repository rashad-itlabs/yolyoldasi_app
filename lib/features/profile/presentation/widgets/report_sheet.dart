import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../reports/domain/entities/report.dart';
import '../../../reports/domain/repositories/report_repository.dart';
import '../../../reports/presentation/bloc/report/report_bloc.dart';

/// Reports a user to the moderators — `POST /reports` (API.md §15).
class ReportSheet extends StatelessWidget {
  const ReportSheet({super.key});

  static Future<void> show(
    BuildContext context, {
    required int targetUserId,
    int? rideId,
    int? bookingId,
  }) {
    final reports = context.read<ReportRepository>();
    return AppFeedback.sheet<void>(
      context,
      builder: (_) => BlocProvider<ReportBloc>(
        create: (_) => ReportBloc(reports: reports)
          ..add(
            ReportStarted(
              targetUserId: targetUserId,
              rideId: rideId,
              bookingId: bookingId,
            ),
          ),
        child: const ReportSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = l10n.languageCode;

    return BlocConsumer<ReportBloc, ReportState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status.isSuccess) {
          Navigator.of(context).pop();
          AppFeedback.success(context, l10n.reportSubmitted);
          return;
        }
        final failure = state.failure;
        if (state.status.isFailure && failure != null) {
          AppFeedback.error(context, failure.message(l10n));
        }
      },
      builder: (context, state) {
        final bloc = context.read<ReportBloc>();

        return SheetScaffold(
          title: l10n.reportUser,
          subtitle: l10n.reportReason,
          action: AppButton.danger(
            label: l10n.reportUser,
            isLoading: state.status.isBusy,
            onPressed: state.canSubmit
                ? () => bloc.add(const ReportSubmitted())
                : null,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in ReportReason.values) ...[
                  SelectableTile(
                    title: reason.label(code),
                    selected: state.reason == reason,
                    onTap: () => bloc.add(ReportReasonSelected(reason)),
                  ),
                  VGap.sm,
                ],
                VGap.md,
                AppTextField(
                  label: l10n.about,
                  hint: l10n.writeCommentHint,
                  // API.md §15: `details` is required once the reason is
                  // "other", and optional otherwise.
                  isRequired: state.needsDetails,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: AppRules.maxReportDetailsLength,
                  errorText: state.detailsError == null
                      ? null
                      : l10n.byKey(state.detailsError!),
                  onChanged: (value) => bloc.add(ReportDetailsChanged(value)),
                ),
                VGap.md,
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on ReportState {
  /// The only field-level error the sheet can show: a missing explanation for
  /// the "other" reason.
  String? get detailsError =>
      needsDetails && details.trim().isEmpty && status.isFailure
      ? 'fieldRequired'
      : null;
}
