//
//  EmotionViewController.swift
//  movieDetection
//
//  Created by t032fj on 2022/02/16.
//

import UIKit
import AVFoundation
import Vision
import SnapKit
import CoreML

class EmotionViewController: UIViewController {
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var faceLayers: [CAShapeLayer] = []
    
    
    
    let emotionMLModel = emotion_64_model()
    
    var recView: UIView = {
        let recView = UIView()
        recView.layer.borderWidth = 3.0
        recView.layer.borderColor = UIColor.green.cgColor
        return recView
    }()
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.borderWidth = 1.0
        imageView.layer.borderColor = UIColor.black.cgColor
        return imageView
    }()
    
    private let judgeLabel: UILabel = {
        let label = UILabel()
        label.text = "---"
        label.textAlignment = .center
        label.backgroundColor = .white
        return label
    }()
    
    var imageBuffer: CVPixelBuffer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }
    
    private func setupCamera() {
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        if let device = deviceDiscoverySession.devices.first {
            
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                
                if captureSession.canAddInput(deviceInput) {
                    
                    captureSession.addInput(deviceInput)
                    setupPreview()
                }
            }
        }
    }
    
    func setupPreview() {
        
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
        
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        
        let videoConnection = self.videoDataOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
    }
}

extension EmotionViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                //レイヤーの削除
                self.faceLayers.forEach({ drawing in drawing.removeFromSuperlayer() })
                
                if let observations = request.results as? [VNFaceObservation] {
                    self.handleFaceDetectionObservations(observations: observations)
                }
            }
        })
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer!, orientation: .leftMirrored, options: [:])
        
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func handleFaceDetectionObservations(observations: [VNFaceObservation]) {
        
        for observation in observations {
            //一番重要
            let faceRectConverted = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
            let faceRectanglePath = CGPath(rect: faceRectConverted, transform: nil)
            
            let faceLayer = CAShapeLayer()
            faceLayer.path = faceRectanglePath
            faceLayer.fillColor = UIColor.clear.cgColor
            faceLayer.strokeColor = UIColor.green.cgColor
            
            self.faceLayers.append(faceLayer)
            self.view.layer.addSublayer(faceLayer)
            
            let videoRect = previewLayer.layerRectConverted(
                fromMetadataOutputRect: CGRect(x: observation.boundingBox.minX,
                                               y: observation.boundingBox.minY,
                                               width: observation.boundingBox.width,
                                               height: observation.boundingBox.height))

            
            let pixcelWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer!))
            let pixcelHeight =  CGFloat(CVPixelBufferGetHeight(imageBuffer!))
            
            let widthScale = pixcelWidth/(view.frame.width)
            let heightScale = pixcelHeight/(view.frame.height)
            
            let img_width: CGFloat = videoRect.width
            let img_height: CGFloat = videoRect.height
            let img_x: CGFloat = videoRect.minX
            let img_y: CGFloat = videoRect.minY
            
            let ciImage = CIImage(cvPixelBuffer: imageBuffer!)
            
            let uiImage: UIImage = UIImage(ciImage: ciImage)
            
            var img = uiImage.cropping(
                to: CGRect(x: (previewLayer.frame.width - img_x) * widthScale - img_width * widthScale, y: img_y * heightScale - img_height / 4,
                           width: img_width * widthScale * 1, height: img_height * heightScale * 1.2))
            
            img = img?.flipHorizontal()
            
            guard let img = img else { return }
            
            self.view.addSubview(self.imageView)
            
            imageView.image = img
            
            self.imageView.snp.makeConstraints { make in
                
                make.size.equalTo(150)
                make.centerX.equalToSuperview()
                make.bottom.equalTo(self.view.snp.bottom).offset(-50)
            }
            
            let imagesize: Int = 64
            
            guard let buffer = img.pixelBufferGray(width: imagesize, height: imagesize) else {
                return
            }
            
            DispatchQueue.global(qos: .userInteractive).async {
                
                guard let output = try? self.emotionMLModel.prediction(input_1: buffer) else {
                    return
                }
                
                DispatchQueue.main.async {
                    
                    let didLabel = output.classLabel
                    //                    print(output)
                    //                    print(didLabel)
                    //                    print(output.Identity)

                    self.view.addSubview(self.judgeLabel)
                    self.judgeLabel.snp.makeConstraints { make in
                        
                        make.size.equalTo(150)
                        make.centerX.equalToSuperview()
                        make.top.equalTo(self.view.snp.top).offset(50)
                    }
                    
                    self.judgeLabel.text = didLabel
                }
            }
        }
    }
}

extension UIImage {
    
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
