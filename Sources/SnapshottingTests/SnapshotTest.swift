//
//  SnapshotTest.swift
//
//
//  Created by Noah Martin on 8/9/24.
//

import Foundation
@_implementationOnly import SnapshotPreviewsCore
import XCTest
import XCTest

/// A test class for generating snapshots of Xcode previews.
///
/// This class is designed to discover SwiftUI previews, render them, and generate snapshot images for testing purposes.
/// It provides mechanisms for filtering previews and supports different rendering strategies based on the platform.
open class SnapshotTest: PreviewBaseTest, PreviewFilters {

  ///
  open class func isHeadlessSetup() -> Bool {
    false
  }

  ///
  open class func isRecording() -> Bool {
    false
  }

  ///
  open class func filePath() -> StaticString {
    #file
  }

  /// Returns an optional array of preview names to be included in the snapshot testing. This also supports Regex format.
  ///
  /// Override this method to specify which previews should be included in the snapshot test.
  /// - Returns: An optional array of String containing the names of previews to be included.
  open class func snapshotPreviews() -> [String]? {
      nil
  }

  /// Returns an optional array of preview names to be excluded from the snapshot testing. This also supports Regex format.
  ///
  /// Override this method to specify which previews should be excluded from the snapshot test.
  /// - Returns: An optional array of String containing the names of previews to be excluded.
  open class func excludedSnapshotPreviews() -> [String]? {
      nil
  }

  /// Determines the appropriate rendering strategy based on the current platform and OS version.
  ///
  /// This method selects between UIKit, AppKit, and SwiftUI rendering strategies depending on the available frameworks and OS version.
  /// - Returns: A `RenderingStrategy` object suitable for the current environment.
  private static func getRenderingStrategy() -> RenderingStrategy {
    #if canImport(UIKit) && !os(watchOS) && !os(visionOS) && !os(tvOS)
      if Self.isHeadlessSetup() {
        print("[DEBUG] Using headless setup")
        return HeadlessRenderingStrategy()
      } else {
        print("[DEBUG] Using UIKit setup")
        return UIKitRenderingStrategy()
      }
    #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
      AppKitRenderingStrategy()
    #else
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
      SwiftUIRenderingStrategy()
    } else {
      preconditionFailure("Cannot snapshot on this device/os")
    }
    #endif
  }

  static private var previews: [SnapshotPreviewsCore.PreviewType] = []

  /// Discovers all relevant previews based on inclusion and exclusion filters. Subclasses should NOT override this method.
  ///
  /// This method uses `FindPreviews` to locate all previews, applying any specified filters.
  /// - Returns: An array of `DiscoveredPreview` objects representing the found previews.
  @MainActor
  override class func discoverPreviews() -> [DiscoveredPreview] {
    previews = FindPreviews.findPreviews(included: Self.snapshotPreviews(), excluded: Self.excludedSnapshotPreviews())
    return previews.map { DiscoveredPreview.from(previewType: $0) }
  }

  /// Tests a specific preview by rendering it and generating a snapshot. Subclasses should NOT override this method.
  ///
  /// This method renders the specified preview using the appropriate rendering strategy,
  /// creates a snapshot image, and attaches it to the test results.
  ///
  /// - Parameter preview: A `DiscoveredPreviewAndIndex` object representing the preview to be tested.
  @MainActor
  override func testPreview(_ preview: DiscoveredPreviewAndIndex) {
    let previewType = Self.previews.first { $0.typeName == preview.preview.typeName }
    guard let preview = previewType?.previews[preview.index] else {
      XCTFail("Preview not found")
      return
    }

    var result: SnapshotResult? = nil
    let expectation = XCTestExpectation()
    Self.getRenderingStrategy().render(preview: preview) { snapshotResult in
      result = snapshotResult
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 10)
    guard let result else {
      XCTFail("Did not render")
      return
    }
    do {
      let snapshotImage = try result.image.get()

      let filePath = Self.filePath()
      let fileUrl = URL(fileURLWithPath: "\(filePath)", isDirectory: false)
      let fileName = fileUrl.deletingLastPathComponent()
      let snapshotDirectoryUrl = fileName.appendingPathComponent("snapshots")

      if FileManager.default.fileExists(atPath: snapshotDirectoryUrl.path) == false {
        try FileManager.default.createDirectory(at: snapshotDirectoryUrl, withIntermediateDirectories: true)
      }

      guard let snapshotName = preview.displayName else {
        XCTFail("Can't get preview name, assign a name to preview")
        return
      }
      let snapshotUrl = snapshotDirectoryUrl
        .appendingPathComponent(sanitizePathComponent(snapshotName))
        .appendingPathExtension("png")

      if Self.isRecording() || FileManager.default.fileExists(atPath: snapshotUrl.path) == false {
        // Record snapshot
        try snapshotImage.pngData()?.write(to: snapshotUrl) // consider empty image for nil case
        XCTFail("Recorded snapshot at \(snapshotUrl), re-run the test to assert against reference.")
        return
      }

      let referenceImageData = try Data(contentsOf: snapshotUrl)
      let referenceImage = UIImage(data: referenceImageData, scale: UIScreen.main.scale)!

      let snapshotAttachment = XCTAttachment(image: snapshotImage)
      snapshotAttachment.name = "Snapshot"
      snapshotAttachment.lifetime = .keepAlways
      add(snapshotAttachment)

      let referenceAttachment = XCTAttachment(image: referenceImage)
      referenceAttachment.name = "Reference"
      referenceAttachment.lifetime = .keepAlways
      add(referenceAttachment)

      if imagesAreEqual(snapshotImage, referenceImage) {
      } else {
        XCTFail("Snapshot does not match reference. See attachments for details.")
      }
    } catch {
      XCTFail("Error \(error)")
    }
  }


}

private func sanitizePathComponent(_ string: String) -> String {
  return
    string
    .lowercased()
    .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
    .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}

private func imagesAreEqual(_ image1: UIImage, _ image2: UIImage) -> Bool {
    guard let data1 = image1.pngData(),
          let data2 = image2.pngData() else {
        return false
    }
    return data1 == data2
}
