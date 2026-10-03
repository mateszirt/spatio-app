import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/cleanliness_engine.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/top_snack_bar.dart';
import '../../domain/models/room.dart';
import '../../domain/models/task_item.dart';
import '../../domain/models/furniture_item.dart';
import '../controllers/household_state_provider.dart';
import '../controllers/supabase_sync_controller.dart';
import '../controllers/task_assignment_controller.dart';
import '../floor_plan/custom_floor_painter.dart';
import '../floor_plan/geometry_utils.dart';
import '../floor_plan/pending_task_coin.dart';
import '../floor_plan/furniture_catalog.dart';
import '../widgets/add_task_dialog.dart';
import '../../../../core/widgets/task_celebration_overlay.dart';
import '../../../../core/services/presence_service.dart';

enum FloorPlanMode {
  furniture, // Unified Furnish mode: Select/Inspect or Place Furniture
  draw,      // Draw Walls with Grid Snap
}

class FloorPlanScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final FloorPlanMode initialMode;

  const FloorPlanScreen({
    super.key,
    this.isEmbedded = false,
    this.initialMode = FloorPlanMode.furniture,
  });

  @override
  ConsumerState<FloorPlanScreen> createState() => FloorPlanScreenState();
}

class FloorPlanScreenState extends ConsumerState<FloorPlanScreen> {
  final TransformationController _transformationController =
      TransformationController();

  late FloorPlanMode _currentMode;
  bool _showGrid = true;
  Room? _selectedRoom;
  FurnitureItem? _selectedFurniture;

  // Floor management
  int _currentFloor = 1;
  final Set<int> _createdFloors = {1};

  // Active furniture selection from catalog (null when just inspecting/navigating)
  String? _selectedFurnitureCatalogItem;
  String _selectedFurnitureName = 'Washing Machine';
  String _selectedFurnitureCategory = 'laundry';
  String _selectedCatalogCategoryKey = 'all';
  double _furnitureWidth = 55.0;
  double _furnitureHeight = 55.0;
  double _furnitureRotation = 0.0;

  // Ghost placement preview
  Offset? _ghostPosition;
  Room? _ghostTargetRoom;
  bool _isGhostInsideRoom = false;
  bool _isGhostFixed = false;

  // Furniture placement undo stack
  final List<String> _placedFurnitureHistory = [];

  // Wall drawing points
  final List<Offset> _currentDrawingPoints = [];
  Offset? _previewPoint;

