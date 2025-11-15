// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

@testable import Flow
import XCTest

final class HitTestingTests: XCTestCase {

    let layout = LayoutConstants()

    // MARK: - Empty Patch Tests

    func testHitTestEmptyPatch() {
        let emptyPatch = Patch(nodes: [], wires: [])
        let result = emptyPatch.hitTest(point: CGPoint(x: 100, y: 100), layout: layout)

        XCTAssertNil(result, "Hit test on empty patch should return nil")
    }

    func testFindInputInEmptyPatch() {
        let emptyPatch = Patch(nodes: [], wires: [])

        // This should not crash
        let inputs = emptyPatch.nodes.enumerated().compactMap { nodeIndex, node -> InputID? in
            node.inputs.enumerated().first { portIndex, input in
                input.type == .signal && node.inputRect(input: portIndex, layout: layout).contains(CGPoint(x: 100, y: 100))
            }.map { InputID(nodeIndex, $0.offset) }
        }

        XCTAssertEqual(inputs.count, 0, "Empty patch should have no inputs")
    }

    // MARK: - Single Node Tests

    func testHitTestSingleNode() {
        let node = Node(
            name: "processor",
            position: CGPoint(x: 100, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )
        let patch = Patch(nodes: [node], wires: [])

        // Hit the node body
        let nodeRect = node.rect(layout: layout)
        let centerPoint = CGPoint(
            x: nodeRect.origin.x + nodeRect.width / 2,
            y: nodeRect.origin.y + nodeRect.height / 2
        )

        let result = patch.hitTest(point: centerPoint, layout: layout)

        XCTAssertNotNil(result)
        if case let .node(nodeIndex) = result {
            XCTAssertEqual(nodeIndex, 0)
        } else {
            XCTFail("Expected node hit result")
        }
    }

    func testHitTestInputPort() {
        let node = Node(
            name: "processor",
            position: CGPoint(x: 100, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )
        let patch = Patch(nodes: [node], wires: [])

        // Hit the input port
        let inputRect = node.inputRect(input: 0, layout: layout)
        let inputCenter = CGPoint(
            x: inputRect.origin.x + inputRect.width / 2,
            y: inputRect.origin.y + inputRect.height / 2
        )

        let result = patch.hitTest(point: inputCenter, layout: layout)

        XCTAssertNotNil(result)
        if case let .input(nodeIndex, portIndex) = result {
            XCTAssertEqual(nodeIndex, 0)
            XCTAssertEqual(portIndex, 0)
        } else {
            XCTFail("Expected input port hit result")
        }
    }

    func testHitTestOutputPort() {
        let node = Node(
            name: "processor",
            position: CGPoint(x: 100, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )
        let patch = Patch(nodes: [node], wires: [])

        // Hit the output port
        let outputRect = node.outputRect(output: 0, layout: layout)
        let outputCenter = CGPoint(
            x: outputRect.origin.x + outputRect.width / 2,
            y: outputRect.origin.y + outputRect.height / 2
        )

        let result = patch.hitTest(point: outputCenter, layout: layout)

        XCTAssertNotNil(result)
        if case let .output(nodeIndex, portIndex) = result {
            XCTAssertEqual(nodeIndex, 0)
            XCTAssertEqual(portIndex, 0)
        } else {
            XCTFail("Expected output port hit result")
        }
    }

    func testHitTestMissNode() {
        let node = Node(
            name: "processor",
            position: CGPoint(x: 100, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )
        let patch = Patch(nodes: [node], wires: [])

        // Hit outside the node
        let result = patch.hitTest(point: CGPoint(x: 1000, y: 1000), layout: layout)

        XCTAssertNil(result, "Hit test outside node should return nil")
    }

    // MARK: - Overlapping Nodes Tests

    func testHitTestOverlappingNodes() {
        // Create two overlapping nodes
        let node1 = Node(
            name: "node1",
            position: CGPoint(x: 100, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )

        let node2 = Node(
            name: "node2",
            position: CGPoint(x: 150, y: 150),  // Overlaps with node1
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )

        let patch = Patch(nodes: [node1, node2], wires: [])

        // Hit the overlapping region
        let overlapPoint = CGPoint(x: 200, y: 200)

        let result = patch.hitTest(point: overlapPoint, layout: layout)

        // Should hit node2 (last in array, drawn on top)
        XCTAssertNotNil(result)
        if case let .node(nodeIndex) = result {
            XCTAssertEqual(nodeIndex, 1, "Should hit the topmost (last) node")
        } else {
            XCTFail("Expected node hit result")
        }
    }

    // MARK: - Multiple Port Tests

    func testHitTestMultipleInputs() {
        let node = Node(
            name: "mixer",
            position: CGPoint(x: 100, y: 100),
            inputs: [
                Port(name: "in1", type: .signal),
                Port(name: "in2", type: .signal),
                Port(name: "in3", type: .signal)
            ],
            outputs: [Port(name: "out", type: .signal)]
        )
        let patch = Patch(nodes: [node], wires: [])

        // Test hitting each input port
        for portIndex in 0..<3 {
            let inputRect = node.inputRect(input: portIndex, layout: layout)
            let inputCenter = CGPoint(
                x: inputRect.origin.x + inputRect.width / 2,
                y: inputRect.origin.y + inputRect.height / 2
            )

            let result = patch.hitTest(point: inputCenter, layout: layout)

            XCTAssertNotNil(result)
            if case let .input(nodeIndex, hitPortIndex) = result {
                XCTAssertEqual(nodeIndex, 0)
                XCTAssertEqual(hitPortIndex, portIndex, "Should hit port \(portIndex)")
            } else {
                XCTFail("Expected input port hit result for port \(portIndex)")
            }
        }
    }

    func testHitTestMultipleOutputs() {
        let node = Node(
            name: "splitter",
            position: CGPoint(x: 100, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: [
                Port(name: "out1", type: .signal),
                Port(name: "out2", type: .signal),
                Port(name: "out3", type: .signal)
            ]
        )
        let patch = Patch(nodes: [node], wires: [])

        // Test hitting each output port
        for portIndex in 0..<3 {
            let outputRect = node.outputRect(output: portIndex, layout: layout)
            let outputCenter = CGPoint(
                x: outputRect.origin.x + outputRect.width / 2,
                y: outputRect.origin.y + outputRect.height / 2
            )

            let result = patch.hitTest(point: outputCenter, layout: layout)

            XCTAssertNotNil(result)
            if case let .output(nodeIndex, hitPortIndex) = result {
                XCTAssertEqual(nodeIndex, 0)
                XCTAssertEqual(hitPortIndex, portIndex, "Should hit port \(portIndex)")
            } else {
                XCTFail("Expected output port hit result for port \(portIndex)")
            }
        }
    }

    // MARK: - Node Selection Tests

    func testSelectNodesInRect() {
        let node1 = Node(name: "node1", position: CGPoint(x: 100, y: 100))
        let node2 = Node(name: "node2", position: CGPoint(x: 400, y: 100))
        let node3 = Node(name: "node3", position: CGPoint(x: 700, y: 100))

        let patch = Patch(nodes: [node1, node2, node3], wires: [])

        // Select nodes 0 and 1
        let selectionRect = CGRect(x: 0, y: 0, width: 500, height: 300)
        let selected = patch.selected(in: selectionRect, layout: layout)

        XCTAssertEqual(selected.count, 2, "Should select 2 nodes")
        XCTAssertTrue(selected.contains(0))
        XCTAssertTrue(selected.contains(1))
        XCTAssertFalse(selected.contains(2))
    }

    func testSelectNoNodesInRect() {
        let node = Node(name: "node", position: CGPoint(x: 100, y: 100))
        let patch = Patch(nodes: [node], wires: [])

        // Selection rect that doesn't intersect any nodes
        let selectionRect = CGRect(x: 500, y: 500, width: 100, height: 100)
        let selected = patch.selected(in: selectionRect, layout: layout)

        XCTAssertEqual(selected.count, 0, "Should select no nodes")
    }

    func testSelectAllNodesInRect() {
        let node1 = Node(name: "node1", position: CGPoint(x: 100, y: 100))
        let node2 = Node(name: "node2", position: CGPoint(x: 400, y: 100))

        let patch = Patch(nodes: [node1, node2], wires: [])

        // Large selection rect covering everything
        let selectionRect = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let selected = patch.selected(in: selectionRect, layout: layout)

        XCTAssertEqual(selected.count, 2, "Should select all nodes")
        XCTAssertTrue(selected.contains(0))
        XCTAssertTrue(selected.contains(1))
    }

    // MARK: - Edge Case Tests

    func testHitTestAtOrigin() {
        let node = Node(name: "node", position: .zero)
        let patch = Patch(nodes: [node], wires: [])

        // Test point within the node's rect (node is at origin with default size 200x80)
        let nodeRect = node.rect(layout: layout)
        let testPoint = CGPoint(
            x: nodeRect.origin.x + nodeRect.width / 2,
            y: nodeRect.origin.y + nodeRect.height / 2
        )

        let result = patch.hitTest(point: testPoint, layout: layout)

        XCTAssertNotNil(result, "Should be able to hit test node at origin")
    }

    func testHitTestNegativeCoordinates() {
        let node = Node(name: "node", position: CGPoint(x: -100, y: -100))
        let patch = Patch(nodes: [node], wires: [])

        let nodeRect = node.rect(layout: layout)
        let centerPoint = CGPoint(
            x: nodeRect.origin.x + nodeRect.width / 2,
            y: nodeRect.origin.y + nodeRect.height / 2
        )

        let result = patch.hitTest(point: centerPoint, layout: layout)

        XCTAssertNotNil(result, "Should handle negative coordinates")
    }

    func testHitTestLargeCoordinates() {
        let node = Node(name: "node", position: CGPoint(x: 10000, y: 10000))
        let patch = Patch(nodes: [node], wires: [])

        let nodeRect = node.rect(layout: layout)
        let centerPoint = CGPoint(
            x: nodeRect.origin.x + nodeRect.width / 2,
            y: nodeRect.origin.y + nodeRect.height / 2
        )

        let result = patch.hitTest(point: centerPoint, layout: layout)

        XCTAssertNotNil(result, "Should handle large coordinates")
    }
}
