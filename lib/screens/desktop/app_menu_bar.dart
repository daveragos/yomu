import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../reading/widgets/reader_column.dart';
import 'desktop_sidebar.dart';

/// The macOS menu bar: the app menu, View (the four screens and reader
/// zoom, each with its shortcut) and Window.
///
/// Shortcuts in the menu bar work wherever keyboard focus is, and the menu
/// shows people which shortcuts exist. Edit is left to Flutter, which
/// handles copy and paste in text itself. Other platforms get [child] as is.
class YomuMenuBar extends StatelessWidget {
  final List<SidebarDestination> destinations;
  final ValueChanged<int> onShowScreen;
  final Widget child;

  const YomuMenuBar({
    super.key,
    required this.destinations,
    required this.onShowScreen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return child;

    return PlatformMenuBar(
      menus: [
        const PlatformMenu(
          label: 'Yomu',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.about,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItemGroup(
              members: [
                for (var i = 0; i < destinations.length; i++)
                  PlatformMenuItem(
                    label: destinations[i].label,
                    shortcut: SingleActivator(
                      LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
                      meta: true,
                    ),
                    onSelected: () => onShowScreen(i),
                  ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Zoom In',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.equal,
                    meta: true,
                  ),
                  onSelected: () => ReaderCommands.current?.zoom(1),
                ),
                PlatformMenuItem(
                  label: 'Zoom Out',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.minus,
                    meta: true,
                  ),
                  onSelected: () => ReaderCommands.current?.zoom(-1),
                ),
                PlatformMenuItem(
                  label: 'Actual Size',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.digit0,
                    meta: true,
                  ),
                  onSelected: () => ReaderCommands.current?.resetZoom(),
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.toggleFullScreen,
                ),
              ],
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Window',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
