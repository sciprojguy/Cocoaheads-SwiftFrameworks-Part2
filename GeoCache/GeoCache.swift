//
//  GeoCache.swift
//  GeoCache
//
//  Created by Chris Woodard on 7/26/17.
//  Copyright © 2017 UsefulSoft. All rights reserved.
//

import Foundation
import sqlite3

typealias SQLite3Function = @convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void

@objc public enum CacheStatus:Int {
    case NoError = 0
    case SqlError = 1
    case NoSuchEntity = 2
}

//now add the extern methods
@objc public class GeoCache : NSObject {
    
    //MARK: - Swift singleton hip-hop

    private static var gc:GeoCache? = nil
    private let versions:[String] = ["1.0"]
    private var cachePath:String = ""
    
    public static func sharedCache(options:[String:Any]) -> GeoCache? {
        if nil == gc {
            gc = GeoCache()
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
            gc?.cachePath = "\(paths[0])/GeoCache.db"
        }
        return gc
    }
    
    public static  func sharedCache() -> GeoCache? {
        return gc
    }
    
    private override init() {
    }
    
    //MARK: - open/close db
        //open db
    func dbOpen() -> OpaquePointer? {
        var db:OpaquePointer? = nil
        var result = sqlite3_open(self.cachePath as String, &db)
        return db
    }
    
    //close db
    func dbClose(db:OpaquePointer) -> Int32 {
        let result = sqlite3_close(db)
        return result
    }

    //delete db - for unit testing
    public func dbDelete() {
        try! FileManager.default.removeItem(atPath: self.cachePath)
    }
    
    //MARK: - create/migrate
/* --------------------------------------------------------------------------------
    This is code to implement creating Errands.db with scripts and migrate it from 
    an old to a new schema when feature changes require db changes.  It's designed 
    to update the db in place so the user doesn't lose cached data.
    
    This works by maintaining two different types of version-specific SQL scripts:  
    
        create_X.Y 
        migrate_X.Y_X.Y
     
    and figuring out, at runtime, which one to use.
   -------------------------------------------------------------------------------- */

