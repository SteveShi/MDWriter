//
//  ImageManager.swift
//  MDWriter
//
//  Created for Image Persistence and Sandboxing
//

import AppKit
import Foundation

class ImageManager {
    static let shared = ImageManager()

    private let fileManager = FileManager.default
    private let imagesDirectoryName = "Images"
    private let imageCache = NSCache<NSString, NSImage>()

    // 获取（或创建）图片存储目录
    private var imagesDirectoryURL: URL? {
        guard
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return nil
        }
        let url = documentsURL.appendingPathComponent(imagesDirectoryName)

        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }

        return url
    }

    /// 将外部 URL 的图片复制到沙盒，并返回新的文件名
    func saveImage(from url: URL) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }

        // 生成唯一文件名，保留原始扩展名
        let fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let filename = UUID().uuidString + "." + fileExtension
        let destinationURL = imagesDir.appendingPathComponent(filename)

        do {
            // 如果是安全范围外的文件，需要 startAccessingSecurityScopedResource（通常拖拽或OpenPanel不需要，但以此防万一）
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }

            try fileManager.copyItem(at: url, to: destinationURL)
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

    /// 根据文件名读取图片
    func loadImage(named filename: String) -> NSImage? {
        if let cached = imageCache.object(forKey: filename as NSString) {
            return cached
        }

        guard let imagesDir = imagesDirectoryURL else { return nil }
        let fileURL = imagesDir.appendingPathComponent(filename)

        if let image = NSImage(contentsOf: fileURL) {
            imageCache.setObject(image, forKey: filename as NSString)
            return image
        }
        return nil
    }

    /// 获取图片的完整路径（用于 QuickLook 或其他用途）
    func fileURL(for filename: String) -> URL? {
        return imagesDirectoryURL?.appendingPathComponent(filename)
    }
}
