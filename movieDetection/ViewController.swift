//
//  ViewController.swift
//  movieDetection
//
//  Created by t032fj on 2021/12/29.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let recView: UIView = {
        let recView = UIView()
        recView.layer.borderWidth = 3.0
        recView.layer.borderColor = UIColor.green.cgColor
        return recView
     }()
    
    let label: UILabel = {
        let label = UILabel()
        label.text = "hello"
        return label
    }()
    
    let imageView: UIImageView = {
         let imageView = UIImageView()
         imageView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
         return imageView
     }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession.addInput(input)
        captureSession.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixcelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixcelBuffer)
        let orientation :CGImagePropertyOrientation = CGImagePropertyOrientation.right
        let orientedImage = ciImage.oriented(orientation)
        let uiImage = UIImage(ciImage: orientedImage)
        
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            
            request.results?.forEach({ (res) in
                
                DispatchQueue.main.async {
                    
                    guard let faceObservation = res as? VNFaceObservation else { return }
                    
                    let width = (self?.view.frame.width)! * faceObservation.boundingBox.width * 2
                    let x = (self?.view.frame.width)! * faceObservation.boundingBox.origin.x
                    let height = (self?.view.frame.height)! * faceObservation.boundingBox.height
                    let y = (self?.view.frame.height)! * (1 - faceObservation.boundingBox.origin.y) - height
                    
                    self?.recView.frame = CGRect(x: x, y: y, width: width, height: height)
                    self?.view.addSubview(self!.recView)
                    
                    self?.label.frame = CGRect(x: (self?.view.bounds.width)! / 2, y: (self?.view.bounds.height)! / 1.2, width: 100, height: 100)
                    self?.view.addSubview(self!.label)
                    
                    let img = uiImage.cropping(to: CGRect(x: 0, y: 0, width: 100, height: 100))
                    
                    self?.imageView.image = img
                    self?.view.addSubview(self!.imageView)
                    
                    print(faceObservation.boundingBox, Date())
                }
                
            })
        }
        
        DispatchQueue.global(qos: .background).async {
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            }
            catch {
                print(error)
            }
        }
    }
}

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
}




