import CoreData

/// Wraps NSPersistentContainer. `inMemory` gives an isolated store for tests.
final class CoreDataStack {
    private(set) var container: NSPersistentContainer

    /// Loaded once per process so multiple stacks (e.g. across tests) share one model
    /// instance, avoiding Core Data's "multiple NSEntityDescription" ambiguity.
    private static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "CryptoPortfolio", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load Core Data model 'CryptoPortfolio'")
        }
        return model
    }()

    init(inMemory: Bool = false, modelName: String = "CryptoPortfolio") {
        container = NSPersistentContainer(name: modelName, managedObjectModel: Self.managedObjectModel)
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }
        // Enable lightweight migration so the store upgrades transparently
        // when the schema version increments. Core Data infers the mapping
        // model between adjacent versions for additive/optional changes.
        container.persistentStoreDescriptions.forEach { description in
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
