//
//  GeoCacheTests.swift
//  GeoCacheTests
//
//  Created by Chris Woodard on 7/26/17.
//  Copyright © 2017 UsefulSoft. All rights reserved.
//

import XCTest
@testable import GeoCache

class GeoCacheTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitDb() {
        let gc = GeoCache.sharedCache(options:["Version":"1.0"])
        XCTAssertNotNil(gc, "GC = nil?  FEH!")
        gc?.prepare()
    }
    
    func testInitDbAddData() {
        let gc = GeoCache.sharedCache(options:["Version":"1.0"])
        XCTAssertNotNil(gc, "GC = nil?  FEH!")
        gc?.prepare()
        
        let loc:[String:Any] = [
            "Name" : "Joe Blow",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        gc?.cache(loc: loc)
        
        if let items = gc?.cached() {
            let numItems = items.count
            XCTAssertEqual(numItems, 1, "Too many or too few items")
            NSLog("\(items)")
        }
        else {
            XCTFail("Nil item array")
        }
        
        gc?.dbDelete()
    }
    
    func testInitDbAddData2() {
        let gc = GeoCache.sharedCache(options:["Version":"1.0"])
        XCTAssertNotNil(gc, "GC = nil?  FEH!")
        gc?.prepare()
        
        let loc:[String:Any] = [
            "Name" : "Memorial Generator Museum",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        let loc2:[String:Any] = [
            "Name" : "Lego Art Sale",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        gc?.cache(loc: loc)
        gc?.cache(loc: loc2)

        if let items = gc?.cached() {
            let numItems = items.count
            XCTAssertEqual(numItems, 2, "Too many or too few items")
            NSLog("\(items)")
        }
        else {
            XCTFail("Nil item array")
        }
        
        gc?.dbDelete()
    }

//next, do unit tests for updating and removing locations, then
//we can bring it into the GCache app.

    func testInitDbAddDataAndUpdateFirst() {
        let gc = GeoCache.sharedCache(options:["Version":"1.0"])
        XCTAssertNotNil(gc, "GC = nil?  FEH!")
        gc?.prepare()
        
        let loc:[String:Any] = [
            "Name" : "Memorial Generator Museum",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        let loc2:[String:Any] = [
            "Name" : "Lego Art Sale",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        gc?.cache(loc: loc)
        gc?.cache(loc: loc2)

        if let items = gc?.cached() {
            let numItems = items.count
            XCTAssertEqual(numItems, 2, "Too many or too few items")
            NSLog("\(items)")
            let item1 = items[0] as [String:Any]
            if let id1 = item1["Id"] as? Int64 {
                let loc_update = [ "Name" : "Craft Beer Nirvana" ]
                gc?.update(locationId: id1, info: loc_update)
                if let items2 = gc?.cached() {
                    XCTAssertEqual(numItems, 2, "Too many or too few items")
                    NSLog("\(items2)")
                    if let name = items2[0]["Name"] as? String {
                        XCTAssertEqual("Craft Beer Nirvana", name, "Wrong name")
                    }
                }
            }
        }
        else {
            XCTFail("Nil item array")
        }
        
        gc?.dbDelete()
    }

    func testInitDbAddDataAndUpdateSecond() {
        let gc = GeoCache.sharedCache(options:["Version":"1.0"])
        XCTAssertNotNil(gc, "GC = nil?  FEH!")
        gc?.prepare()
        
        let loc:[String:Any] = [
            "Name" : "Memorial Generator Museum",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        let loc2:[String:Any] = [
            "Name" : "Lego Art Sale",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        gc?.cache(loc: loc)
        gc?.cache(loc: loc2)

        if let items = gc?.cached() {
            let numItems = items.count
            XCTAssertEqual(numItems, 2, "Too many or too few items")
            NSLog("\(items)")
            let item2 = items[1] as [String:Any]
            if let id2 = item2["Id"] as? Int64 {
                let loc_update = [ "Name" : "Craft Beer Nirvana" ]
                gc?.update(locationId: id2, info: loc_update)
                if let items2 = gc?.cached() {
                    XCTAssertEqual(numItems, 2, "Too many or too few items")
                    NSLog("\(items2)")
                    if let name = items2[1]["Name"] as? String {
                        XCTAssertEqual("Craft Beer Nirvana", name, "Wrong name")
                    }
                }
            }
        }
        else {
            XCTFail("Nil item array")
        }
        
        gc?.dbDelete()
    }

    func testInitDbAddDataAndRemoveFirst() {
        let gc = GeoCache.sharedCache(options:["Version":"1.0"])
        XCTAssertNotNil(gc, "GC = nil?  FEH!")
        gc?.prepare()
        
        let loc:[String:Any] = [
            "Name" : "Memorial Generator Museum",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        let loc2:[String:Any] = [
            "Name" : "Lego Art Sale",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        gc?.cache(loc: loc)
        gc?.cache(loc: loc2)

        if let items = gc?.cached() {
            let numItems = items.count
            XCTAssertEqual(numItems, 2, "Too many or too few items")
            NSLog("\(items)")
            let item1 = items[0] as [String:Any]
            if let id1 = item1["Id"] as? Int64 {
                gc?.delete(locationId: id1)
                //now retrieve and check this one is gone
                if let items2 = gc?.cached() {
                    XCTAssertEqual(items2.count, 1, "Too many or too few items")
                    NSLog("items2: \(items2)")
                }
            }
        }
        else {
            XCTFail("Nil item array")
        }
        
        gc?.dbDelete()
    }

    func testInitDbAddDataAndRemoveSecond() {
        let gc = GeoCache.sharedCache(options:["Version":"1.0"])
        XCTAssertNotNil(gc, "GC = nil?  FEH!")
        gc?.prepare()
        
        let loc:[String:Any] = [
            "Name" : "Memorial Generator Museum",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        let loc2:[String:Any] = [
            "Name" : "Lego Art Sale",
            "Notes" : "None",
            "Street" : "6013 N Dexter Ave",
            "City" : "Tampa",
            "State" : "FL",
            "Country" : "USA",
            "Lat" : 1.234,
            "Lon" : 5.678,
            "Timestamp" : Date()
        ]
        
        gc?.cache(loc: loc)
        gc?.cache(loc: loc2)

        if let items = gc?.cached() {
            let numItems = items.count
            XCTAssertEqual(numItems, 2, "Too many or too few items")
            NSLog("\(items)")
            let item2 = items[1] as [String:Any]
            if let id2 = item2["Id"] as? Int64 {
                gc?.delete(locationId: id2)
                //now retrieve and check this one is gone
                if let items2 = gc?.cached() {
                    XCTAssertEqual(items2.count, 1, "Too many or too few items")
                    NSLog("items2: \(items2)")
                }
            }
        }
        else {
            XCTFail("Nil item array")
        }
        
        gc?.dbDelete()
    }

}
