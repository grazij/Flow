// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

@testable import Flow
import XCTest

final class WireConnectionTests: XCTestCase {

    var patch: Patch!

    override func setUp() {
        super.setUp()

        // Create a simple patch with three nodes: generator -> processor -> output
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
    }

    // MARK: - Wire Creation Tests

    func testCreateWire() {
        XCTAssertEqual(patch.wires.count, 0, "Patch should start with no wires")

        let wire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        patch.wires.insert(wire)

        XCTAssertEqual(patch.wires.count, 1, "Patch should have one wire")
        XCTAssertTrue(patch.wires.contains(wire), "Patch should contain the created wire")
    }

    func testCreateMultipleWires() {
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(2, 0))

        patch.wires.insert(wire1)
        patch.wires.insert(wire2)

        XCTAssertEqual(patch.wires.count, 2, "Patch should have two wires")
        XCTAssertTrue(patch.wires.contains(wire1))
        XCTAssertTrue(patch.wires.contains(wire2))
    }

    func testWireEquality() {
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        let wire2 = Wire(from: OutputID(0, 0), to: InputID(1, 0))

        XCTAssertEqual(wire1, wire2, "Wires with same endpoints should be equal")
    }

    // MARK: - Wire Removal Tests

    func testRemoveWire() {
        let wire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        patch.wires.insert(wire)

        XCTAssertEqual(patch.wires.count, 1)

        patch.wires.remove(wire)

        XCTAssertEqual(patch.wires.count, 0, "Wire should be removed")
        XCTAssertFalse(patch.wires.contains(wire))
    }

    func testRemoveNonexistentWire() {
        let wire = Wire(from: OutputID(0, 0), to: InputID(1, 0))

        patch.wires.remove(wire)

        XCTAssertEqual(patch.wires.count, 0, "Removing nonexistent wire should not crash")
    }

    // MARK: - Multiple Wires to Same Input Tests

    func testMultipleWiresToSameInput() {
        // This tests the behavior where an input can only have one wire connected
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(1, 0)) // Different output, same input

        patch.wires.insert(wire1)
        XCTAssertEqual(patch.wires.count, 1)

        // When adding wire2, wire1 should be replaced (in the UI logic)
        // The data model allows both, but UI should enforce single input connection
        patch.wires.insert(wire2)

        XCTAssertEqual(patch.wires.count, 2, "Data model allows multiple wires to same input")

        // Filter to find wires connected to input (1, 0)
        let wirestoInput = patch.wires.filter { $0.input == InputID(1, 0) }
        XCTAssertEqual(wirestoInput.count, 2, "Both wires target the same input")
    }

    func testFindWireByInput() {
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(2, 0))

        patch.wires.insert(wire1)
        patch.wires.insert(wire2)

        let foundWire = patch.wires.first(where: { $0.input == InputID(1, 0) })
        XCTAssertNotNil(foundWire)
        XCTAssertEqual(foundWire, wire1)
    }

    func testFindWireByOutput() {
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(2, 0))

        patch.wires.insert(wire1)
        patch.wires.insert(wire2)

        let foundWire = patch.wires.first(where: { $0.output == OutputID(1, 0) })
        XCTAssertNotNil(foundWire)
        XCTAssertEqual(foundWire, wire2)
    }

    // MARK: - Invalid Connection Tests

    func testWireToNonexistentNode() {
        // Wire referencing invalid node indices
        let invalidWire = Wire(from: OutputID(99, 0), to: InputID(1, 0))

        patch.wires.insert(invalidWire)
        XCTAssertEqual(patch.wires.count, 1, "Data model allows invalid wires")

        // Verify safe access would handle this
        XCTAssertNil(patch.nodes[safe: 99], "Safe subscript should return nil for invalid index")
    }

    func testWireToNonexistentPort() {
        // Wire referencing invalid port indices
        let invalidWire = Wire(from: OutputID(0, 99), to: InputID(1, 0))

        patch.wires.insert(invalidWire)
        XCTAssertEqual(patch.wires.count, 1, "Data model allows invalid port references")

        let node = patch.nodes[safe: 0]
        XCTAssertNotNil(node)
        XCTAssertNil(node?.outputs[safe: 99], "Safe subscript should return nil for invalid port")
    }

    // MARK: - Wire Type Tests

    func testWireBetweenDifferentTypes() {
        // Create nodes with different port types
        let midiNode = Node(
            name: "midi",
            position: .zero,
            inputs: [],
            outputs: [Port(name: "midi", type: .midi)]
        )

        let signalNode = Node(
            name: "signal",
            position: .zero,
            inputs: [Port(name: "in", type: .signal)],
            outputs: []
        )

        var testPatch = Patch(nodes: [midiNode, signalNode], wires: [])

        // Data model allows mismatched types
        let mismatchedWire = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        testPatch.wires.insert(mismatchedWire)

        XCTAssertEqual(testPatch.wires.count, 1, "Data model allows type-mismatched wires")
        // Note: Type validation should be enforced in the UI layer
    }

    // MARK: - Bulk Operations Tests

    func testClearAllWires() {
        patch.wires.insert(Wire(from: OutputID(0, 0), to: InputID(1, 0)))
        patch.wires.insert(Wire(from: OutputID(1, 0), to: InputID(2, 0)))

        XCTAssertEqual(patch.wires.count, 2)

        patch.wires.removeAll()

        XCTAssertEqual(patch.wires.count, 0, "All wires should be removed")
    }

    func testFilterWiresByNode() {
        let wire1 = Wire(from: OutputID(0, 0), to: InputID(1, 0))
        let wire2 = Wire(from: OutputID(1, 0), to: InputID(2, 0))
        let wire3 = Wire(from: OutputID(0, 0), to: InputID(2, 0))

        patch.wires.insert(wire1)
        patch.wires.insert(wire2)
        patch.wires.insert(wire3)

        // Find all wires connected to node 0
        let node0Wires = patch.wires.filter {
            $0.output.nodeIndex == 0 || $0.input.nodeIndex == 0
        }

        XCTAssertEqual(node0Wires.count, 2, "Node 0 should have 2 connected wires")
    }
}