    //return pairs of migration versions so we can migrate 1.0-1.1, then 1.1-1.2 instead of
    //having to maintain an upper triangular matrix of version combinations for migrating.
    func migrationPairs(from:String, to:String) -> [(String, String)] {

        var pairs:[(String,String)] = []
        
        guard let iFrom = versions.index(of: from), let iTo = versions.index(of: to)
        else {
            return pairs
        }
        
        guard iFrom < iTo
        else {
            return pairs
        }
        
        let versionSlice = versions[iFrom...iTo]
        var prevVersion:String? = nil
        var pair:(String, String) = (from, "")
        for version in versionSlice {
            if let pv = prevVersion {
                if(pv != from) {
                    pairs.append(pair)
                }
                pair.0 = pv
            }
            pair.1 = version
            prevVersion = version
        }
        pairs.append(pair)
        return pairs
    }

/* --------------------------------------------------------------------------------
    This loads and parses one of the SQL scripts in the app bundle.  It returns an
    array of strings, each string containing a SQL statement or command.
   -------------------------------------------------------------------------------- */
    func sqlContents(name:String) -> [String?]? {
        var sqlText:[String]? = nil
        
        let p = Bundle(for: self.classForCoder)
        if let sqlPath = p.path(forResource: name, ofType: "sql") {
            do {
                let sqlRawText = try String(contentsOfFile: sqlPath)
                sqlText = sqlRawText.components(separatedBy: ";")
            }
            catch {
                //todo: log error
            }
        }
        return sqlText
    }
    
/* --------------------------------------------------------------------------------
    This constructs a "create_X.y" script name so that the contents of a specific
    creation script can be loaded.
   -------------------------------------------------------------------------------- */
	func creationSQL(version:String) -> [String?]? {
		return sqlContents(name: "create_\(version)")
	}
    
/* --------------------------------------------------------------------------------
    This constructs a "migrate_<version>_<version> to load a script that has the
    SQL statements and commands needed to modify the schema and rows from an older
    version to the current version.
   -------------------------------------------------------------------------------- */
    func migrationSQL(from:String, to:String) -> [String?]? {
        return sqlContents(name: "migrate_\(from)_\(to)")
    }
    
/* --------------------------------------------------------------------------------
    This creates the database schema for a given version.
   -------------------------------------------------------------------------------- */
	func createDb(db:OpaquePointer, version:String) -> CacheStatus {
        var err:CacheStatus = .NoError
        if let sqlStatments = creationSQL(version: version) {
            for sqlStmt in sqlStatments {
                if let stmt = sqlStmt {
                    var e:UnsafeMutablePointer<Int8>? = nil
                    let result = sqlite3_exec(db, stmt, nil, nil, &e)
                    if SQLITE_OK != result {
                        if nil != e {
                            let str = String(cString: e!)
                            print(str)
                        }
                        
                        err = .SqlError
                    }
                }
            }
        }
        else {
            err = .SqlError
        }

        return err
	}
		
/* --------------------------------------------------------------------------------
    This migrates the db, in place, from an old version to a newer version by generating
    a pairwise version list and migrating that way
   -------------------------------------------------------------------------------- */
    //migrate db from old to new schema version
    func migrateDb(db:OpaquePointer, from:String, to:String) -> CacheStatus {

        var err:CacheStatus = .NoError
        var result:Int32 = SQLITE_OK
        
        result = sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil )
        let pairs = self.migrationPairs(from: from, to: to)
        for versionPair in pairs {
            if let sqlStatments = migrationSQL(from: versionPair.0, to: versionPair.1) {
                for sqlStmt in sqlStatments {
                    result = sqlite3_exec(db, sqlStmt, nil, nil, nil)
                    if SQLITE_OK != result {
                        let errStr = String(cString: sqlite3_errstr(result))
                        print("Error: \(errStr)")
                        err = .SqlError
                        break
                    }
                }
            }
            else {
                err = .SqlError
                break
            }
        }
        
        if case .SqlError = err {
            result = sqlite3_exec(db, "ROLLBACK", nil, nil, nil )
        }
        else {
            result = sqlite3_exec(db, "COMMIT", nil, nil, nil )
        }
        
        return err
    }
    
    
/* --------------------------------------------------------------------------------
    This returns the version in the db.
   -------------------------------------------------------------------------------- */
	func cachedVersion(db:OpaquePointer) -> String? {
        var version:String? = nil
        var stmt:OpaquePointer? = nil
        
        var result = sqlite3_prepare_v2(db, "SELECT version from Version", -1, &stmt, nil)
        if SQLITE_OK == result {
            result = sqlite3_step(stmt)
            if SQLITE_ROW == result {
                if let rawTxt = sqlite3_column_text(stmt, 0) {
                    version = String(cString:rawTxt)
                }
            }
            sqlite3_finalize(stmt)
        }
        return version
    }

