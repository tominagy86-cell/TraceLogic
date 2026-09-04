import Foundation
import SwiftData

public enum ModelContainerFactory {

    public static var schema: Schema {
        Schema([
            StoredSample.self,
            StoredDailyStat.self,
            StoredWorkout.self,
            StoredSleepSession.self,
            SyncState.self,
            SyncLogEntry.self,
        ])
    }

    /// A rendes, lemezre író konténer (`~/Library/.../Application Support`).
    public static func makeDefault() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
    }

    /// Csak-memóriás konténer — preview-hoz / unit teszthez (ha egyszer Mac-en is tesztelünk).
    public static func makeInMemory() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
