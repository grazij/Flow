// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

import SwiftUI

extension NodeEditor {
    /// Minimum drag distance (in screen coordinates) to distinguish a drag from a tap.
    private static let minimumDragDistance: CGFloat = 5

    /// State for all gestures.
    enum DragInfo {
        case wire(output: OutputID, offset: CGSize = .zero, hideWire: Wire? = nil)
        case node(index: NodeIndex, offset: CGSize = .zero)
        case selection(rect: CGRect = .zero)
        case none
    }

    /// Adds a new wire to the patch, ensuring that multiple wires aren't connected to an input.
    func connect(_ output: OutputID, to input: InputID) {
        let wire = Wire(from: output, to: input)

        // Find and remove any other wires connected to the input.
        let wiresToRemove = patch.wires.filter { $0.input == wire.input }

        // Remove wires and notify handlers
        for wireToRemove in wiresToRemove {
            patch.wires.remove(wireToRemove)
            wireRemoved(wireToRemove)
        }

        // Add new wire
        patch.wires.insert(wire)
        wireAdded(wire)
    }

    func attachedWire(inputID: InputID) -> Wire? {
        patch.wires.first(where: { $0.input == inputID })
    }

    func toLocal(_ p: CGPoint) -> CGPoint {
        let currentZoom = max(zoom, 0.1)  // Ensure zoom is never below minimum
        return CGPoint(x: p.x / CGFloat(currentZoom), y: p.y / CGFloat(currentZoom)) - pan
    }

    func toLocal(_ sz: CGSize) -> CGSize {
        let currentZoom = max(zoom, 0.1)  // Ensure zoom is never below minimum
        return CGSize(width: sz.width / CGFloat(currentZoom), height: sz.height / CGFloat(currentZoom))
    }

#if os(macOS)
    var commandGesture: some Gesture {
        DragGesture(minimumDistance: 0).modifiers(.command).onEnded { drag in
            guard drag.distance < Self.minimumDragDistance else { return }

            let startLocation = toLocal(drag.startLocation)

            let hitResult = patch.hitTest(point: startLocation, layout: layout)
            switch hitResult {
            case .none:
                return
            case let .node(nodeIndex):
                if selection.contains(nodeIndex) {
                    selection.remove(nodeIndex)
                } else {
                    selection.insert(nodeIndex)
                }
            case let .wire(wire):
                if wireSelection.contains(wire) {
                    wireSelection.remove(wire)
                } else {
                    wireSelection.insert(wire)
                }
            default: break
            }
        }
    }
#endif

    // MARK: - Drag Info Update Helpers

    /// Updates drag info for an input port being dragged (detaching and re-routing a wire).
    private func updateDragInfoForInput(
        nodeIndex: NodeIndex,
        portIndex: PortIndex,
        translation: CGSize
    ) -> DragInfo? {
        guard let node = patch.nodes[safe: nodeIndex],
              node.inputs.indices.contains(portIndex) else {
            return nil
        }

        // Is a wire attached to the input?
        guard let attachedWire = attachedWire(inputID: InputID(nodeIndex, portIndex)),
              let outputNode = patch.nodes[safe: attachedWire.output.nodeIndex],
              outputNode.outputs.indices.contains(attachedWire.output.portIndex) else {
            return nil
        }

        let offset = node.inputRect(input: portIndex, layout: layout).center
            - outputNode.outputRect(output: attachedWire.output.portIndex, layout: layout).center
            + translation

        return .wire(output: attachedWire.output, offset: offset, hideWire: attachedWire)
    }

    // MARK: - Drag Completion Helpers

    /// Handles completing a selection rectangle drag.
    private func handleSelectionDrag(startLocation: CGPoint, endLocation: CGPoint) {
        let selectionRect = CGRect(a: startLocation, b: endLocation)
        selection = patch.selected(in: selectionRect, layout: layout)
    }

    /// Handles completing a node drag, including any selected nodes.
    private func handleNodeDrag(nodeIndex: NodeIndex, translation: CGSize) {
        patch.moveNode(nodeIndex: nodeIndex, offset: translation, nodeMoved: nodeMoved)

        // Also move other selected nodes if this node is part of selection
        if selection.contains(nodeIndex) {
            for idx in selection where idx != nodeIndex {
                patch.moveNode(nodeIndex: idx, offset: translation, nodeMoved: nodeMoved)
            }
        }
    }

    /// Handles completing an output port drag (creating a new wire).
    private func handleOutputDrag(nodeIndex: NodeIndex, portIndex: PortIndex, location: CGPoint) {
        guard let node = patch.nodes[safe: nodeIndex],
              let port = node.outputs[safe: portIndex] else {
            return
        }

        if let input = findInput(point: location, type: port.type) {
            connect(OutputID(nodeIndex, portIndex), to: input)
        }
    }

    /// Handles completing an input port drag (reconnecting an existing wire).
    private func handleInputDrag(nodeIndex: NodeIndex, portIndex: PortIndex, location: CGPoint) {
        guard let node = patch.nodes[safe: nodeIndex],
              let port = node.inputs[safe: portIndex] else {
            return
        }

        // Is a wire attached to the input?
        guard let attachedWire = attachedWire(inputID: InputID(nodeIndex, portIndex)) else {
            return
        }

        patch.wires.remove(attachedWire)
        wireRemoved(attachedWire)

        if let input = findInput(point: location, type: port.type) {
            connect(attachedWire.output, to: input)
        }
    }

