// app/Database/Database.swift
import SQLiteData
import GRDB
import OSLog
import Dependencies

private let logger = Logger(subsystem: "com.wherefam.ios", category: "Database")

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    var config = Configuration()
    #if DEBUG
    config.prepareDatabase { db in
        db.trace(options: .profile) {
            context == .preview
                ? print($0.expandedDescription)
                : logger.debug("\($0.expandedDescription)")
        }
    }
    #endif
    let db = try defaultDatabase(configuration: config)
    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif
    migrator.registerMigration("v1") { db in
        try #sql(
            """
            CREATE TABLE "person" (
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT,
                "avatarData" BLOB,
                "latitude" REAL, "longitude" REAL, "altitude" REAL, "speed" REAL,
                "batteryLevel" REAL, "batteryCharging" INTEGER,
                "lastSeen" TEXT,
                "addedAt" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
            ) STRICT
            """
        ).execute(db)
        try #sql(
            """
            CREATE TABLE "place" (
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL, "emoji" TEXT NOT NULL DEFAULT '📍',
                "latitude" REAL NOT NULL, "longitude" REAL NOT NULL,
                "radiusMetres" REAL NOT NULL DEFAULT 150,
                "notifyOnArrive" INTEGER NOT NULL DEFAULT 1,
                "notifyOnLeave" INTEGER NOT NULL DEFAULT 1,
                "createdAt" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
            ) STRICT
            """
        ).execute(db)
        try #sql(
            """
            CREATE TABLE "locationHistory" (
                "id" TEXT NOT NULL PRIMARY KEY,
                "personId" TEXT NOT NULL REFERENCES "person"("id") ON DELETE CASCADE,
                "latitude" REAL NOT NULL, "longitude" REAL NOT NULL,
                "speed" REAL, "placeName" TEXT,
                "recordedAt" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
            ) STRICT
            """
        ).execute(db)
        try #sql(
            """
            CREATE INDEX "idx_history_personId" ON "locationHistory"("personId")
            """
        ).execute(db)
        try #sql(
            """
            CREATE INDEX "idx_history_recordedAt" ON "locationHistory"("recordedAt")
            """
        ).execute(db)
    }
    try migrator.migrate(db)
    return db
}

extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        defaultDatabase = try appDatabase()
    }
}
