import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/ride.dart';
import 'ride_share_card.dart';

enum _ShareFormat { image, link }

/// Previews the [RideShareCard] and offers the two ways a ride leaves the app.
///
/// Both stay because they are good at different things: a link is what a
/// WhatsApp or Telegram group needs, and Instagram will not take anything but
/// an image into a post.
class RideShareSheet extends StatefulWidget {
  const RideShareSheet({super.key, required this.ride});

  final Ride ride;

  /// Starts sharing [ride]. Pass the share button's own [context]: an iPad
  /// hangs the system's popover off that button.
  static Future<void> show(BuildContext context, Ride ride) async {
    // A picture is an advert with no way to correct itself, so a ride that can
    // no longer be booked only goes out as a link, whose page shows its status.
    if (!ride.status.isActive || ride.hasDeparted) {
      try {
        await _shareLink(context, ride, _originOf(context));
      } on Exception {
        if (context.mounted) {
          AppFeedback.error(context, context.l10n.shareFailed);
        }
      }
      return;
    }

    // The snackbar would land behind the sheet, so the sheet reports a failure
    // back here and closes.
    final failed = await AppFeedback.sheet<bool>(
      context,
      builder: (_) => RideShareSheet(ride: ride),
    );
    if (failed == true && context.mounted) {
      AppFeedback.error(context, context.l10n.shareFailed);
    }
  }

  static Future<ShareResult> _shareLink(
    BuildContext context,
    Ride ride,
    Rect? origin,
  ) {
    _logShared(context, ride, _ShareFormat.link);
    return SharePlus.instance.share(
      ShareParams(
        text: _describe(
          context,
          ride,
          when: context.fmt.dayLabelWithTime(ride.departureAt),
        ),
        sharePositionOrigin: origin,
      ),
    );
  }

  static void _logShared(BuildContext context, Ride ride, _ShareFormat format) {
    context.read<Analytics>().log(
      Ev.rideShared,
      params: {
        'ride_id': ride.id,
        'is_mine': ride.isMine,
        'format': format.name,
      },
    );
  }

  /// The route, the time and the price, so the message reads on its own in a
  /// group chat — a bare link is scrolled past.
  static String _describe(
    BuildContext context,
    Ride ride, {
    required String when,
  }) {
    final l10n = context.l10n;
    final code = l10n.languageCode;
    return '${ride.fromCity.nameFor(code)} → ${ride.toCity.nameFor(code)}\n'
        '$when · ${context.fmt.price(ride.pricePerSeat)} ${l10n.perSeat}\n'
        '${ride.shareUrl}';
  }

  /// Where [context] sits on screen. An iPad refuses to share without this;
  /// a phone ignores it.
  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  @override
  State<RideShareSheet> createState() => _RideShareSheetState();
}

class _RideShareSheetState extends State<RideShareSheet> {
  final _cardKey = GlobalKey();

  _ShareFormat? _active;

  /// Built once, so tapping a button cannot repaint the card while it is being
  /// captured.
  late final Widget _card = RepaintBoundary(
    key: _cardKey,
    child: RideShareCard(ride: widget.ride),
  );

  Future<void> _share(_ShareFormat format) async {
    setState(() => _active = format);
    try {
      final result = await switch (format) {
        _ShareFormat.image => _shareImage(),
        _ShareFormat.link => RideShareSheet._shareLink(
          context,
          widget.ride,
          RideShareSheet._originOf(_cardKey.currentContext!),
        ),
      };
      if (!mounted) return;
      // Backing out of the system's picker returns here, so the other format
      // is still one tap away.
      if (result.status == ShareResultStatus.dismissed) {
        setState(() => _active = null);
      } else {
        Navigator.of(context).pop();
      }
    } on Exception {
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  /// Instagram takes the picture and drops any text sent with it, and a caption
  /// cannot be filled in from outside. The clipboard is the only way left to
  /// spare the driver from typing the details again. The sheet says this will
  /// happen before the button is tapped.
  Future<ShareResult> _shareImage() async {
    final ride = widget.ride;
    final origin = RideShareSheet._originOf(_cardKey.currentContext!);
    final caption = RideShareSheet._describe(
      context,
      ride,
      when: context.fmt.dayMonthWithTime(ride.departureAt),
    );
    RideShareSheet._logShared(context, ride, _ShareFormat.image);

    final png = await _renderCard();
    await Clipboard.setData(ClipboardData(text: caption));

    return SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['yol-yoldasi-${ride.id}.png'],
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<Uint8List> _renderCard() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: RideShareCard.pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('The ride card could not be encoded');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isIdle = _active == null;

    return SheetScaffold(
      title: l10n.shareRide,
      subtitle: l10n.shareImageHint,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: l10n.shareAsImage,
            icon: Icons.image_outlined,
            isLoading: _active == _ShareFormat.image,
            onPressed: isIdle ? () => _share(_ShareFormat.image) : null,
          ),
          VGap.md,
          AppButton.secondary(
            label: l10n.shareAsLink,
            icon: Icons.link_rounded,
            isLoading: _active == _ShareFormat.link,
            onPressed: isIdle ? () => _share(_ShareFormat.link) : null,
          ),
        ],
      ),
      // The preview gives up height first, so the buttons stay on screen on
      // the shortest phones.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.screenHeight * 0.5),
            child: AspectRatio(
              aspectRatio: RideShareCard.size.aspectRatio,
              child: ClipRRect(
                borderRadius: Radii.mdAll,
                child: FittedBox(child: _card),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
