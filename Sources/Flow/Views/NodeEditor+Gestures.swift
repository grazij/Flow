// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

import SwiftUI

extension NodeEditor {
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
            guard drag.distance < 5 else { return }

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
            default: break
            }
        }
    }
#endif

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
                    dragInfo = .selection(rect: CGRect(a: startLocation,
                                                       b: location))
                case let .node(nodeIndex):
                    dragInfo = .node(index: nodeIndex, offset: translation)
                case let .output(nodeIndex, portIndex):
                    dragInfo = DragInfo.wire(output: OutputID(nodeIndex, portIndex), offset: translation)
                case let .input(nodeIndex, portIndex):
                    guard let node = patch.nodes[safe: nodeIndex],
                          node.inputs.indices.contains(portIndex) else {
                        break
                    }
                    // Is a wire attached to the input?
                    if let attachedWire = attachedWire(inputID: InputID(nodeIndex, portIndex)),
                       let outputNode = patch.nodes[safe: attachedWire.output.nodeIndex],
                       outputNode.outputs.indices.contains(attachedWire.output.portIndex) {
                        let offset = node.inputRect(input: portIndex, layout: layout).center
                            - outputNode.outputRect(
                                output: attachedWire.output.portIndex,
                                layout: layout
                            ).center
                            + translation
                        dragInfo = .wire(output: attachedWire.output,
                                         offset: offset,
                                         hideWire: attachedWire)
                    }
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
                if drag.distance > 5 {
                    switch hitResult {
                    case .none:
                        let selectionRect = CGRect(a: startLocation, b: location)
                        selection = self.patch.selected(
                            in: selectionRect,
                            layout: layout
                        )
                    case let .node(nodeIndex):
                        patch.moveNode(
                            nodeIndex: nodeIndex,
                            offset: translation,
                            nodeMoved: self.nodeMoved
                        )
                        if selection.contains(nodeIndex) {
                            for idx in selection where idx != nodeIndex {
                                patch.moveNode(
                                    nodeIndex: idx,
                                    offset: translation,
                                    nodeMoved: self.nodeMoved
                                )
                            }
                        }
                    case let .output(nodeIndex, portIndex):
                        guard let node = patch.nodes[safe: nodeIndex],
                              let port = node.outputs[safe: portIndex] else {
                            break
                        }
                        if let input = findInput(point: location, type: port.type) {
                            connect(OutputID(nodeIndex, portIndex), to: input)
                        }
                    case let .input(nodeIndex, portIndex):
                        guard let node = patch.nodes[safe: nodeIndex],
                              let port = node.inputs[safe: portIndex] else {
                            break
                        }
                        // Is a wire attached to the input?
                        if let attachedWire = attachedWire(inputID: InputID(nodeIndex, portIndex)) {
                            patch.wires.remove(attachedWire)
                            wireRemoved(attachedWire)
                            if let input = findInput(point: location, type: port.type) {
                                connect(attachedWire.output, to: input)
                            }
                        }
                    }
                } else {
                    // If we haven't moved far, then this is effectively a tap.
                    switch hitResult {
                    case .none:
                        selection = Set<NodeIndex>()
                    case let .node(nodeIndex):
                        selection = Set<NodeIndex>([nodeIndex])
                    default: break
                    }
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
