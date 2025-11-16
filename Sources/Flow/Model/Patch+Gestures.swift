// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

import CoreGraphics
import Foundation

extension Patch {
    enum HitTestResult {
        case node(NodeIndex)
        case input(NodeIndex, PortIndex)
        case output(NodeIndex, PortIndex)
        case wire(Wire)
    }

    /// Hit test a point against the whole patch.
    func hitTest(point: CGPoint, layout: LayoutConstants) -> HitTestResult? {
        // Test nodes first (higher priority)
        for (nodeIndex, node) in nodes.enumerated().reversed() {
            if let result = node.hitTest(nodeIndex: nodeIndex, point: point, layout: layout) {
                return result
            }
        }

        // Test wires if no node was hit
        for wire in wires {
            if wireContains(wire: wire, point: point, layout: layout) {
                return .wire(wire)
            }
        }

        return nil
    }

    /// Check if a point is near a wire's Bezier curve.
    private func wireContains(wire: Wire, point: CGPoint, layout: LayoutConstants) -> Bool {
        // Skip wire if nodes don't exist (stale wire references)
        guard let outputNode = nodes[safe: wire.output.nodeIndex],
              let inputNode = nodes[safe: wire.input.nodeIndex],
              outputNode.outputs.indices.contains(wire.output.portIndex),
              inputNode.inputs.indices.contains(wire.input.portIndex) else {
            return false
        }

        let fromPoint = outputNode.outputRect(output: wire.output.portIndex, layout: layout).center
        let toPoint = inputNode.inputRect(input: wire.input.portIndex, layout: layout).center

        // Calculate Bezier curve control points (same as drawing)
        let d = 0.4 * abs(toPoint.x - fromPoint.x)
        let control1 = CGPoint(x: fromPoint.x + d, y: fromPoint.y)
        let control2 = CGPoint(x: toPoint.x - d, y: toPoint.y)

        // Sample points along the curve and check distance to click point
        let samples = 20
        let hitThreshold: CGFloat = 8.0 // pixels

        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let curvePoint = cubicBezier(
                t: t,
                p0: fromPoint,
                p1: control1,
                p2: control2,
                p3: toPoint
            )

            if point.distance(to: curvePoint) < hitThreshold {
                return true
            }
        }

        return false
    }

    /// Calculate a point on a cubic Bezier curve.
    private func cubicBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusT2 = oneMinusT * oneMinusT
        let oneMinusT3 = oneMinusT2 * oneMinusT
        let t2 = t * t
        let t3 = t2 * t

        let x = oneMinusT3 * p0.x + 3 * oneMinusT2 * t * p1.x + 3 * oneMinusT * t2 * p2.x + t3 * p3.x
        let y = oneMinusT3 * p0.y + 3 * oneMinusT2 * t * p1.y + 3 * oneMinusT * t2 * p2.y + t3 * p3.y

        return CGPoint(x: x, y: y)
    }

    mutating func moveNode(
        nodeIndex: NodeIndex,
        offset: CGSize,
        nodeMoved: NodeEditor.NodeMovedHandler
    ) {
        guard let node = nodes[safe: nodeIndex], !node.locked else {
            return
        }
        nodes[nodeIndex].position += offset
        nodeMoved(nodeIndex, nodes[nodeIndex].position)
    }

    /// Deletes selected nodes and wires from the patch.
    ///
    /// This function:
    /// - Removes selected wires
    /// - Removes wires connected to selected nodes (cascade deletion)
    /// - Updates wire indices after node deletion to prevent corruption
    ///
    /// Use this from `.onDeleteCommand` in your app:
    /// ```swift
    /// .onDeleteCommand {
    ///     patch.deleteSelected(nodes: &selection, wires: &wireSelection)
    /// }
    /// ```
    public mutating func deleteSelected(nodes nodeSelection: inout Set<NodeIndex>, wires wireSelection: inout Set<Wire>) {
        guard !wireSelection.isEmpty || !nodeSelection.isEmpty else { return }

        // Delete selected wires
        for wire in wireSelection {
            wires.remove(wire)
        }

        // Find and delete wires connected to selected nodes
        let wiresToRemove = wires.filter { wire in
            nodeSelection.contains(wire.output.nodeIndex) || nodeSelection.contains(wire.input.nodeIndex)
        }

        for wire in wiresToRemove {
            wires.remove(wire)
        }

        // Delete nodes and update wire indices
        if !nodeSelection.isEmpty {
            let sortedIndices = nodeSelection.sorted(by: >)

            for nodeIndex in sortedIndices {
                guard nodes.indices.contains(nodeIndex) else { continue }
                nodes.remove(at: nodeIndex)

                // Update all wire references to account for the deleted node
                var updatedWires = Set<Wire>()
                for wire in wires {
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
                wires = updatedWires
            }
        }

        // Clear selections
        wireSelection.removeAll()
        nodeSelection.removeAll()
    }

    func selected(in rect: CGRect, layout: LayoutConstants) -> Set<NodeIndex> {
        var selection = Set<NodeIndex>()

        for (idx, node) in nodes.enumerated() {
            if rect.intersects(node.rect(layout: layout)) {
                selection.insert(idx)
            }
        }
        return selection
    }
}