    /// Handles a tap gesture (drag distance below threshold).
    private func handleTap(hitResult: Patch.HitTestResult?) {
        switch hitResult {
        case .none:
            selection = Set<NodeIndex>()
            wireSelection = Set<Wire>()
        case let .node(nodeIndex):
            selection = Set<NodeIndex>([nodeIndex])
            wireSelection = Set<Wire>()
        case let .wire(wire):
            selection = Set<NodeIndex>()
            wireSelection = Set<Wire>([wire])
        default:
            break
        }
    }

    /// Deletes selected wires and nodes.
    ///
    /// This method handles deletion of selected nodes and wires, automatically:
    /// - Removing selected wires
    /// - Removing wires connected to selected nodes (cascade deletion)
    /// - Updating wire indices after node deletion to prevent corruption
    /// - Clearing the selection
    ///
    /// Call this from `.onDeleteCommand` in your view:
    /// ```swift
    /// NodeEditor(patch: $patch, selection: $selection, wireSelection: $wireSelection)
    ///     .onDeleteCommand {
    ///         // Call deleteSelected on the NodeEditor instance
    ///     }
    /// ```
    public func deleteSelected() {
        guard !wireSelection.isEmpty || !selection.isEmpty else { return }

        // Delete selected wires
        for wire in wireSelection {
            patch.wires.remove(wire)
            wireRemoved(wire)
        }

        // Find and delete wires connected to selected nodes
        let wiresToRemove = patch.wires.filter { wire in
            selection.contains(wire.output.nodeIndex) || selection.contains(wire.input.nodeIndex)
        }

        for wire in wiresToRemove {
            patch.wires.remove(wire)
            wireRemoved(wire)
        }

        // Delete nodes and update wire indices
        if !selection.isEmpty {
            let sortedIndices = selection.sorted(by: >)

            for nodeIndex in sortedIndices {
                guard patch.nodes.indices.contains(nodeIndex) else { continue }
                patch.nodes.remove(at: nodeIndex)
                nodesDeleted([nodeIndex])

                // Update all wire references to account for the deleted node
                var updatedWires = Set<Wire>()
                for wire in patch.wires {
                    var newWire = wire

                    // Adjust output node index if it's after the deleted node
                    if wire.output.nodeIndex > nodeIndex {
                        newWire = Wire(
                            from: OutputID(wire.output.nodeIndex - 1, wire.output.portIndex),
                            to: wire.input
                        )
                    }

                    // Adjust input node index if it's after the deleted node
                    if wire.input.nodeIndex > nodeIndex {
                        newWire = Wire(
                            from: newWire.output,
                            to: InputID(wire.input.nodeIndex - 1, wire.input.portIndex)
                        )
                    }

                    updatedWires.insert(newWire)
                }
                patch.wires = updatedWires
            }
        }

        // Clear selections
        wireSelection.removeAll()
        selection.removeAll()
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragInfo) { drag, dragInfo, _ in
                let startLocation = toLocal(drag.startLocation)
                let location = toLocal(drag.location)
                let translation = toLocal(drag.translation)

                // Cache hit test result to avoid redundant iteration in onEnded
                let hitResult = patch.hitTest(point: startLocation, layout: layout)
                cachedHitResult = hitResult

                switch hitResult {
                case .none:
                    dragInfo = .selection(rect: CGRect(a: startLocation, b: location))
                case let .node(nodeIndex):
                    dragInfo = .node(index: nodeIndex, offset: translation)
                case let .output(nodeIndex, portIndex):
                    dragInfo = .wire(output: OutputID(nodeIndex, portIndex), offset: translation)
                case let .input(nodeIndex, portIndex):
                    if let info = updateDragInfoForInput(nodeIndex: nodeIndex, portIndex: portIndex, translation: translation) {
                        dragInfo = info
                    }
                case .wire:
                    // Wires don't drag, they're only selectable on tap
                    break
                }
            }
            .onEnded { drag in
                let startLocation = toLocal(drag.startLocation)
                let location = toLocal(drag.location)
                let translation = toLocal(drag.translation)

                // Use cached hit test result instead of iterating again
                let hitResult = cachedHitResult ?? patch.hitTest(point: startLocation, layout: layout)
                cachedHitResult = nil  // Clear cache after use

                // Note that this threshold should be in screen coordinates.
                if drag.distance > Self.minimumDragDistance {
                    // Handle drag gestures
                    switch hitResult {
                    case .none:
                        handleSelectionDrag(startLocation: startLocation, endLocation: location)
                    case let .node(nodeIndex):
                        handleNodeDrag(nodeIndex: nodeIndex, translation: translation)
                    case let .output(nodeIndex, portIndex):
                        handleOutputDrag(nodeIndex: nodeIndex, portIndex: portIndex, location: location)
                    case let .input(nodeIndex, portIndex):
                        handleInputDrag(nodeIndex: nodeIndex, portIndex: portIndex, location: location)
                    case .wire:
                        // Wires don't drag
                        break
                    }
                } else {
                    // If we haven't moved far, then this is effectively a tap
                    handleTap(hitResult: hitResult)
                }
            }
    }
}

extension DragGesture.Value {
    @inlinable @inline(__always)
    var distance: CGFloat {
        startLocation.distance(to: location)
    }
}
