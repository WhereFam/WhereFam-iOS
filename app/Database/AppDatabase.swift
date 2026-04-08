// app/Database/AppDatabase.swift
import SQLiteData
import GRDB
import Dependencies

func savePerson(_ person: Person) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
        if try Person.where({ $0.id.eq(person.id) }).fetchOne(db) != nil {
            try Person.update(person).execute(db)
        } else {
            try Person.insert(values: { person }).execute(db)
        }
    }
}

func markPersonOffline(id: String) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
        try #sql(
            """
            UPDATE "person" SET "latitude"=NULL,"longitude"=NULL,"altitude"=NULL,"speed"=NULL
            WHERE "id" = \(bind: id)
            """
        ).execute(db)
    }
}

func deletePerson(id: String) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
        try #sql(
            """
            DELETE FROM "person" WHERE "id" = \(bind: id)
            """
        ).execute(db)
    }
}

func fetchAllPeople() throws -> [Person] {
    @Dependency(\.defaultDatabase) var database
    return try database.read { db in try Person.order(by: \.name).fetchAll(db) }
}

func findPerson(id: String) throws -> Person? {
    @Dependency(\.defaultDatabase) var database
    return try database.read { db in
        try Person.where({ $0.id.eq(id) }).fetchOne(db)
    }
}

func savePlace(_ place: Place) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
        if try Place.where({ $0.id.eq(place.id) }).fetchOne(db) != nil {
            try Place.update(place).execute(db)
        } else {
            try Place.insert(values: { place }).execute(db)
        }
    }
}

func deletePlace(id: String) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
        try #sql(
            """
            DELETE FROM "place" WHERE "id" = \(bind: id)
            """
        ).execute(db)
    }
}

func fetchAllPlaces() throws -> [Place] {
    @Dependency(\.defaultDatabase) var database
    return try database.read { db in try Place.order(by: \.name).fetchAll(db) }
}

func saveHistory(_ entry: LocationHistory) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
        try LocationHistory.insert(values: { entry }).execute(db)
        try #sql(
            """
            DELETE FROM "locationHistory" WHERE "recordedAt" < datetime('now','-7 days')
            """
        ).execute(db)
    }
}
