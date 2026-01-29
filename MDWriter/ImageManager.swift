//
//  ImageManager.swift
//  MDWriter
//
//  Created for Image Persistence and Sandboxing
//

import AppKit
import Foundation

// 使用全局非隔离变量来避开 Swift 6 对类实例属性的自动隔离推断
nonisolated(unsafe) private let imageCache = NSCache<NSString, NSImage>()

final class ImageManager: @unchecked Sendable {
    nonisolated static let shared = ImageManager()

    private let imagesDirectoryName = "Images"

    nonisolated init() {}

    // 获取（或创建）图片存储目录
    nonisolated private var imagesDirectoryURL: URL? {
        let fm = FileManager.default
        guard
            let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return nil
        }
        let url = documentsURL.appendingPathComponent(imagesDirectoryName)

        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }

        return url
    }

    /// 将外部 URL 的图片复制到沙盒，并返回新的文件名
    func saveImage(from url: URL) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        let fm = FileManager.default

        // 生成唯一文件名，保留原始扩展名
        let fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let filename = UUID().uuidString + "." + fileExtension
        let destinationURL = imagesDir.appendingPathComponent(filename)

        do {
            // 如果是安全范围外的文件，需要 startAccessingSecurityScopedResource
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }

            try fm.copyItem(at: url, to: destinationURL)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }

    /// 保存 NSImage 对象（例如来自粘贴板的图片数据）
    func saveImage(_ image: NSImage) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let tiffData = image.tiffRepresentation,
            let bitmapImage = NSBitmapImageRep(data: tiffData),
            let pngData = bitmapImage.representation(using: .png, properties: [:])
        else {
            return nil
        }

        let filename = UUID().uuidString + ".png"
        let destinationURL = imagesDir.appendingPathComponent(filename)

        do {
            try pngData.write(to: destinationURL)
            return filename
        } catch {
            print("Error saving image data: \(error)")
            return nil
        }
    }

    /// 根据文件名或路径读取图片
    nonisolated func loadImage(named pathOrFilename: String) -> NSImage? {
        print("[ImageManager] Loading: \(pathOrFilename)")

        // 先剥离可能存在的 file:// 协议头
        var cleanPath = pathOrFilename
        if cleanPath.hasPrefix("file://") {
            cleanPath = String(cleanPath.dropFirst(7))
        }

        // 再对路径进行 URL 解码，处理可能存在的 %20 等字符
        let decodedPath = cleanPath.removingPercentEncoding ?? cleanPath

        if let cached = imageCache.object(forKey: decodedPath as NSString) {
            return cached
        }

        let fileURL: URL
        if decodedPath.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: decodedPath)
        } else if decodedPath.hasPrefix("~") {
            fileURL = URL(fileURLWithPath: (decodedPath as NSString).expandingTildeInPath)
        } else {
            guard let imagesDir = imagesDirectoryURL else {
                print("[ImageManager] Error: Could not resolve images directory")
                return nil
            }
            fileURL = imagesDir.appendingPathComponent(decodedPath)
        }

        print("[ImageManager] Resolved URL: \(fileURL.path)")

        if let image = NSImage(contentsOf: fileURL) {
            print("[ImageManager] Success: Loaded \(decodedPath)")
            imageCache.setObject(image, forKey: decodedPath as NSString)
            return image
        } else {
            print("[ImageManager] Failure: Could not load image at \(fileURL.path)")
            return nil
        }
    }

    /// 获取图片的完整路径（用于 QuickLook 或其他用途）
    nonisolated func fileURL(for pathOrFilename: String) -> URL? {
        var cleanPath = pathOrFilename
        if cleanPath.hasPrefix("file://") {
            cleanPath = String(cleanPath.dropFirst(7))
        }
        let decodedPath = cleanPath.removingPercentEncoding ?? cleanPath

        if decodedPath.hasPrefix("/") {
            return URL(fileURLWithPath: decodedPath)
        } else if decodedPath.hasPrefix("~") {
            return URL(fileURLWithPath: (decodedPath as NSString).expandingTildeInPath)
        }
        return imagesDirectoryURL?.appendingPathComponent(decodedPath)
    }
}
