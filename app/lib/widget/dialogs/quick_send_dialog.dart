import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// A dialog that lists the nearby devices and pops with the picked one.
/// It is shown by the quick send hotkey.
class QuickSendDialog extends StatefulWidget {
  const QuickSendDialog();

  @override
  State<QuickSendDialog> createState() => _QuickSendDialogState();
}

class _QuickSendDialogState extends State<QuickSendDialog> with Refena {
  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(nearbyDevicesProvider.select((state) => state.allDevices.values.toList()));

    return AlertDialog(
      title: Text(t.dialogs.quickSendDialog.title),
      content: SizedBox(
        width: 400,
        child: devices.isEmpty
            ? Text(t.dialogs.quickSendDialog.noDevices)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final device in devices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DeviceListTile(
                          device: device,
                          onTap: () => context.pop(device),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.cancel),
        ),
      ],
    );
  }
}
