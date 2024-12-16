//
//  HeadlessRenderingStrategy.swift
//
//
//  Created by Ilter Cengiz on 13/12/24.
//

#if canImport(UIKit) && !os(watchOS) && !os(visionOS) && !os(tvOS)
import Foundation
import UIKit
import SwiftUI

public class HeadlessRenderingStrategy: RenderingStrategy {

  public init() {
    let window = UIWindow()
    window.windowLevel = .statusBar + 1
    window.backgroundColor = UIColor.systemBackground
    window.makeKeyAndVisible()
    self.window = window
  }

  private let window: UIWindow

  @MainActor
  public func render(
      preview: SnapshotPreviewsCore.Preview,
      completion: @escaping (SnapshotResult) -> Void
  ) {
      Self.setup()
      performRender(preview: preview, completion: completion)
  }

  @MainActor private func performRender(
    preview: SnapshotPreviewsCore.Preview,
    completion: @escaping (SnapshotResult) -> Void
  ) {
    UIView.setAnimationsEnabled(false)
    let view = preview.view()
    let controller = view.makeExpandingView(layout: preview.layout, window: window)
    view.snapshot(
      layout: preview.layout,
      controller: controller,
      window: window,
      async: false) { result in
        completion(result)
      }
  }
}
#endif
