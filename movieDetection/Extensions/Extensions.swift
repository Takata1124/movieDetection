//
//  Extensions.swift
//  movieDetection
//
//  Created by t032fj on 2022/02/10.
//

import UIKit

extension UIImage {
    
    func cropping(to: CGRect) -> UIImage? {
        var opaque = false
        if let cgImage = cgImage {
            switch cgImage.alphaInfo {
            case .noneSkipLast, .noneSkipFirst:
                opaque = true
            default:
                break
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(to.size, opaque, scale)
        draw(at: CGPoint(x: -to.origin.x, y: -to.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    func getCVPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        
        var pixelBuffer: CVPixelBuffer?
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let imageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        
        let options = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
               kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        self.draw(in: imageRect)
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        UIGraphicsEndImageContext()
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(newImage.size.width),
            Int(newImage.size.height),
            kCVPixelFormatType_32ARGB,
            options,
            &pixelBuffer)
        
        guard status == kCVReturnSuccess, let uwPixelBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(uwPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(uwPixelBuffer)
        let context = CGContext(
            data: pixelData,
            width: Int(newImage.size.width),
            height: Int(newImage.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(uwPixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let uwContext = context else {
            return nil
        }
        
        uwContext.translateBy(x: 0, y: newImage.size.height)
        uwContext.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(uwContext)
        newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(uwPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
    
    func pixelBufferGray(width: Int, height: Int) -> CVPixelBuffer? {
        
        var pixelBuffer : CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_OneComponent8,
            attributes as CFDictionary,
            &pixelBuffer)
        
        guard status == kCVReturnSuccess, let imageBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let imageData =  CVPixelBufferGetBaseAddress(imageBuffer)
        
        guard let context = CGContext(data: imageData, width: Int(width), height:Int(height),
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer),
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x:0, y:0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return imageBuffer
        
    }
    
    func flipHorizontal() -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let imageRef = self.cgImage
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: size.width, y:  size.height)
        context?.scaleBy(x: -1.0, y: -1.0)
        context?.draw(imageRef!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let flipHorizontalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return flipHorizontalImage!
    }
}
