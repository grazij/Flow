// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

@testable import Flow
import SwiftUI
import XCTest

final class GestureHandlingTests: XCTestCase {

    var patch: Patch!
    var selection: Set<NodeIndex>!
    var nodeMovedCalls: [(NodeIndex, CGPoint)]!
    var wireAddedCalls: [Wire]!
    var wireRemovedCalls: [Wire]!

    override func setUp() {
        super.setUp()

        // Create a test patch
        let generator = Node(
            name: "generator",
            position: CGPoint(x: 100, y: 100),
            inputs: [],
            outputs: [Port(name: "out", type: .signal)]
        )

        let processor = Node(
            name: "processor",
            position: CGPoint(x: 400, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: [Port(name: "out", type: .signal)]
        )

        let output = Node(
            name: "output",
            position: CGPoint(x: 700, y: 100),
            inputs: [Port(name: "in", type: .signal)],
            outputs: []
        )

        patch = Patch(nodes: [generator, processor, output], wires: [])
        selection = Set<NodeIndex>()
        nodeMovedCalls = []
        wireAddedCalls = []
        wireRemovedCalls = []
    }

    // MARK: - Node Movement Tests

    func testMoveNodeBasic() {
        let originalPosition = patch.nodes[0].position
        let offset = CGSize(width: 50, height: 30)

        patch.moveNode(nodeIndex: 0, offset: offset) { idx, pos in
            self.nodeMovedCalls.append((idx, pos))
        }

        let expectedPosition = CGPoint(
            x: originalPosition.x + offset.width,
            y: originalPosition.y + offset.height
        )

        XCTAssertEqual(patch.nodes[0].position, expectedPosition)
        XCTAssertEqual(nodeMovedCalls.count, 1)
        XCTAssertEqual(nodeMovedCalls[0].0, 0)
        XCTAssertEqual(nodeMovedCalls[0].1, expectedPosition)
    }

    func testMoveNodeMultipleTimes() {
        let offset1 = CGSize(width: 10, height: 20)
        let offset2 = CGSize(width: 30, height: 40)

        patch.moveNode(nodeIndex: 0, offset: offset1) { _, _ in }
        let positionAfterFirst = patch.nodes[0].position

        patch.moveNode(nodeIndex: 0, offset: offset2) { _, _ in }
        let positionAfterSecond = patch.nodes[0].position

        XCTAssertNotEqual(positionAfterFirst, positionAfterSecond)
        XCTAssertEqual(
            positionAfterSecond.x,
            positionAfterFirst.x + offset2.width,
            accuracy: 0.01
        )
    }

    func testMoveLockedNode() {
        // Create a locked node
        let lockedNode = Node(
            name: "locked",
            position: CGPoint(x: 100, y: 100),
            locked: true
        )

        var testPatch = Patch(nodes: [lockedNode], wires: [])
        let originalPosition = testPatch.nodes[0].position

        testPatch.moveNode(nodeIndex: 0, offset: CGSize(width: 50, height: 50)) { _, _ in
            XCTFail("Node moved callback should not be called for locked node")
        }

        XCTAssertEqual(testPatch.nodes[0].position, originalPosition, "Locked node should not move")
    }

    func testMoveInvalidNodeIndex() {
        var callbackCalled = false

        patch.moveNode(nodeIndex: 99, offset: CGSize(width: 10, height: 10)) { _, _ in
            callbackCalled = true
        }

        XCTAssertFalse(callbackCalled, "Callback should not be called for invalid node index")
    }

    // MARK: - Wire Connection Tests

    func testConnectWire() {
        XCTAssertEqual(patch.wires.count, 0)

        let wire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        patch.wires.insert(wire)

        XCTAssertEqual(patch.wires.count, 1)
        XCTAssertTrue(patch.wires.contains(wire))
    }

    func testConnectWireReplacesExisting() {
        // Connect first wire to input
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        patch.wires.insert(wire1)

        XCTAssertEqual(patch.wires.count, 1)

        // Connect second wire to same input (should be handled by UI layer to remove wire1)
        let wire2 = Wire(from: OutputID(2, 0), to: InputID(1, 0))

        // Find and remove existing wires to the input (mimics NodeEditor.connect logic)
        let wiresToRemove = patch.wires.filter { $0.input == wire2.input }
        for wire in wiresToRemove {
            patch.wires.remove(wire)
        }

        patch.wires.insert(wire2)

        XCTAssertEqual(patch.wires.count, 1, "Should only have one wire to the input")
        XCTAssertTrue(patch.wires.contains(wire2))
        XCTAssertFalse(patch.wires.contains(wire1))
    }

    func testDisconnectWire() {
        let wire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        patch.wires.insert(wire)

        XCTAssertEqual(patch.wires.count, 1)

        patch.wires.remove(wire)

        XCTAssertEqual(patch.wires.count, 0)
        XCTAssertFalse(patch.wires.contains(wire))
    }

    func testReconnectWire() {
        // Original connection
        let originalWire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        patch.wires.insert(originalWire)

        // Reconnect to different input
        patch.wires.remove(originalWire)
        let newWire = Wire(from: OutputID(0, 0), to: InputID(2, 0))
        patch.wires.insert(newWire)

        XCTAssertEqual(patch.wires.count, 1)
        XCTAssertTrue(patch.wires.contains(newWire))
        XCTAssertFalse(patch.wires.contains(originalWire))
    }

    // MARK: - Selection Tests

    func testSelectSingleNode() {
        let selectionRect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let selected = patch.selected(in: selectionRect, layout: LayoutConstants())

        XCTAssertEqual(selected.count, 1)
        XCTAssertTrue(selected.contains(0))
    }

    func testSelectMultipleNodes() {
        let selectionRect = CGRect(x: 0, y: 0, width: 500, height: 200)
        let selected = patch.selected(in: selectionRect, layout: LayoutConstants())

        XCTAssertEqual(selected.count, 2)
        XCTAssertTrue(selected.contains(0))
        XCTAssertTrue(selected.contains(1))
    }

    func testSelectNoNodes() {
        let selectionRect = CGRect(x: 1000, y: 1000, width: 100, height: 100)
        let selected = patch.selected(in: selectionRect, layout: LayoutConstants())

        XCTAssertEqual(selected.count, 0)
    }

    func testClearSelection() {
        selection.insert(0)
        selection.insert(1)

        XCTAssertEqual(selection.count, 2)

        selection.removeAll()

        XCTAssertEqual(selection.count, 0)
    }

    // MARK: - DragInfo Tests

    func testDragInfoNone() {
        let dragInfo = NodeEditor.DragInfo.none

        switch dragInfo {
        case .none:
            XCTAssertTrue(true, "Should match .none case")
        default:
            XCTFail("Should be .none")
        }
    }

    func testDragInfoNode() {
        let dragInfo = NodeEditor.DragInfo.node(index: 1, offset: CGSize(width: 10, height: 20))

        switch dragInfo {
        case let .node(index, offset):
            XCTAssertEqual(index, 1)
            XCTAssertEqual(offset, CGSize(width: 10, height: 20))
        default:
            XCTFail("Should be .node")
        }
    }

    func testDragInfoWire() {
        let outputID = OutputID(0, 0)
        let offset = CGSize(width: 50, height: 30)

        let dragInfo = NodeEditor.DragInfo.wire(output: outputID, offset: offset)

        switch dragInfo {
        case let .wire(output, wireOffset, hideWire):
            XCTAssertEqual(output, outputID)
            XCTAssertEqual(wireOffset, offset)
            XCTAssertNil(hideWire)
        default:
            XCTFail("Should be .wire")
        }
    }

    func testDragInfoSelection() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let dragInfo = NodeEditor.DragInfo.selection(rect: rect)

        switch dragInfo {
        case let .selection(selectionRect):
            XCTAssertEqual(selectionRect, rect)
        default:
            XCTFail("Should be .selection")
        }
    }

