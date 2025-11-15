// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

import CoreGraphics
import Foundation

public extension Patch {
    /// Builds an adjacency map of incoming wires for each node.
    ///
    /// This map is used internally by `recursiveLayout` to avoid O(n × m) wire filtering.
    /// - Returns: Dictionary mapping node indices to their incoming wires, sorted by port index.
    private func buildIncomingWiresMap() -> [NodeIndex: [Wire]] {
        var map: [NodeIndex: [Wire]] = [:]

        // Group wires by target node
        for wire in wires {
            map[wire.input.nodeIndex, default: []].append(wire)
        }

        // Sort each node's incoming wires by port index
        for (nodeIndex, wires) in map {
            map[nodeIndex] = wires.sorted(by: { $0.input.portIndex < $1.input.portIndex })
        }

        return map
    }

    /// Recursive layout implementation with pre-built adjacency map.
    private mutating func recursiveLayoutWithMap(
        nodeIndex: NodeIndex,
        at point: CGPoint,
        layout: LayoutConstants,
        consumedNodeIndexes: Set<NodeIndex>,
        nodePadding: Bool,
        incomingWiresMap: [NodeIndex: [Wire]]
    ) -> (aggregateHeight: CGFloat,
          consumedNodeIndexes: Set<NodeIndex>)
    {
        guard nodes.indices.contains(nodeIndex) else {
            return (aggregateHeight: 0, consumedNodeIndexes: consumedNodeIndexes)
        }

        nodes[nodeIndex].position = point

        // Use pre-built adjacency map instead of filtering all wires
        let incomingWires = incomingWiresMap[nodeIndex] ?? []

        var consumedNodeIndexes = consumedNodeIndexes

        var height: CGFloat = 0
        for wire in incomingWires {
            let addPadding = wire == incomingWires.last
            let ni = wire.output.nodeIndex
            guard !consumedNodeIndexes.contains(ni) else { continue }
            let rl = recursiveLayoutWithMap(
                nodeIndex: ni,
                at: CGPoint(x: point.x - layout.nodeWidth - layout.nodeSpacing,
                            y: point.y + height),
                layout: layout,
                consumedNodeIndexes: consumedNodeIndexes,
                nodePadding: addPadding,
                incomingWiresMap: incomingWiresMap
            )
            height = rl.aggregateHeight
            consumedNodeIndexes.insert(ni)
            consumedNodeIndexes.formUnion(rl.consumedNodeIndexes)
        }

        let nodeHeight = nodes[nodeIndex].rect(layout: layout).height
        let aggregateHeight = max(height, nodeHeight) + (nodePadding ? layout.nodeSpacing : 0)
        return (aggregateHeight: aggregateHeight,
                consumedNodeIndexes: consumedNodeIndexes)
    }

    /// Recursive layout.
    ///
    /// Automatically lays out nodes by working backward from a target node through wire connections.
    /// This method builds an adjacency map once for O(n + m) performance instead of O(n × m).
    ///
    /// - Parameters:
    ///   - nodeIndex: The target node to layout from.
    ///   - point: Position for the target node.
    ///   - layout: Layout constants for sizing.
    ///   - consumedNodeIndexes: Set of already-positioned nodes to skip.
    ///   - nodePadding: Whether to add spacing after this node.
    /// - Returns: Tuple of aggregate height and set of positioned nodes.
    @discardableResult
    mutating func recursiveLayout(
        nodeIndex: NodeIndex,
        at point: CGPoint,
        layout: LayoutConstants = LayoutConstants(),
        consumedNodeIndexes: Set<NodeIndex> = [],
        nodePadding: Bool = false
    ) -> (aggregateHeight: CGFloat,
          consumedNodeIndexes: Set<NodeIndex>)
    {
        // Build adjacency map once for performance
        let incomingWiresMap = buildIncomingWiresMap()

        return recursiveLayoutWithMap(
            nodeIndex: nodeIndex,
            at: point,
            layout: layout,
            consumedNodeIndexes: consumedNodeIndexes,
            nodePadding: nodePadding,
            incomingWiresMap: incomingWiresMap
        )
    }

    /// Manual stacked grid layout.
    ///
    /// - Parameters:
    ///   - origin: Top-left origin coordinate.
    ///   - columns: Array of columns each comprised of an array of node indexes.
    ///   - layout: Layout constants.
    mutating func stackedLayout(at origin: CGPoint = .zero,
                                _ columns: [[NodeIndex]],
                                layout: LayoutConstants = LayoutConstants())
    {
        for column in columns.indices {
            let nodeStack = columns[column]
            var yOffset: CGFloat = 0

            let xPos = origin.x + (CGFloat(column) * (layout.nodeWidth + layout.nodeSpacing))
            for nodeIndex in nodeStack {
                guard nodes.indices.contains(nodeIndex) else {
                    continue
                }

                nodes[nodeIndex].position = .init(
                    x: xPos,
                    y: origin.y + yOffset
                )

                let nodeHeight = nodes[nodeIndex].rect(layout: layout).height
                yOffset += nodeHeight
                if column != columns.indices.last {
                    yOffset += layout.nodeSpacing
                }
            }
        }
    }
}
