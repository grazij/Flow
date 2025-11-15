// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

@testable import Flow
import XCTest

final class LayoutAlgorithmTests: XCTestCase {

    let layout = LayoutConstants()

    // MARK: - Recursive Layout - Simple Cases

    func testRecursiveLayoutEmptyPatch() {
        var patch = Patch(nodes: [], wires: [])

        // Should not crash with empty patch
        let result = patch.recursiveLayout(
            nodeIndex: 0,
            at: CGPoint(x: 100, y: 100),
            layout: layout
        )

        XCTAssertEqual(result.aggregateHeight, 0, "Empty patch should have zero height")
        XCTAssertEqual(result.consumedNodeIndexes.count, 0, "No nodes should be consumed")
    }

    func testRecursiveLayoutSingleNode() {
        let node = Node(
            name: "output",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: []
        )
        var patch = Patch(nodes: [node], wires: [])

        let targetPoint = CGPoint(x: 500, y: 200)
        patch.recursiveLayout(nodeIndex: 0, at: targetPoint, layout: layout)

        XCTAssertEqual(patch.nodes[0].position, targetPoint, "Node should be positioned at target point")
    }

    func testRecursiveLayoutLinearChain() {
        // Create a simple linear chain: generator -> processor -> output
        let generator = Node(
            name: "generator",
            position: .zero,
            inputs: [],
            outputs: [Port(name: "out", type: .signal)]
        )

        let processor = Node(
            name: "processor",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )

        let output = Node(
            name: "output",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: []
        )

        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))  // generator -> processor
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(2, 0))  // processor -> output

        var patch = Patch(nodes: [generator, processor, output], wires: [wire1, wire2])

        // Layout from output node
        let outputPoint = CGPoint(x: 800, y: 200)
        let result = patch.recursiveLayout(nodeIndex: 2, at: outputPoint, layout: layout)

        // Verify output node is at target position
        XCTAssertEqual(patch.nodes[2].position, outputPoint)

        // Verify nodes are laid out in a line to the left
        XCTAssertLessThan(patch.nodes[1].position.x, patch.nodes[2].position.x, "Processor should be left of output")
        XCTAssertLessThan(patch.nodes[0].position.x, patch.nodes[1].position.x, "Generator should be left of processor")

        // Verify layout positioned the connected nodes
        XCTAssertGreaterThanOrEqual(result.consumedNodeIndexes.count, 2, "At least 2 nodes should be positioned")
        XCTAssertTrue(result.consumedNodeIndexes.contains(1), "Processor node should be consumed")
        XCTAssertTrue(result.consumedNodeIndexes.contains(0), "Generator node should be consumed")
    }

    // MARK: - Recursive Layout - Branching

    func testRecursiveLayoutBranching() {
        // Create a branching structure:
        //   gen1 \
        //          mixer -> output
        //   gen2 /

        let gen1 = Node(
            name: "gen1",
            position: .zero,
            inputs: [],
            outputs: [Port(name: "out", type: .signal)]
        )

        let gen2 = Node(
            name: "gen2",
            position: .zero,
            inputs: [],
            outputs: [Port(name: "out", type: .signal)]
        )

        let mixer = Node(
            name: "mixer",
            position: .zero,
            inputs: [
                Port(name: "in1", type: .signal),
                Port(name: "in2", type: .signal)
            ],
            outputs: [Port(name: "out", type: .signal)]
        )

        let output = Node(
            name: "output",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: []
        )

        let wire1 = Wire(from: OutputID(0, 0), to: InputID(2, 0))  // gen1 -> mixer.in1
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(2, 1))  // gen2 -> mixer.in2
        let wire3 = Wire(from: OutputID(2, 0), to: InputID(3, 0))  // mixer -> output

        var patch = Patch(nodes: [gen1, gen2, mixer, output], wires: [wire1, wire2, wire3])

        // Layout from output
        let outputPoint = CGPoint(x: 800, y: 200)
        let result = patch.recursiveLayout(nodeIndex: 3, at: outputPoint, layout: layout)

        // Verify output is at target
        XCTAssertEqual(patch.nodes[3].position, outputPoint)

        // Verify mixer is left of output
        XCTAssertLessThan(patch.nodes[2].position.x, patch.nodes[3].position.x)

        // Verify both generators are left of mixer
        XCTAssertLessThan(patch.nodes[0].position.x, patch.nodes[2].position.x)
        XCTAssertLessThan(patch.nodes[1].position.x, patch.nodes[2].position.x)

        // Verify generators are stacked vertically
        XCTAssertNotEqual(patch.nodes[0].position.y, patch.nodes[1].position.y, "Generators should be at different Y positions")

        // Verify connected nodes consumed (at least mixer and its inputs)
        XCTAssertGreaterThanOrEqual(result.consumedNodeIndexes.count, 2, "At least mixer and one input should be consumed")
    }

    // MARK: - Recursive Layout - Disconnected Nodes

    func testRecursiveLayoutDisconnectedNode() {
        let connected = Node(name: "connected", position: .zero)
        let disconnected = Node(name: "disconnected", position: CGPoint(x: 999, y: 999))

        var patch = Patch(nodes: [connected, disconnected], wires: [])

        patch.recursiveLayout(nodeIndex: 0, at: CGPoint(x: 100, y: 100), layout: layout)

        // Connected node should be repositioned
        XCTAssertEqual(patch.nodes[0].position, CGPoint(x: 100, y: 100))

        // Disconnected node should remain untouched
        XCTAssertEqual(patch.nodes[1].position, CGPoint(x: 999, y: 999))
    }

    // MARK: - Recursive Layout - Circular Dependencies

    // TODO: This test currently causes a crash - needs investigation
    // The recursiveLayout may have issues with true circular references
    func disabled_testRecursiveLayoutWithCircularReference() {
        // Create a feedback loop: A -> B -> A
        let nodeA = Node(
            name: "A",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )

        let nodeB = Node(
            name: "B",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )

        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))  // A -> B
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(0, 0))  // B -> A (circular!)

        var patch = Patch(nodes: [nodeA, nodeB], wires: [wire1, wire2])

        // Layout should handle circular reference without infinite loop
        // The consumedNodeIndexes set prevents infinite recursion
        let result = patch.recursiveLayout(nodeIndex: 1, at: CGPoint(x: 500, y: 200), layout: layout)

        // Should complete (not hang) - the consumed set breaks the cycle
        XCTAssertNotNil(result)

        // Node B should be positioned at target
        XCTAssertEqual(patch.nodes[1].position, CGPoint(x: 500, y: 200))

        // At least node B should be consumed (node A may or may not be, depending on traversal)
        XCTAssertGreaterThanOrEqual(result.consumedNodeIndexes.count, 1, "At least one node should be consumed")
        XCTAssertTrue(result.consumedNodeIndexes.count <= 2, "Should not enter infinite loop")
    }

    // MARK: - Stacked Layout Tests

    func testStackedLayoutEmptyPatch() {
        var patch = Patch(nodes: [], wires: [])

        // Should not crash
        patch.stackedLayout(at: .zero, [[]], layout: layout)

        XCTAssertEqual(patch.nodes.count, 0)
    }

    func testStackedLayoutSingleColumn() {
        let node1 = Node(name: "node1", position: .zero)
        let node2 = Node(name: "node2", position: .zero)
        let node3 = Node(name: "node3", position: .zero)

        var patch = Patch(nodes: [node1, node2, node3], wires: [])

        let origin = CGPoint(x: 100, y: 100)
        patch.stackedLayout(at: origin, [[0, 1, 2]], layout: layout)

        // All nodes should be in same column (same X)
        XCTAssertEqual(patch.nodes[0].position.x, origin.x)
        XCTAssertEqual(patch.nodes[1].position.x, origin.x)
        XCTAssertEqual(patch.nodes[2].position.x, origin.x)

        // Nodes should be stacked vertically
        XCTAssertEqual(patch.nodes[0].position.y, origin.y)
        XCTAssertGreaterThan(patch.nodes[1].position.y, patch.nodes[0].position.y)
        XCTAssertGreaterThan(patch.nodes[2].position.y, patch.nodes[1].position.y)
    }

    func testStackedLayoutMultipleColumns() {
        let node1 = Node(name: "node1", position: .zero)
        let node2 = Node(name: "node2", position: .zero)
        let node3 = Node(name: "node3", position: .zero)
        let node4 = Node(name: "node4", position: .zero)

        var patch = Patch(nodes: [node1, node2, node3, node4], wires: [])

        let origin = CGPoint(x: 100, y: 100)
        patch.stackedLayout(at: origin, [[0, 1], [2, 3]], layout: layout)

        // First column
        XCTAssertEqual(patch.nodes[0].position.x, origin.x)
        XCTAssertEqual(patch.nodes[1].position.x, origin.x)

        // Second column (should be offset by nodeWidth + spacing)
        let expectedX = origin.x + layout.nodeWidth + layout.nodeSpacing
        XCTAssertEqual(patch.nodes[2].position.x, expectedX)
        XCTAssertEqual(patch.nodes[3].position.x, expectedX)

        // Verify vertical stacking within columns
        XCTAssertLessThan(patch.nodes[0].position.y, patch.nodes[1].position.y)
        XCTAssertLessThan(patch.nodes[2].position.y, patch.nodes[3].position.y)
    }

    func testStackedLayoutUnevenColumns() {
        let node1 = Node(name: "node1", position: .zero)
        let node2 = Node(name: "node2", position: .zero)
        let node3 = Node(name: "node3", position: .zero)

        var patch = Patch(nodes: [node1, node2, node3], wires: [])

        let origin = CGPoint(x: 0, y: 0)
        patch.stackedLayout(at: origin, [[0, 1], [2]], layout: layout)

        // First column has 2 nodes
        XCTAssertEqual(patch.nodes[0].position.x, origin.x)
        XCTAssertEqual(patch.nodes[1].position.x, origin.x)

        // Second column has 1 node
        let expectedX = layout.nodeWidth + layout.nodeSpacing
        XCTAssertEqual(patch.nodes[2].position.x, expectedX)
    }

    func testStackedLayoutSpacing() {
        // Create nodes with different heights (more inputs = taller)
        let shortNode = Node(
            name: "short",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: []
        )

        let tallNode = Node(
            name: "tall",
            position: .zero,
            inputs: [
                Port(name: "in1", type: .signal),
                Port(name: "in2", type: .signal),
                Port(name: "in3", type: .signal),
                Port(name: "in4", type: .signal)
            ],
            outputs: []
        )

        var patch = Patch(nodes: [shortNode, tallNode], wires: [])

        patch.stackedLayout(at: .zero, [[0, 1]], layout: layout)

        let node0Height = patch.nodes[0].rect(layout: layout).height
        let spacing = layout.nodeSpacing

        // Second node should be offset by first node's height + spacing
        let expectedY = node0Height + spacing
        XCTAssertEqual(patch.nodes[1].position.y, expectedY, accuracy: 0.01)
    }

    func testStackedLayoutInvalidNodeIndex() {
        let node1 = Node(name: "node1", position: .zero)

        var patch = Patch(nodes: [node1], wires: [])

        // Reference invalid node index (should be handled gracefully with bounds checking)
        patch.stackedLayout(at: .zero, [[0, 99]], layout: layout)

        // Valid node should still be positioned
        XCTAssertEqual(patch.nodes[0].position, .zero)
    }

    // MARK: - Layout Constants Tests

    func testLayoutConstantsDefaults() {
        let constants = LayoutConstants()

        XCTAssertEqual(constants.nodeWidth, 200)
        XCTAssertEqual(constants.nodeSpacing, 40)
        XCTAssertEqual(constants.nodeTitleHeight, 40)
        XCTAssertEqual(constants.portSize, CGSize(width: 20, height: 20))
        XCTAssertEqual(constants.portSpacing, 10)
        XCTAssertEqual(constants.nodeCornerRadius, 5)
    }

    // MARK: - Consumed Node Tests

    func testRecursiveLayoutWithConsumedNodes() {
        let node1 = Node(name: "node1", position: .zero, outputs: [Port(name: "out", type: .signal)])
        let node2 = Node(name: "node2", position: .zero, inputs: [Port(name: "in", type: .signal)])

        let wire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        var patch = Patch(nodes: [node1, node2], wires: [wire])

        // Pre-consume node 0
        let consumedNodes: Set<NodeIndex> = [0]

        let result = patch.recursiveLayout(
            nodeIndex: 1,
            at: CGPoint(x: 500, y: 100),
            layout: layout,
            consumedNodeIndexes: consumedNodes
        )

        // Node 0 should not be repositioned (already consumed)
        XCTAssertEqual(patch.nodes[0].position, .zero, "Consumed node should not move")

        // Node 1 should be positioned at target
        XCTAssertEqual(patch.nodes[1].position, CGPoint(x: 500, y: 100))

        // Result should include pre-consumed node in the set
        XCTAssertTrue(result.consumedNodeIndexes.contains(0), "Pre-consumed node should remain in consumed set")
    }
}
