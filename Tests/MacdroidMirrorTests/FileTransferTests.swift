import Foundation
import Testing
@testable import MacdroidMirrorCore

@Suite("File Transfer Service Tests")
struct FileTransferServiceTests {
    @Test("Parse machine-readable stat output into structured RemoteFileItems")
    func parseStatOutputStructured() {
        let raw = """
        directory|3452|1776874795|/sdcard/Download/.temp_mimusic
        regular file|122652|1757042272|/sdcard/Download/(0)1000066391.jpg
        regular file|481626|1747640713|/sdcard/Download/(inshotmuzic.in) arabic ringtone.mp3
        directory|53248|1792801802|/sdcard/Download/Canva
        """

        let service = FileTransferService()
        let items = service.parseStatOutput(raw)

        #expect(items.count == 4)
        // Directories come first, sorted alphabetically
        #expect(items[0].isDirectory == true)
        #expect(items[0].name == ".temp_mimusic")
        #expect(items[1].isDirectory == true)
        #expect(items[1].name == "Canva")
        #expect(items[2].isDirectory == false)
        #expect(items[2].name == "(0)1000066391.jpg")
        #expect(items[2].sizeBytes == 122652)
        #expect(items[3].isDirectory == false)
        #expect(items[3].name == "(inshotmuzic.in) arabic ringtone.mp3")
        #expect(items[3].sizeBytes == 481626)
    }

    @Test("Skip . and .. from stat output")
    func skipSpecialDirectoryDots() {
        let raw = """
        directory|4096|1757042272|/sdcard/Download/.
        directory|4096|1757042272|/sdcard/Download/..
        regular file|120|1757042272|/sdcard/Download/notes.txt
        """

        let service = FileTransferService()
        let items = service.parseStatOutput(raw)
        #expect(items.count == 1)
        #expect(items[0].name == "notes.txt")
        #expect(items[0].fullPath == "/sdcard/Download/notes.txt")
    }

    @Test("RemotePathModel normalized paths, parent paths and breadcrumbs")
    func remotePathModelBehavior() {
        let root = RemotePathModel("/sdcard")
        #expect(root.isRoot == true)
        #expect(root.parentPath == "/sdcard")
        #expect(root.breadcrumbs.count == 1)
        #expect(root.breadcrumbs[0].title == "Internal storage")
        #expect(root.friendlyDisplayPath == "Internal storage")

        let download = RemotePathModel("/sdcard/Download//")
        #expect(download.normalizedPath == "/sdcard/Download")
        #expect(download.isRoot == false)
        #expect(download.parentPath == "/sdcard")
        #expect(download.displayName == "Download")
        #expect(download.friendlyDisplayPath == "Internal storage/Download")
        #expect(download.breadcrumbs.count == 2)
        #expect(download.breadcrumbs[0].title == "Internal storage")
        #expect(download.breadcrumbs[1].title == "Download")
        #expect(download.breadcrumbs[1].path == "/sdcard/Download")

        let nested = RemotePathModel("/sdcard/Download/Canva/Projects")
        #expect(nested.parentPath == "/sdcard/Download/Canva")
        #expect(nested.friendlyDisplayPath == "Internal storage/Download/Canva/Projects")
        #expect(nested.breadcrumbs.count == 4)
        #expect(nested.breadcrumbs[3].title == "Projects")
    }

    @Test("RemotePathModel handles empty or root slashes cleanly")
    func remotePathModelRootBoundaries() {
        let empty = RemotePathModel("")
        #expect(empty.normalizedPath == "/sdcard")
        #expect(empty.isRoot == true)

        let slash = RemotePathModel("///")
        #expect(slash.normalizedPath == "/")
        #expect(slash.isRoot == true)
    }

    @Test("BatchTransferSummary user feedback descriptions")
    func batchTransferSummaryDescriptions() {
        var summary = BatchTransferSummary(transferredCount: 3, replacedCount: 1, skippedCount: 2, failedCount: 0)
        #expect(summary.userFeedbackDescription == "2 transferred, 1 replaced, 2 skipped")

        summary = BatchTransferSummary(transferredCount: 1, replacedCount: 1, skippedCount: 0, failedCount: 0)
        #expect(summary.userFeedbackDescription == "1 replaced")

        summary = BatchTransferSummary(isCancelled: true)
        #expect(summary.userFeedbackDescription == "Transfer cancelled")

        summary = BatchTransferSummary()
        #expect(summary.userFeedbackDescription == "No files transferred")
    }
}
