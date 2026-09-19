import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/bloc/data_status.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import '../../../domain/entities/report.dart';
import '../../../domain/repositories/report_repository.dart';

part 'report_event.dart';
part 'report_state.dart';

/// `POST /reports` — the "report this user" sheet (API.md §15).
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc({required ReportRepository reports})
    : _reports = reports,
      super(const ReportState()) {
    on<ReportStarted>(_onStarted);
    on<ReportReasonSelected>(_onReasonSelected);
    on<ReportDetailsChanged>(_onDetailsChanged);
    on<ReportSubmitted>(_onSubmitted);
    on<ReportFailureCleared>(_onFailureCleared);
  }

  final ReportRepository _reports;

  void _onStarted(ReportStarted event, Emitter<ReportState> emit) {
    emit(
      ReportState(
        draft: ReportDraft(
          targetUserId: event.targetUserId,
          rideId: event.rideId,
          bookingId: event.bookingId,
        ),
      ),
    );
  }

  void _onReasonSelected(
    ReportReasonSelected event,
    Emitter<ReportState> emit,
  ) {
    emit(
      state.copyWith(
        draft: state.draft?.copyWith(reason: event.reason),
        failure: () => null,
      ),
    );
  }

  void _onDetailsChanged(
    ReportDetailsChanged event,
    Emitter<ReportState> emit,
  ) {
    emit(
      state.copyWith(
        draft: state.draft?.copyWith(details: event.details),
        failure: () => null,
      ),
    );
  }

  Future<void> _onSubmitted(
    ReportSubmitted event,
    Emitter<ReportState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null || !draft.isValid || state.status.isBusy) return;

    emit(state.copyWith(status: ActionStatus.inProgress, failure: () => null));

    final result = await _reports.submit(draft);
    switch (result) {
      case Ok():
        emit(state.copyWith(status: ActionStatus.success));
      case Err(:final failure):
        emit(
          state.copyWith(status: ActionStatus.failure, failure: () => failure),
        );
    }
  }

  void _onFailureCleared(
    ReportFailureCleared event,
    Emitter<ReportState> emit,
  ) {
    emit(state.copyWith(failure: () => null, status: ActionStatus.idle));
  }
}
