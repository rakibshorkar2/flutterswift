import QuickLook
import UIKit

/// Native QuickLook preview controller.
final class QuickLookViewController: QLPreviewController, QLPreviewControllerDataSource {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(nibName: nil, bundle: nil)
        self.dataSource = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

    func previewController(_ controller: QLPreviewController,
                           previewItemAt index: Int) -> QLPreviewItem {
        fileURL as QLPreviewItem
    }
}
