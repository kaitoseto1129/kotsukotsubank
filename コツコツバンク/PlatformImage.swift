//
//  PlatformImage.swift
//  コツコツバンク
//

import SwiftUI

struct PlatformImage {
    #if canImport(UIKit)
    let uiImage: UIImage
    init?(data: Data) {
        guard let image = UIImage(data: data) else { return nil }
        self.uiImage = image
    }
    var resizableImage: Image { Image(uiImage: uiImage).resizable() }
    #elseif canImport(AppKit)
    let nsImage: NSImage
    init?(data: Data) {
        guard let image = NSImage(data: data) else { return nil }
        self.nsImage = image
    }
    var resizableImage: Image { Image(nsImage: nsImage).resizable() }
    #endif
}