/* --------------------------------------------------------------------------------
    This method gets called after the first time we allocate the singleton.  It 
    compares the cached version against the current version (last node in the
    version history array) and decides whether the db needs to be created or
    migrated from an existing schema version.
   -------------------------------------------------------------------------------- */
	public func prepare() -> CacheStatus {
        var err:CacheStatus = .NoError
        if let db = dbOpen() {
            if let currentVersion = self.versions.last {
                if let cachedVersion = self.cachedVersion(db:db) {
                    if cachedVersion != currentVersion {
                        // if cached version doesn't match current version, we need to migrate it
                        err = self.migrateDb(db:db, from: cachedVersion, to: currentVersion)
                    }
                }
                else {
                    // if cached version came back nil, we assume db doesn't exist and create it
                    // with current version
                    err = self.createDb(db:db, version: currentVersion)
                }
            }
        }
        return err
	}

    //MARK: - locations
    
    public func cache(loc:[String:Any]) -> CacheStatus {
		var err:CacheStatus = .NoError
        var changes:Int = 0
        var lastInsertId:Int64 = -1
        
        if let db = dbOpen() {
        
            let colNames = Array<String>(loc.keys)
            var colValues = [String]()
            let fmtr = DateFormatter()
            fmtr.dateFormat = "yyyy-MM-dd'T'hh:mm:SS"
            for colName in colNames {
                switch colName {
                    case "Name", "Notes", "Street", "City", "State", "Country", "Area":
                        colValues.append("'\(loc[colName]!)'")
                    case "Lat", "Lon":
                        colValues.append("\(loc[colName]!)")
                    case "Timestamp":
                        //todo: switch this to using a time interval to store it instead
                        //of a string that requires extra parsing
                        let str = fmtr.string(from: loc[colName] as! Date)
                        colValues.append("'\(str)'")
                        break
                    default:
                        break
                }
                
            }
            
            let colNameStr = colNames.joined(separator: ",")
            let colValsStr = colValues.joined(separator: ",")
            let sql = "INSERT INTO GeoCache ("+colNameStr+") VALUES("+colValsStr+")"
            
            var errStr:UnsafeMutablePointer<Int8>? = nil
            var result = sqlite3_exec(db, sql, nil, nil, &errStr)
            if nil != errStr {
                let s = String(cString:errStr!)
                print("\(s)")
            }
//            var retryCount:Int = 0
//            while SQLITE_BUSY == result && retryCount < 10 {
//                sleep(1)
//                retryCount += 1
//                result = sqlite3_exec(db, sql, nil, nil, nil)
//            }
            
            if SQLITE_OK != result {
                err = .SqlError
            }
            else {
                changes = Int(sqlite3_changes(db))
                lastInsertId = sqlite3_last_insert_rowid(db)
            }
            
            _ = self.dbClose(db: db)
        
        }
        
        return err
    }
    
    public func cached() -> [[String:Any]]? {
		var err:CacheStatus = .NoError
        var locations:[[String:Any]] = []
        
        if let db = dbOpen() {
        
            let sql = "SELECT Id, Name, Street, City, State, Area, Country, Lat, Lon, Timestamp FROM GeoCache ORDER BY Timestamp DESC"
            
            var stmt:OpaquePointer? = nil
            var result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            
            var retryCount:Int = 0
            while SQLITE_BUSY == result && retryCount < 15 {
                sleep(1)
                retryCount += 1
                result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            }
            
            if SQLITE_OK == result {
                result = sqlite3_step(stmt)
                while SQLITE_ROW == result {
                
                    let rowId:Int64 = sqlite3_column_int64(stmt, 0)
                    let lat = sqlite3_column_double(stmt, 7)
                    let lon = sqlite3_column_double(stmt, 8)
                    
                    var name = ""
                    if let str = sqlite3_column_text(stmt, 1) {
                        name = String(cString:str)
                    }

                    var street = ""
                    if let str = sqlite3_column_text(stmt, 2) {
                        street = String(cString:str)
                    }

                    var city = ""
                    if let str = sqlite3_column_text(stmt, 3) {
                        city = String(cString:str)
                    }

                    var state = ""
                    if let str = sqlite3_column_text(stmt, 4) {
                        state = String(cString:str)
                    }

                    var area = ""
                    if let str = sqlite3_column_text(stmt, 5) {
                        area = String(cString:str)
                    }

                    var country = ""
                    if let str = sqlite3_column_text(stmt, 6) {
                        country = String(cString:str)
                    }
                    
                    let d = Date(timeIntervalSince1970: sqlite3_column_double(stmt,9))
                    
                    let loc:[String:Any] = [
                        "Id" : rowId,
                        "Lat" : lat,
                        "Lon" : lon,
                        "Name" : name,
                        "Timestamp" : d,
                        "Address" : "\(street), \(city) \(state) \(country)"
                    ]
                    
                    locations.append(loc)
                    
                    result = sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            
            self.dbClose(db: db)
        }
        
        return locations
    }
    
    public func cached(_ tags:[String], from:Date?, to:Date?) -> [[String:Any]]? {
		var err:CacheStatus = .NoError
        var locations:[[String:Any]] = []
        
        if let db = dbOpen() {
            
            var whereClauses:[String] = []
            
            var whereClause = ""
            if tags.count > 0 {
                let quotedTags = tags.map {return "'" + $0 + "'"}.joined(separator: ",")
                whereClauses.append("Id IN (SELECT Id FROM Tags WHERE Tag IN (\(quotedTags)))")
            }
            
//            if let fromDate = from {
//                whereClauses.append("Timestamp < date expression")
//            }
//            
//            if let toDate = to {
//                whereClauses.append("Timestamp < date expression")
//            }
            
            whereClause = whereClauses.joined(separator: " AND ")
            
            let sql = "SELECT Id, Name, Street, City, State, Area, Country, Lat, Lon, Timestamp FROM GeoCache \(whereClause) ORDER BY Timestamp DESC"
            
            var stmt:OpaquePointer? = nil
            var result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            
            var retryCount:Int = 0
            while SQLITE_BUSY == result && retryCount < 15 {
                sleep(1)
                retryCount += 1
                result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            }
            
            if SQLITE_OK == result {
                result = sqlite3_step(stmt)
                while SQLITE_ROW == result {
                
                    let rowId:Int64 = sqlite3_column_int64(stmt, 0)
                    let lat = sqlite3_column_double(stmt, 7)
                    let lon = sqlite3_column_double(stmt, 8)
                    
                    var name = ""
                    if let str = sqlite3_column_text(stmt, 1) {
                        name = String(cString:str)
                    }

                    var street = ""
                    if let str = sqlite3_column_text(stmt, 2) {
                        street = String(cString:str)
                    }

                    var city = ""
                    if let str = sqlite3_column_text(stmt, 3) {
                        city = String(cString:str)
                    }

                    var state = ""
                    if let str = sqlite3_column_text(stmt, 4) {
                        state = String(cString:str)
                    }

                    var area = ""
                    if let str = sqlite3_column_text(stmt, 5) {
                        area = String(cString:str)
                    }

                    var country = ""
                    if let str = sqlite3_column_text(stmt, 6) {
                        country = String(cString:str)
                    }
                    
                    let d = Date(timeIntervalSince1970: sqlite3_column_double(stmt,9))
                    
                    //todo: add an address formatter to SQLHelpers.swift
                    let loc:[String:Any] = [
                        "Id" : rowId,
                        "Lat" : lat,
                        "Lon" : lon,
                        "Name" : name,
                        "Timestamp" : d,
                        "Address" : "\(street), \(city) \(state) \(area) \(country)"
                    ]
                    
                    locations.append(loc)
                    
                    result = sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            
            _ = self.dbClose(db: db)
        }
        
        return locations
    }
    
    public func cachedLocation(_ cacheId:Int64) -> [String:Any]? {
    
        var location:[String:Any]? = [:]
        
        if let db = dbOpen() {
        
            let sql = "SELECT Id, Name, Street, City, State, Area, Country, Lat, Lon, Timestamp, Notes FROM GeoCache WHERE Id = \(cacheId)"
            
            var stmt:OpaquePointer? = nil
            var result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            
            var retryCount:Int = 0
            while SQLITE_BUSY == result && retryCount < 15 {
                sleep(1)
                retryCount += 1
                result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            }
            
            if SQLITE_OK == result {
                result = sqlite3_step(stmt)
                if SQLITE_ROW == result {
                
                    let rowId:Int64 = sqlite3_column_int64(stmt, 0)
                    let lat = sqlite3_column_double(stmt, 7)
                    let lon = sqlite3_column_double(stmt, 8)
                    
                    var name = ""
                    if let str = sqlite3_column_text(stmt, 1) {
                        name = String(cString:str)
                    }

                    var street = ""
                    if let str = sqlite3_column_text(stmt, 2) {
                        street = String(cString:str)
                    }

                    var city = ""
                    if let str = sqlite3_column_text(stmt, 3) {
                        city = String(cString:str)
                    }

                    var state = ""
                    if let str = sqlite3_column_text(stmt, 4) {
                        state = String(cString:str)
                    }

                    var area = ""
                    if let str = sqlite3_column_text(stmt, 5) {
                        area = String(cString:str)
                    }

                    var country = ""
                    if let str = sqlite3_column_text(stmt, 6) {
                        country = String(cString:str)
                    }
                    
                    var notes = ""
                    if let str = sqlite3_column_text(stmt, 10) {
                        notes = String(cString:str)
                    }
                    
                    let d = Date(timeIntervalSince1970: sqlite3_column_double(stmt,9))
                    
                    let loc:[String:Any] = [
                        "Id" : rowId,
                        "Lat" : lat,
                        "Lon" : lon,
                        "Name" : name,
                        "Timestamp" : d,
                        "Street" : street,
                        "City" : city,
                        "State" : state,
                        "Country" : country,
                        "Notes" : notes
                    ]
                    
                    location = loc
                }
                sqlite3_finalize(stmt)
            }
            else {
                location = nil
            }
            
            _ = self.dbClose(db: db)
        }
        
        return location
    }

    public func update(locationId:Int64, info:[String:Any]) -> CacheStatus {
        var err:CacheStatus = .NoError
        var changes:Int = 0
        var lastInsertId:Int64 = -1
        
        if let db = dbOpen() {
        
            let colNames = Array<String>(info.keys)
            var colValues = [String]()
            let fmtr = DateFormatter()
            fmtr.dateFormat = "yyyy-MM-dd'T'hh:mm:SS"
            for colName in colNames {
                switch colName {
                    case "Name", "Notes", "Street", "City", "State", "Country", "Area":
                        colValues.append("\(colName) = '\(info[colName]!)'")
                    case "Lat", "Lon":
                        colValues.append("\(colName) = \(info[colName]!)")
                    case "Timestamp":
                        //todo: switch this to using a time interval to store it instead
                        //of a string that requires extra parsing
                        let str = fmtr.string(from: info[colName] as! Date)
                        colValues.append("\(colName) = '\(str)'")
                        break
                    default:
                        break
                }
                
            }
            
            let colValsStr = colValues.joined(separator: ",")
            let sql = "UPDATE GeoCache SET \(colValsStr) WHERE Id = \(locationId)"
            
            var result = sqlite3_exec(db, sql, nil, nil, nil)
            
            var retryCount:Int = 0
            while SQLITE_BUSY == result && retryCount < 10 {
                sleep(1)
                retryCount += 1
                result = sqlite3_exec(db, sql, nil, nil, nil)
            }
            
            if SQLITE_OK != result {
                err = .SqlError
            }
            else {
                changes = Int(sqlite3_changes(db))
            }
            
            _ = self.dbClose(db: db)
        
        }
        
        return err
    }
    
    public func delete(locationId:Int64) -> CacheStatus {
        var err:CacheStatus = .NoError
        
        if let db = dbOpen() {
            let sql = "DELETE FROM GeoCache WHERE Id = \(locationId)"
            var result = sqlite3_exec(db, sql, nil, nil, nil)
            
            var retryCount:Int = 0
            while SQLITE_BUSY == result && retryCount < 10 {
                sleep(1)
                retryCount += 1
                result = sqlite3_exec(db, sql, nil, nil, nil)
            }
            
            if SQLITE_OK != result {
                err = .SqlError
            }
            
            _ = self.dbClose(db: db)
        }
        
        return err
    }

    //MARK: - tags
    func tag(_ locationId:Int64, tags:[String]) -> CacheStatus {
        //DELETE FROM Tags WHERE Id = locationId
        return .NoError
    }
    
    func tags() -> [String] {
        //SELECT DISTINCT Tag from Tags ORDER BY Tag ASC
        return []
    }
    
    func tags(locationId:Int64) -> [String] {
        //SELECT Tag from Tags where Id = locationId
        return []
    }
    
}
