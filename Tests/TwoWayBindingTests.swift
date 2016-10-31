//
//  UpdatableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

class UpdatableTests: XCTestCase {

    func test_bind_OneWayBinding() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(100)

        let c = master.connect(to: slave)

        XCTAssertEqual(slave.value, 0)

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 200

        XCTAssertEqual(master.value, 1, "Connection should not be a two-way binding")
        XCTAssertEqual(slave.value, 200)

        master.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        c.disconnect()

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)
    }

    func test_bind_TwoWayBinding() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let c = master.bind(to: slave)

        XCTAssertEqual(master.value, 0) // Slave should get the value of master
        XCTAssertEqual(slave.value, 0)

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        c.disconnect() // The variables should now be independent again.

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)
        
        slave.value = 4
        
        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 4)
    }

    func test_Connector_bind() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let connector = Connector()
        connector.bind(master, to: slave)

        XCTAssertEqual(master.value, 0) // Slave should get the value of master
        XCTAssertEqual(slave.value, 0)

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        connector.disconnect() // The variables should now be independent again.

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)

        slave.value = 4

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 4)

    }
}