  static const double _canvasWidth = 1600.0;
  static const double _canvasHeight = 1200.0;
  double _gridSize = 20.0;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _transformationController.addListener(_onTransformChanged);
  }

  void setMode(FloorPlanMode mode) {
    if (mode == FloorPlanMode.draw) {
      final currentMember = ref.read(currentUserProvider);
      if (currentMember?.isChild == true) {
        showTopSnackBar(
          context,
          AppStrings.permissionDenied,
          isError: true,
        );
        return;
      }
    }
    setState(() {
      _currentMode = mode;
      _currentDrawingPoints.clear();
      _previewPoint = null;
      if (mode != FloorPlanMode.furniture) {
        _selectedFurnitureCatalogItem = null;
        _ghostPosition = null;
        _ghostTargetRoom = null;
        _isGhostFixed = false;
      }
    });
    if (mode == FloorPlanMode.draw) {
      ref.read(householdPresenceProvider.notifier).trackActivity(
            action: 'drawing_room',
            detail: 'Drawing room on Floor $_currentFloor',
            floor: _currentFloor,
          );
    } else {
      ref.read(householdPresenceProvider.notifier).trackActivity(
            action: 'idle',
            floor: _currentFloor,
          );
    }
  }

  void clearGhost() {
    setState(() {
      _selectedFurnitureCatalogItem = null;
      _ghostPosition = null;
      _ghostTargetRoom = null;
      _isGhostFixed = false;
    });
  }

  void _onTransformChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _resetTransform() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  /// Select furniture from catalog with preset dimensions
  void _selectFurniture(String name, String category) {
    final currentMember = ref.read(currentUserProvider);
    if (currentMember?.isChild == true) {
      showTopSnackBar(
        context,
        AppStrings.permissionDenied,
        isError: true,
      );
      return;
    }

    if (_selectedFurnitureCatalogItem == name) {
      // Toggle off / deselect
      setState(() {
        _selectedFurnitureCatalogItem = null;
        _ghostPosition = null;
        _ghostTargetRoom = null;
        _isGhostFixed = false;
      });
      ref.read(householdPresenceProvider.notifier).trackActivity(
            action: 'idle',
            floor: _currentFloor,
          );
      return;
    }

    final catalogType = FurnitureCatalog.byName(name);
    final double w = catalogType?.width ?? 55.0;
    final double h = catalogType?.height ?? 55.0;
    final String resolvedCategory = catalogType?.category ?? category;

    setState(() {
      _selectedFurnitureCatalogItem = name;
      _selectedFurnitureName = name;
      _selectedFurnitureCategory = resolvedCategory;
      _furnitureWidth = w;
      _furnitureHeight = h;
      _furnitureRotation = 0.0;
      _isGhostFixed = false;
      _selectedRoom = null;
      _selectedFurniture = null;
    });

    ref.read(householdPresenceProvider.notifier).trackActivity(
          action: 'placing_furniture',
          detail: 'Placing $name',
          floor: _currentFloor,
        );
  }

  void _updateGhostPosition(Offset localPos, List<Room> currentFloorRooms) {
    final scenePoint = _transformationController.toScene(localPos);
    final snapped = GeometryUtils.snapToGrid(scenePoint, gridSize: _gridSize);
    final hitRoom = GeometryUtils.findRoomAtPoint(snapped, currentFloorRooms);

    setState(() {
      _ghostPosition = snapped;
      _ghostTargetRoom = hitRoom;
      _isGhostInsideRoom = hitRoom != null;
    });

    if (hitRoom != null) {
      ref.read(householdPresenceProvider.notifier).trackActivity(
            action: 'placing_furniture',
            detail: 'Placing $_selectedFurnitureName in ${hitRoom.name}',
            roomId: hitRoom.id,
            floor: _currentFloor,
          );
    }
  }

  void _handleTapUp(
    TapUpDetails details,
    List<Room> currentFloorRooms,
    List<FurnitureItem> currentFloorFurniture,
    List<FurnitureItem> lowerFloorStairs,
  ) {
    final scenePoint = _transformationController.toScene(details.localPosition);

    // 1. PLACEMENT MODE ACTIVE
    if (_currentMode == FloorPlanMode.furniture && _selectedFurnitureCatalogItem != null) {
      _updateGhostPosition(details.localPosition, currentFloorRooms);
      setState(() {
        _isGhostFixed = true;
      });
      return;
    }

    // 2. NAVIGATE & SELECT MODE (Unified Furnish mode when no catalog item is selected)
    if (_currentMode == FloorPlanMode.furniture && _selectedFurnitureCatalogItem == null) {
      // 2.A: Stair arrival cutout from lower floor -> go down
      for (final stair in lowerFloorStairs) {
        final sx = (stair.positionCoordinates['x'] as num?)?.toDouble() ?? 0.0;
        final sy = (stair.positionCoordinates['y'] as num?)?.toDouble() ?? 0.0;
        final sw = (stair.positionCoordinates['width'] as num?)?.toDouble() ?? 75.0;
        final sh = (stair.positionCoordinates['height'] as num?)?.toDouble() ?? 110.0;
        final hitRect = Rect.fromCenter(center: Offset(sx, sy), width: sw + 16, height: sh + 16);

        if (hitRect.contains(scenePoint)) {
          final targetFloor = _currentFloor - 1;
          setState(() {
            _currentFloor = targetFloor;
            _selectedRoom = null;
            _selectedFurniture = null;
          });
          if (mounted) {
            showTopSnackBar(
              context,
              '🪜 Moved down to ${AppStrings.floorLabel(targetFloor)}!',
            );
          }
          return;
        }
      }

      // 2.B: Staircase on current floor -> go up
      for (final item in currentFloorFurniture) {
        final isStairs = item.category == 'stairs' ||
            item.name.toLowerCase().contains('lépcső') ||
            item.name.toLowerCase().contains('stairs');
        if (isStairs) {
          final fx = (item.positionCoordinates['x'] as num?)?.toDouble() ?? 0.0;
          final fy = (item.positionCoordinates['y'] as num?)?.toDouble() ?? 0.0;
          final fw = (item.positionCoordinates['width'] as num?)?.toDouble() ?? 75.0;
          final fh = (item.positionCoordinates['height'] as num?)?.toDouble() ?? 110.0;
          final hitRect = Rect.fromCenter(center: Offset(fx, fy), width: fw + 16, height: fh + 16);

          if (hitRect.contains(scenePoint)) {
            final targetFloor = (item.positionCoordinates['targetFloor'] as num?)?.toInt() ?? (_currentFloor + 1);
            _createdFloors.add(targetFloor);
            setState(() {
              _currentFloor = targetFloor;
              _selectedRoom = null;
              _selectedFurniture = null;
            });
            if (mounted) {
              showTopSnackBar(
                context,
                '🪜 Moved up to ${AppStrings.floorLabel(targetFloor)}!',
              );
            }
            return;
          }
        }
      }

      // 2.C: Other furniture click -> opens side panel
      FurnitureItem? hitFurniture;
      for (final item in currentFloorFurniture) {
        final fx = (item.positionCoordinates['x'] as num?)?.toDouble() ?? 0.0;
        final fy = (item.positionCoordinates['y'] as num?)?.toDouble() ?? 0.0;
        final fw = (item.positionCoordinates['width'] as num?)?.toDouble() ?? 50.0;
        final fh = (item.positionCoordinates['height'] as num?)?.toDouble() ?? 50.0;
        final hitRadius = (fw > fh ? fw : fh) / 2 + 8.0;

        if ((Offset(fx, fy) - scenePoint).distance <= hitRadius) {
          hitFurniture = item;
          break;
        }
      }

      if (hitFurniture != null) {
        final room = currentFloorRooms.cast<Room?>().firstWhere(
              (r) => r?.id == hitFurniture!.roomId,
              orElse: () => null,
            );
        setState(() {
          _selectedFurniture = hitFurniture;
          _selectedRoom = room;
        });
        return;
      }

      // 2.D: Room click -> opens side panel
      final hitRoom = GeometryUtils.findRoomAtPoint(scenePoint, currentFloorRooms);
      setState(() {
        _selectedRoom = hitRoom;
        _selectedFurniture = null;
      });
      if (hitRoom != null) {
        ref.read(householdPresenceProvider.notifier).trackActivity(
              action: 'viewing_room',
              detail: 'Inspecting ${hitRoom.name}',
              roomId: hitRoom.id,
              floor: _currentFloor,
            );
      }
    } else if (_currentMode == FloorPlanMode.draw) {
      // 3. DRAW WALLS: Snap to grid
      final snapped = GeometryUtils.snapToGrid(scenePoint, gridSize: _gridSize);

      setState(() {
        if (_currentDrawingPoints.length >= 3 &&
            (snapped - _currentDrawingPoints.first).distance <= _gridSize * 1.5) {
          _promptSaveNewRoom();
        } else {
          _currentDrawingPoints.add(snapped);
        }
      });
    }
  }

  void _handlePointerHover(PointerHoverEvent event, List<Room> currentFloorRooms) {
    if (_currentMode == FloorPlanMode.draw) {
      final scenePoint = _transformationController.toScene(event.localPosition);
      final snapped = GeometryUtils.snapToGrid(scenePoint, gridSize: _gridSize);
      if (_previewPoint != snapped) {
        setState(() {
          _previewPoint = snapped;
        });
      }
    } else if (_currentMode == FloorPlanMode.furniture && _selectedFurnitureCatalogItem != null) {
      if (!_isGhostFixed) {
        _updateGhostPosition(event.localPosition, currentFloorRooms);
      }
    }
  }

  /// Confirm furniture placement
  Future<void> _confirmPlaceFurniture() async {
    if (_ghostPosition == null || _ghostTargetRoom == null) {
      showTopSnackBar(
        context,
        AppStrings.placeInsideRoomWarning,
        isError: true,
      );
      return;
    }

    // Check collision / overlap with existing furniture on the current floor
    final rooms = ref.read(roomsRealtimeStreamProvider).value ?? [];
    final furnitureList = ref.read(furnitureRealtimeStreamProvider).value ?? [];
    final roomFloorMap = {for (final r in rooms) r.id: r.floor};
    final currentFloorFurniture = furnitureList.where((f) => roomFloorMap[f.roomId] == _currentFloor).toList();

    final isRotated90 = (_furnitureRotation % 180 != 0);
    final candW = isRotated90 ? _furnitureHeight : _furnitureWidth;
    final candH = isRotated90 ? _furnitureWidth : _furnitureHeight;
    final candRect = Rect.fromCenter(
      center: _ghostPosition!,
      width: candW - 4.0,
      height: candH - 4.0,
    );

    final hasOverlap = currentFloorFurniture.any((item) {
      final ix = (item.positionCoordinates['x'] as num?)?.toDouble() ?? 0.0;
      final iy = (item.positionCoordinates['y'] as num?)?.toDouble() ?? 0.0;
      final iw = (item.positionCoordinates['width'] as num?)?.toDouble() ?? 70.0;
      final ih = (item.positionCoordinates['height'] as num?)?.toDouble() ?? 70.0;
      final iRot = (item.positionCoordinates['rotation'] as num?)?.toInt() ?? 0;
      final iRotated = (iRot % 180 != 0);
      final effW = iRotated ? ih : iw;
      final effH = iRotated ? iw : ih;
      final itemRect = Rect.fromCenter(
        center: Offset(ix, iy),
        width: effW - 4.0,
        height: effH - 4.0,
      );
      return candRect.overlaps(itemRect);
    });

    if (hasOverlap) {
      showTopSnackBar(
        context,
        AppStrings.overlapWarning,
        isError: true,
      );
      return;
    }

    final furnitureId = generateUuid();
    final isStairs = _selectedFurnitureCategory == 'stairs' ||
        _selectedFurnitureName.toLowerCase().contains('lépcső') ||
        _selectedFurnitureName.toLowerCase().contains('stairs');
    final targetFloor = isStairs ? _currentFloor + 1 : null;

    final posCoords = <String, dynamic>{
      'x': _ghostPosition!.dx,
      'y': _ghostPosition!.dy,
      'width': _furnitureWidth,
      'height': _furnitureHeight,
      'rotation': _furnitureRotation,
    };
    if (targetFloor != null) {
      posCoords['targetFloor'] = targetFloor;
    }

    final newFurniture = FurnitureItem(
      id: furnitureId,
      roomId: _ghostTargetRoom!.id,
      name: _selectedFurnitureName,
      category: _selectedFurnitureCategory,
      positionCoordinates: posCoords,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(syncServiceProvider).saveFurnitureItem(newFurniture);
    _placedFurnitureHistory.add(furnitureId);

    if (isStairs) {
      _createdFloors.add(_currentFloor + 1);
      if (mounted) {
        showTopSnackBar(
          context,
          '${AppStrings.stairsPlaced} Accessible: ${AppStrings.floorLabel(_currentFloor + 1)}',
        );
      }
    } else {
      if (mounted) {
        showTopSnackBar(
          context,
          '✅ $_selectedFurnitureName ${AppStrings.furniturePlaced}',
        );
      }
    }

    setState(() {
      _selectedFurnitureCatalogItem = null;
      _ghostPosition = null;
      _ghostTargetRoom = null;
      _isGhostFixed = false;
    });

    ref.read(householdPresenceProvider.notifier).trackActivity(
          action: 'idle',
          floor: _currentFloor,
        );
  }

  /// Cancel and deselect furniture
  void _cancelPlaceFurniture() {
    setState(() {
      _selectedFurnitureCatalogItem = null;
      _ghostPosition = null;
      _ghostTargetRoom = null;
      _isGhostFixed = false;
    });

    ref.read(householdPresenceProvider.notifier).trackActivity(
          action: 'idle',
          floor: _currentFloor,
        );
  }

  /// Undo last placed furniture
  Future<void> _undoLastFurniture() async {
    if (_placedFurnitureHistory.isEmpty) return;
    final lastId = _placedFurnitureHistory.removeLast();
    await ref.read(supabaseSyncControllerProvider.notifier).deleteFurniture(lastId);
    if (mounted) {
      showTopSnackBar(context, AppStrings.furnitureUndone);
      setState(() {});
    }
  }

  /// Confirm floor deletion with staircase check
  void _confirmDeleteFloor(int floorToDelete, List<FurnitureItem> allFurniture) {
    final currentMember = ref.read(currentUserProvider);
    if (currentMember?.isChild == true) {
      showTopSnackBar(
        context,
        AppStrings.permissionDenied,
        isError: true,
      );
      return;
    }

    if (floorToDelete == 1) {
      showTopSnackBar(
        context,
        AppStrings.cannotDeleteGroundFloor,
        isError: true,
      );
      return;
    }

    // Check if any staircase connects to or starts from this floor
    final hasConnectingStairs = allFurniture.any((f) {
      final isStairs = f.category == 'stairs' ||
          f.name.toLowerCase().contains('lépcső') ||
          f.name.toLowerCase().contains('stairs');
      if (!isStairs) return false;
      final targetFloor = (f.positionCoordinates['targetFloor'] as num?)?.toInt();
      if (targetFloor == floorToDelete) return true;
      return false;
    });

    if (hasConnectingStairs) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(AppStrings.deleteFloor),
            ],
          ),
          content: const Text(AppStrings.cannotDeleteFloorWithStairs),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete ${AppStrings.floorLabel(floorToDelete)}?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${AppStrings.floorLabel(floorToDelete)}? All rooms and items on this level will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final roomsOnFloor = ref
                  .read(roomsRealtimeStreamProvider)
                  .value
                  ?.where((r) => r.floor == floorToDelete)
                  .toList() ?? [];
              for (final room in roomsOnFloor) {
                await ref.read(supabaseSyncControllerProvider.notifier).deleteRoom(room.id);
              }
              setState(() {
                _createdFloors.remove(floorToDelete);
                _currentFloor = 1;
                _selectedRoom = null;
                _selectedFurniture = null;
              });
              if (mounted) {
                showTopSnackBar(
                  context,
                  AppStrings.floorDeleted,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show Grid Snap selector dialog
  void _showSnapSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.straighten, color: Color(0xFF00897B)),
              SizedBox(width: 8),
              Text(AppStrings.gridSnapTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select grid snapping resolution:'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _snapChoice(ctx, 'Off (1 px)', 1.0),
                  _snapChoice(ctx, '10 px', 10.0),
                  _snapChoice(ctx, '20 px', 20.0),
                  _snapChoice(ctx, '50 px', 50.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _snapChoice(BuildContext ctx, String label, double value) {
    final isSel = _gridSize == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: const Color(0xFF00897B).withValues(alpha: 0.15),
      side: BorderSide(color: isSel ? const Color(0xFF00897B) : const Color(0xFFCBD5E1)),
      labelStyle: TextStyle(
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        color: isSel ? const Color(0xFF004D40) : const Color(0xFF334155),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _gridSize = value);
          Navigator.pop(ctx);
        }
      },
    );
  }

  /// Delete room
  void _confirmDeleteRoom(Room room) {
    final currentMember = ref.read(currentUserProvider);
    if (currentMember?.isChild == true) {
      showTopSnackBar(
        context,
        AppStrings.permissionDenied,
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(AppStrings.deleteRoomConfirmTitle),
          ],
        ),
        content: Text(
          AppStrings.deleteRoomConfirmMsg.replaceFirst('%s', room.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _selectedRoom = null;
                _selectedFurniture = null;
              });
              await ref.read(supabaseSyncControllerProvider.notifier).deleteRoom(room.id);
              if (mounted) {
                showTopSnackBar(
                  context,
                  AppStrings.roomDeleted,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Save newly drawn room
  void _promptSaveNewRoom() {
    if (_currentDrawingPoints.length < 3) return;

    final nameController = TextEditingController(text: 'Room ${_currentFloor * 10 + 1}');
    int floor = _currentFloor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.meeting_room, color: Color(0xFF00897B)),
                  SizedBox(width: 8),
                  Text(AppStrings.saveRoom),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: AppStrings.roomName,
                      hintText: AppStrings.roomNameHint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: floor,
                    decoration: const InputDecoration(
                      labelText: 'Floor',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3, 4]
                        .map((f) => DropdownMenuItem(value: f, child: Text(f == 1 ? AppStrings.groundFloor : 'Floor $f')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => floor = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Wall vertices: ${_currentDrawingPoints.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentDrawingPoints.clear();
                      _previewPoint = null;
                    });
                  },
                  child: const Text(AppStrings.discard),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      final newRoom = Room(
                        id: generateUuid(),
                        householdId: '00000000-0000-0000-0000-000000000001',
                        name: name,
                        floor: floor,
                        cleanlinessScore: 100,
                        polygonCoordinates: _currentDrawingPoints
                            .map((p) => {'x': p.dx, 'y': p.dy})
                            .toList(),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      await ref.read(supabaseSyncControllerProvider.notifier).saveDrawnRoom(newRoom);

                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() {
                          _currentFloor = floor;
                          _currentDrawingPoints.clear();
                          _previewPoint = null;
                          _currentMode = FloorPlanMode.furniture;
                          _selectedRoom = newRoom;
                        });
                        showTopSnackBar(
                          context,
                          AppStrings.roomSaved,
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsRealtimeStreamProvider);
    final rooms = roomsAsync.value ?? [];
    final furnitureList = ref.watch(furnitureRealtimeStreamProvider).value ?? [];
    final allTasks = ref.watch(tasksRealtimeStreamProvider).value ?? [];
    final pendingTasks = ref.watch(pendingApprovalTasksProvider);
    final presences = ref.watch(householdPresenceProvider);

    // Compute dynamic cleanliness scores for all rooms
    final cleanlinessMap = <String, int>{
      for (final r in rooms)
        r.id: CleanlinessEngine.calculateRoomCleanliness(
          room: r,
          allTasks: allTasks,
          allFurniture: furnitureList,
        ),
    };

    // Floor hierarchy
    final availableFloors = <int>{
      1,
      ...rooms.map((r) => r.floor),
      ..._createdFloors,
    }.toList()..sort();

    final currentFloorRooms = rooms.where((r) => r.floor == _currentFloor).toList();
    final roomFloorMap = {for (final r in rooms) r.id: r.floor};
    final currentFloorFurniture = furnitureList.where((f) => roomFloorMap[f.roomId] == _currentFloor).toList();

    final lowerFloorStairs = furnitureList.where((f) =>
        (f.category == 'stairs' ||
            f.name.toLowerCase().contains('lépcső') ||
            f.name.toLowerCase().contains('stairs')) &&
        roomFloorMap[f.roomId] == _currentFloor - 1).toList();

    final isPlacementActive = _currentMode == FloorPlanMode.furniture && _selectedFurnitureCatalogItem != null;

    final content = Stack(
      children: [
        // 1. Interactive 2D Canvas with RepaintBoundary
        Positioned.fill(
          child: MouseRegion(
            onHover: (event) => _handlePointerHover(event, currentFloorRooms),
            child: GestureDetector(
              onTapUp: (details) => _handleTapUp(
                details,
                currentFloorRooms,
                currentFloorFurniture,
                lowerFloorStairs,
              ),
              onPanUpdate: (details) {
                if (isPlacementActive) {
                  _updateGhostPosition(details.localPosition, currentFloorRooms);
                  _isGhostFixed = true;
                }
              },
              child: InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(800),
                minScale: 0.3,
                maxScale: 4.0,
                panEnabled: !isPlacementActive && _currentMode == FloorPlanMode.furniture,
                scaleEnabled: !isPlacementActive && _currentMode == FloorPlanMode.furniture,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(_canvasWidth, _canvasHeight),
                    painter: CustomFloorPainter(
                      rooms: currentFloorRooms,
                      selectedRoom: _selectedRoom,
                      furnitureItems: currentFloorFurniture,
                      selectedFurniture: _selectedFurniture,
                      currentDrawingPoints: _currentDrawingPoints,
                      previewPoint: _previewPoint,
                      showGrid: _showGrid,
                      gridSize: _gridSize,
                      canvasSize: const Size(_canvasWidth, _canvasHeight),
                      currentFloor: _currentFloor,
                      lowerFloorStairs: lowerFloorStairs,
                      ghostPosition: isPlacementActive ? _ghostPosition : null,
                      ghostFurnitureName: _selectedFurnitureName,
                      ghostCategory: _selectedFurnitureCategory,
                      ghostWidth: _furnitureWidth,
                      ghostHeight: _furnitureHeight,
                      ghostRotation: _furnitureRotation,
                      isGhostInsideRoom: _isGhostInsideRoom,
                      roomCleanlinessScores: cleanlinessMap,
                      activePresences: presences,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Pending Approval Coins
        if (pendingTasks.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Builder(builder: (context) {
                return Stack(
                  children: pendingTasks.map((task) {
                    final room = currentFloorRooms.cast<Room?>().firstWhere(
                          (r) => r?.id == task.referenceId,
                          orElse: () => null,
                        );
                    if (room == null) return const SizedBox.shrink();

                    final vertices = GeometryUtils.roomToPolygon(room);
                    if (vertices.isEmpty) return const SizedBox.shrink();
                    final canvasCentroid = GeometryUtils.computeCentroid(vertices);

                    final matrix = _transformationController.value;
                    final screenPoint = MatrixUtils.transformPoint(
                      matrix,
                      canvasCentroid,
                    );

                    return AnimatedCoin(
                      key: ValueKey('coin_${task.id}'),
                      task: task,
                      screenPosition: screenPoint,
                      onTap: () => _showCoinApprovalSideSheet(context, task),
                    );
                  }).toList(),
                );
              }),
            ),
          ),

        // 3. Top Responsive Controls Bar: Floor Pills, Mode Selector & Interactive Snap
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3.A: Floor selector with delete option
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.layers_rounded, size: 18, color: Color(0xFF00897B)),
                      const SizedBox(width: 8),
                      const Text(
                        AppStrings.level,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(width: 8),
                      ...availableFloors.map((fl) {
                        final isSel = _currentFloor == fl;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentFloor = fl;
                                _selectedRoom = null;
                                _selectedFurniture = null;
                                _ghostPosition = null;
                                _ghostTargetRoom = null;
                                _isGhostFixed = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF00897B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF004D40) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppStrings.floorLabel(fl),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                  // Floor delete icon for floors > 1
                                  if (fl > 1) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _confirmDeleteFloor(fl, furnitureList),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: isSel ? Colors.white70 : Colors.red.shade400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      // Add new floor button
                      IconButton(
                        tooltip: AppStrings.addFloor,
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF00897B)),
                        onPressed: () {
                          final currentMember = ref.read(currentUserProvider);
                          if (currentMember?.isChild == true) {
                            showTopSnackBar(
                              context,
                              AppStrings.permissionDenied,
                              isError: true,
                            );
                            return;
                          }
                          final nextFl = (availableFloors.last) + 1;
                          setState(() {
                            _createdFloors.add(nextFl);
                            _currentFloor = nextFl;
                            _selectedRoom = null;
                            _selectedFurniture = null;
                            _ghostPosition = null;
                            _ghostTargetRoom = null;
                            _isGhostFixed = false;
                          });
                          showTopSnackBar(
                            context,
                            '🏢 ${AppStrings.floorLabel(nextFl)} created!',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 3.B: Mode Bar (Furnish vs Draw Walls) and Interactive Snap
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(
                          mode: FloorPlanMode.furniture,
                          icon: Icons.chair_outlined,
                          label: AppStrings.modeFurnish,
                        ),
                        _buildModeButton(
                          mode: FloorPlanMode.draw,
                          icon: Icons.edit_road_rounded,
                          label: AppStrings.modeDrawWalls,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Undo and Interactive Grid Snap Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_placedFurnitureHistory.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: IconButton(
                            tooltip: AppStrings.undoLastFurniture,
                            icon: const Icon(Icons.undo, color: Color(0xFF00897B), size: 20),
                            onPressed: _undoLastFurniture,
                          ),
                        ),
                      // Interactive Snap Badge (Clickable)
                      InkWell(
                        onTap: _showSnapSettingsDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.straighten, size: 16, color: Color(0xFF00897B)),
                              const SizedBox(width: 4),
                              Text(
                                _gridSize == 1.0 ? 'Snap: Off' : 'Snap: ${_gridSize.toInt()} px',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down, size: 16, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3.B: Collaborator Presence Status Banner
        if (presences.any((p) => p.isBusy))
          Positioned(
            top: 110,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    presences
                        .where((p) => p.isBusy)
                        .map((p) => '${p.userAvatar} ${p.userName}: ${p.displayStatus}')
                        .join(' • '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 4. FURNITURE PLACEMENT CONTROLS (Active placement mode)
        if (isPlacementActive)
          Positioned(
            bottom: 84,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    // Dual Dimension Controls (Width & Length) + Rotation
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(AppStrings.size, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 6),
                        // Width +/-
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${AppStrings.width} ${_furnitureWidth.toInt()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () {
                                  if (_furnitureWidth > 25) setState(() => _furnitureWidth -= 10);
                                },
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () {
                                  if (_furnitureWidth < 300) setState(() => _furnitureWidth += 10);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Length +/-
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${AppStrings.length} ${_furnitureHeight.toInt()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () {
                                  if (_furnitureHeight > 25) setState(() => _furnitureHeight -= 10);
                                },
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () {
                                  if (_furnitureHeight < 300) setState(() => _furnitureHeight += 10);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Rotate 90° button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          icon: const Icon(Icons.rotate_right_rounded, size: 16),
                          label: const Text(AppStrings.rotate, style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _furnitureRotation = (_furnitureRotation + 90.0) % 360.0;
                              // also swap width and height for intuitive 2D layout
                              final tmp = _furnitureWidth;
                              _furnitureWidth = _furnitureHeight;
                              _furnitureHeight = tmp;
                            });
                          },
                        ),
                      ],
                    ),

                    // Actions: Cancel & Place
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text(AppStrings.cancel),
                          onPressed: _cancelPlaceFurniture,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(AppStrings.place),
                          onPressed: _confirmPlaceFurniture,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 5. FURNITURE CATALOG BAR (Categorized, comprehensive catalog)
        if (_currentMode == FloorPlanMode.furniture)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 860),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A: Category Tabs Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryTabChip('all', 'All Items', '🌟', const Color(0xFF00897B)),
                          ...FurnitureCatalog.categories.map((c) =>
                            _buildCategoryTabChip(c.key, c.label, c.emoji, c.color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // B: Items in Selected Category
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: FurnitureCatalog.itemsIn(_selectedCatalogCategoryKey)
                            .map((item) => _buildCatalogItemChip(item))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 6. WALL DRAWING BAR (Active when drawing)
        if (_currentMode == FloorPlanMode.draw)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '${AppStrings.points} ${_currentDrawingPoints.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentDrawingPoints.length < 3
                          ? AppStrings.tapToStartDrawing
                          : AppStrings.tapFirstPointToClose,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_currentDrawingPoints.isNotEmpty)
                    IconButton(
                      tooltip: AppStrings.undoLastPoint,
                      icon: const Icon(Icons.undo),
                      onPressed: () {
                        setState(() {
                          _currentDrawingPoints.removeLast();
                        });
                      },
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentDrawingPoints.length >= 3
                          ? const Color(0xFF00897B)
                          : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _currentDrawingPoints.length >= 3 ? _promptSaveNewRoom : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(AppStrings.saveRoom),
                  ),
                ],
              ),
            ),
          ),

        // 7. SIDE PANEL: Room or Furniture Details & Task Assignment
        if (_selectedRoom != null || _selectedFurniture != null)
          Positioned(
            top: 76,
            bottom: 80,
            right: 14,
            child: _buildSideDetailsPanel(
              context,
              rooms,
              furnitureList,
              allTasks,
              cleanlinessMap,
            ),
          ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('2D Interactive Floor Plan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: AppStrings.toggleGrid,
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          IconButton(
            tooltip: AppStrings.resetView,
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _resetTransform,
          ),
          // Sample layout test data removed - fresh start
        ],
      ),
      body: content,
    );
  }

  /// Side Details Panel replacing bottom sheets
  /// Side Details Panel replacing bottom sheets:
  /// When a room is selected, displays direct room tasks AND all furniture items in that room
  /// along with each item's associated cleaning tasks.
  Widget _buildSideDetailsPanel(
    BuildContext context,
    List<Room> rooms,
    List<FurnitureItem> furnitureList,
    List<TaskItem> allTasks,
    Map<String, int> cleanlinessMap,
  ) {
    final members = ref.watch(householdMembersProvider);
    final currentMember = ref.watch(currentUserProvider);

    // If an individual furniture item is directly selected
    if (_selectedFurniture != null) {
      final furniture = _selectedFurniture!;
      final parentRoom = rooms.cast<Room?>().firstWhere(
            (r) => r?.id == furniture.roomId,
            orElse: () => null,
          );
      final furnitureTasks = allTasks
          .where((t) =>
              t.referenceType == TaskReferenceType.furnitureItem &&
              t.referenceId == furniture.id)
          .toList();

      return Container(
        width: 360,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(-2, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _furnitureEmoji(furniture.category ?? furniture.name),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        furniture.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (parentRoom != null)
                        Text(
                          'in ${parentRoom.name}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedFurniture = null;
                      _selectedRoom = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action toolbar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 16),
                    label: const Text(AppStrings.assignTask,
                        style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      AddTaskDialog.show(
                        context,
                        rooms: rooms,
                        furnitureList: furnitureList,
                        initialReferenceType: TaskReferenceType.furnitureItem,
                        initialTargetId: furniture.id,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: AppStrings.deleteFurniture,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () {
                    if (currentMember?.isChild == true) {
                      showTopSnackBar(
                        context,
                        AppStrings.permissionDenied,
                        isError: true,
                      );
                      return;
                    }
                    ref
                        .read(supabaseSyncControllerProvider.notifier)
                        .deleteFurniture(furniture.id);
                    setState(() => _selectedFurniture = null);
                    showTopSnackBar(
                        context, 'Furniture deleted successfully');
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              'Tasks (${furnitureTasks.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: furnitureTasks.isEmpty
                  ? Center(
                      child: Text(
                        'No chores for this item yet.\nTap "${AppStrings.assignTask}" above!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: furnitureTasks.length,
                      itemBuilder: (ctx, idx) =>
                          _buildSideTaskCard(furnitureTasks[idx], members),
                    ),
            ),
          ],
        ),
      );
    }

    // A Room is selected: inspect room, its direct tasks, and its furniture + furniture tasks!
    final room = _selectedRoom!;
    final score = cleanlinessMap[room.id] ?? room.cleanlinessScore;

    // 1. Direct tasks for this room
    final directRoomTasks = allTasks
        .where((t) =>
            t.referenceType == TaskReferenceType.room &&
            t.referenceId == room.id)
        .toList();

    // 2. All furniture items located in this room
    final roomFurniture =
        furnitureList.where((f) => f.roomId == room.id).toList();

    // Total count of tasks inside this room (direct + on furniture)
    final furnitureIds = roomFurniture.map((f) => f.id).toSet();
    final allRoomScopeTasksCount = directRoomTasks.length +
        allTasks
            .where((t) =>
                t.referenceType == TaskReferenceType.furnitureItem &&
                furnitureIds.contains(t.referenceId))
            .length;

    Color scoreColor;
    if (score >= 80) {
      scoreColor = Colors.green;
    } else if (score >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(-2, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: Color(0xFF00897B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${AppStrings.floorLabel(room.floor)} • $allRoomScopeTasksCount total tasks',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _selectedRoom = null;
                    _selectedFurniture = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Cleanliness progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 10),

          // Action Toolbar: Assign Room Task & Delete Room
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.add_task_rounded, size: 15),
                  label: const Text(AppStrings.assignTask,
                      style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    AddTaskDialog.show(
                      context,
                      rooms: rooms,
                      furnitureList: furnitureList,
                      initialReferenceType: TaskReferenceType.room,
                      initialTargetId: room.id,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Delete',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
                onPressed: () => _confirmDeleteRoom(room),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Scrollable Room Inspection Body: Direct Tasks & Objects in Room
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. Direct Room Tasks Section
                Row(
                  children: [
                    const Icon(Icons.checklist_rounded,
                        size: 16, color: Color(0xFF00897B)),
                    const SizedBox(width: 6),
                    Text(
                      '${AppStrings.roomTasks} (${directRoomTasks.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (directRoomTasks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      AppStrings.noTasksInRoom,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  )
                else
                  ...directRoomTasks
                      .map((t) => _buildSideTaskCard(t, members)),

                const SizedBox(height: 14),

                // 2. Furniture & Objects in Room Section (Requirement #1.5)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chair_outlined,
                            size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        Text(
                          '${AppStrings.roomFurniture} (${roomFurniture.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (roomFurniture.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppStrings.noFurnitureInRoom,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...roomFurniture.map((f) {
                    final fTasks = allTasks
                        .where((t) =>
                            t.referenceType ==
                                TaskReferenceType.furnitureItem &&
                            t.referenceId == f.id)
                        .toList();
                    return _buildRoomFurnitureInspectionItem(
                      f,
                      fTasks,
                      members,
                      rooms,
                      furnitureList,
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget for a single furniture item within a room's inspection sheet
  Widget _buildRoomFurnitureInspectionItem(
    FurnitureItem furniture,
    List<TaskItem> itemTasks,
    List<FamilyMember> members,
    List<Room> rooms,
    List<FurnitureItem> furnitureList,
  ) {
    final currentMember = ref.watch(currentUserProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _furnitureEmoji(furniture.category ?? furniture.name),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  furniture.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Add task to this specific furniture item
              InkWell(
                onTap: () {
                  AddTaskDialog.show(
                    context,
                    rooms: rooms,
                    furnitureList: furnitureList,
                    initialReferenceType: TaskReferenceType.furnitureItem,
                    initialTargetId: furniture.id,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_task_rounded,
                          size: 12, color: Color(0xFF00897B)),
                      SizedBox(width: 3),
                      Text('+ Task',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00897B),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Delete furniture item
              InkWell(
                onTap: () {
                  if (currentMember?.isChild == true) {
                    showTopSnackBar(
                      context,
                      AppStrings.permissionDenied,
                      isError: true,
                    );
                    return;
                  }
                  ref
                      .read(supabaseSyncControllerProvider.notifier)
                      .deleteFurniture(furniture.id);
                  showTopSnackBar(
                      context, '${furniture.name} deleted');
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(Icons.delete_outline,
                      size: 16, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          if (itemTasks.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...itemTasks.map((t) => _buildSideTaskCard(t, members)),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 4.0),
              child: Text(
                'No tasks on this item.',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  /// Compact task card with completion toggle, assignee badge, and countdown
  Widget _buildSideTaskCard(TaskItem t, List<FamilyMember> members) {
    final currentMember = ref.watch(currentUserProvider);
    final assigneeName = resolveAssigneeName(t.assignedTo, members);
    final assigneeAvatar = resolveAssigneeAvatar(t.assignedTo, members);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: t.isCompleted,
              activeColor: const Color(0xFF00897B),
              onChanged: (_) async {
                final wasCompleted = t.isCompleted;
                final result = await ref
                    .read(supabaseSyncControllerProvider.notifier)
                    .toggleTaskStatus(
                      t.id,
                      t.status,
                      completedBy: currentMember?.name ?? 'Someone',
                    );
                if (!mounted) return;
                if (!wasCompleted && result != null && result.points > 0) {
                  TaskCelebrationOverlay.show(
                    context,
                    points: result.points,
                    taskTitle: t.title,
                    currentPoints: (currentMember?.points ?? 0) + result.points,
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    decoration:
                        t.isCompleted ? TextDecoration.lineThrough : null,
                    color: t.isCompleted
                        ? Colors.grey.shade500
                        : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${t.priority}⭐ • ${t.formattedCountdown()}',
                  style: TextStyle(
                    fontSize: 9,
                    color: t.isOverdue() ? Colors.red : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Assignee pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(assigneeAvatar, style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 2),
                Text(
                  assigneeName,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _furnitureEmoji(String category) {
    return FurnitureCatalog.emojiFor(category, category);
  }

  void _showCoinApprovalSideSheet(BuildContext context, TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Color(0xFFFFB300)),
            SizedBox(width: 8),
            Text(AppStrings.pendingApproval),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Reward: ${task.pointsReward} ${AppStrings.pointsSuffix}'),
            const SizedBox(height: 4),
            Text('Assigned to: ${task.assignedTo ?? "Child"}'),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(taskAssignmentControllerProvider.notifier).rejectChildTask(task);
            },
            child: const Text(AppStrings.reject),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(taskAssignmentControllerProvider.notifier).approveChildTask(task);
            },
            child: const Text(AppStrings.approve),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabChip(String key, String label, String emoji, Color color) {
    final isSelected = _selectedCatalogCategoryKey == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCatalogCategoryKey = key;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogItemChip(FurnitureType type) {
    final isSelected = _selectedFurnitureCatalogItem == type.name;
    final catColor = FurnitureCatalog.colorFor(type.name, type.category);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Text(type.emoji, style: const TextStyle(fontSize: 13)),
        label: Text(type.name),
        selected: isSelected,
        selectedColor: catColor.withValues(alpha: 0.18),
        backgroundColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(
          color: isSelected ? catColor : const Color(0xFFE2E8F0),
          width: isSelected ? 2.0 : 1.0,
        ),
        labelStyle: TextStyle(
          fontSize: 11,
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        onSelected: (_) {
          _selectFurniture(type.name, type.category);
        },
      ),
    );
  }

  Widget _buildModeButton({
    required FloorPlanMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00897B) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
