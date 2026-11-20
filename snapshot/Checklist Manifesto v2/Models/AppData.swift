import Foundation
import Darwin

struct AppData: Codable {
    var checklists: [Checklist] = []
    
    var allTags: [String] {
        Array(Set(checklists.flatMap { $0.tags })).sorted()
    }
    
    func checklists(forTag tag: String) -> [Checklist] {
        checklists.filter { $0.tags.contains(tag) }
    }
    
    func checklistsWithoutTags() -> [Checklist] {
        checklists.filter { $0.tags.isEmpty }
    }
}

extension AppData {
    static let fileURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("checklistData.json")
    }()
}

/// Missing is a valid first-run state; a read/decoding error is never empty data.
enum ChecklistLoadResult {
    case missing
    case loaded(AppData, bytes: Data)
}

enum ChecklistStorageError: LocalizedError {
    case unreadable, invalidData, changed, missingExisting, busy, writeFailed, verificationFailed
    var errorDescription: String? {
        switch self {
        case .unreadable: return "Your checklists could not be read. The saved file has not been replaced."
        case .invalidData: return "The saved checklist file could not be understood. Its original contents have been kept."
        case .changed: return "The saved checklists changed since they were opened. Reload them before making further changes."
        case .missingExisting: return "The saved checklist file is now missing. Your last loaded checklists have been kept in memory."
        case .busy: return "Another save is in progress. Reload the checklists before trying again."
        case .writeFailed: return "Your changes could not be saved. Reload the checklists before trying again."
        case .verificationFailed: return "The save could not be confirmed. Reload the saved checklists before trying again."
        }
    }
}

/// Local file storage only. A URL is injected for isolated tests, not remote access.
struct ChecklistStorage {
    let url: URL
    static let maximumBytes = 32 * 1024 * 1024

    func load() throws -> ChecklistLoadResult {
        guard let bytes = try readBytes() else { return .missing }
        guard let model = try? JSONDecoder().decode(AppData.self, from: bytes) else {
            throw ChecklistStorageError.invalidData
        }
        return .loaded(model, bytes: bytes)
    }

    /// A cooperating writer holds the lock across compare, atomic replace and readback.
    /// The expected bytes also prevent overwriting edits made since the last load.
    func save(_ model: AppData, expecting expected: Data?) throws -> Data {
        let encoded: Data
        do { encoded = try JSONEncoder().encode(model) }
        catch { throw ChecklistStorageError.writeFailed }
        guard encoded.count <= Self.maximumBytes else { throw ChecklistStorageError.writeFailed }
        let lockURL = url.appendingPathExtension("lock")
        let lock = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_NONBLOCK, 0o600)
        guard lock >= 0 else { throw ChecklistStorageError.writeFailed }
        defer { close(lock) }
        var info = stat()
        guard fstat(lock, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw ChecklistStorageError.busy }
        defer { flock(lock, LOCK_UN) }
        let current = try readBytes()
        guard current == expected else { throw ChecklistStorageError.changed }
        // Even a caller supplying corrupt bytes cannot authorize replacing unreadable data.
        if let current = current,
           (try? JSONDecoder().decode(AppData.self, from: current)) == nil {
            throw ChecklistStorageError.invalidData
        }
        do { try encoded.write(to: url, options: .atomic) }
        catch { throw ChecklistStorageError.writeFailed }
        guard try readBytes() == encoded else { throw ChecklistStorageError.verificationFailed }
        return encoded
    }

    private func readBytes() throws -> Data? {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        if descriptor < 0 {
            if errno == ENOENT { return nil }
            throw ChecklistStorageError.unreadable
        }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? file.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_size <= Self.maximumBytes else { throw ChecklistStorageError.unreadable }
        do {
            var data = Data()
            while let chunk = try file.read(upToCount: min(65536, Self.maximumBytes + 1 - data.count)), !chunk.isEmpty {
                data.append(chunk)
                if data.count > Self.maximumBytes { throw ChecklistStorageError.unreadable }
            }
            return data
        } catch { throw ChecklistStorageError.unreadable }
    }
}