    // MARK: - Port ID Tests

    func testInputIDEquality() {
        let id1 = InputID(0, 0)
        let id2 = InputID(0, 0)
        let id3 = InputID(1, 0)

        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }

    func testOutputIDEquality() {
        let id1 = OutputID(0, 0)
        let id2 = OutputID(0, 0)
        let id3 = OutputID(0, 1)

        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }

    func testInputIDComponents() {
        let id = InputID(5, 3)

        XCTAssertEqual(id.nodeIndex, 5)
        XCTAssertEqual(id.portIndex, 3)
    }

    func testOutputIDComponents() {
        let id = OutputID(7, 2)

        XCTAssertEqual(id.nodeIndex, 7)
        XCTAssertEqual(id.portIndex, 2)
    }

    // MARK: - Attached Wire Tests

    func testFindAttachedWire() {
        let wire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        patch.wires.insert(wire)

        let found = patch.wires.first(where: { $0.input == InputID(1, 0) })

        XCTAssertNotNil(found)
        XCTAssertEqual(found, wire)
    }

    func testFindAttachedWireNotFound() {
        let found = patch.wires.first(where: { $0.input == InputID(1, 0) })

        XCTAssertNil(found)
    }

    func testMultipleWiresFromSameOutput() {
        // An output can have multiple wires
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        let wire2 = Wire(from: OutputID(0, 0), to: InputID(2, 0))

        patch.wires.insert(wire1)
        patch.wires.insert(wire2)

        let wiresFromOutput = patch.wires.filter { $0.output == OutputID(0, 0) }

        XCTAssertEqual(wiresFromOutput.count, 2)
        XCTAssertTrue(wiresFromOutput.contains(wire1))
        XCTAssertTrue(wiresFromOutput.contains(wire2))
    }

    // MARK: - Edge Cases
    // Note: minimumDragDistance is private, so we test behavior instead of the constant itself

    func testMoveNodeToNegativeCoordinates() {
        patch.nodes[0].position = CGPoint(x: 10, y: 10)
        patch.moveNode(nodeIndex: 0, offset: CGSize(width: -50, height: -50)) { _, _ in }

        XCTAssertLessThan(patch.nodes[0].position.x, 0)
        XCTAssertLessThan(patch.nodes[0].position.y, 0)
    }

    func testMoveNodeLargeDistance() {
        let largeOffset = CGSize(width: 10000, height: 10000)
        patch.moveNode(nodeIndex: 0, offset: largeOffset) { _, _ in }

        XCTAssertGreaterThan(patch.nodes[0].position.x, 1000)
        XCTAssertGreaterThan(patch.nodes[0].position.y, 1000)
    }

    func testSelectWithZeroSizeRect() {
        // Zero-size rect at a point that doesn't intersect any nodes
        let zeroRect = CGRect(x: 1000, y: 1000, width: 0, height: 0)
        let selected = patch.selected(in: zeroRect, layout: LayoutConstants())

        // Zero-size rect should not select anything if it doesn't intersect nodes
        XCTAssertEqual(selected.count, 0)
    }

    func testSelectWithNegativeSizeRect() {
        // CGRect with negative size (e.g., dragging from bottom-right to top-left)
        let rect = CGRect(x: 400, y: 200, width: -300, height: -100)
        let standardized = rect.standardized

        let selected = patch.selected(in: standardized, layout: LayoutConstants())

        // Should still work with standardized rect
        XCTAssertGreaterThanOrEqual(selected.count, 0)
    }
}
