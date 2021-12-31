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
        return imageView
    }()
    
    let reverseButton: UIButton = {
        let reverseButton = UIButton()
        reverseButton.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        reverseButton.setTitle("Reverse Camera Position", for: .normal)
        reverseButton.setTitleColor(UIColor.white, for: .normal)
        reverseButton.setTitleColor(UIColor.lightGray, for: .disabled)
        return reverseButton
    }()
    
    var frontOn: Bool?
    
    var captureSession: AVCaptureSession? = nil
    
    var videoDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        frontOn = false
        
        self.setupCaptureSession(withPosition: .back)
    }
    
    @objc func onTapReverseButton(sender: UIButton) {
        self.reverseCameraPosition()
    }
    
    func setupCaptureSession(withPosition cameraPosition: AVCaptureDevice.Position) {
        
        self.videoDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: cameraPosition)
        
        self.captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        let videoInput = try! AVCaptureDeviceInput(device: self.videoDevice!)
        self.captureSession?.addInput(videoInput)
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        view.layer.addSublayer(self.previewLayer!)
        self.previewLayer!.frame = view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession?.addOutput(dataOutput)
        
        self.captureSession?.startRunning()
    }
    
    func reverseCameraPosition() {
        
        self.captureSession?.stopRunning()
        
        if frontOn == true {
            frontOn = false
            print("false")
        }
        else {
            frontOn = true
            print("true")
        }
        
        self.captureSession?.inputs.forEach { input in
            self.captureSession?.removeInput(input)
        }
        self.captureSession?.outputs.forEach { output in
            self.captureSession?.removeOutput(output)
        }
        
        captureSession?.sessionPreset = .photo
        
        // prepare new capture session & preview
        let newCameraPosition: AVCaptureDevice.Position = self.videoDevice?.position == .front ? .back : .front
        setupCaptureSession(withPosition: newCameraPosition)
        
        let newVideoLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession!)
        newVideoLayer.frame = self.view.frame
//        newVideoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // horizontal flip
        UIView.transition(with: self.view, duration: 0.5, options: [.transitionFlipFromLeft], animations: nil, completion: { _ in
            // replace camera preview with new one
            self.view.layer.replaceSublayer(self.previewLayer!, with: newVideoLayer)
            self.previewLayer = newVideoLayer
        })
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixcelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixcelBuffer)
        let orientation :CGImagePropertyOrientation = CGImagePropertyOrientation.right
        let orientedImage = ciImage.oriented(orientation)
        var uiImage = UIImage(ciImage: orientedImage)
        
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            
            request.results?.forEach({ (res) in
                
                DispatchQueue.main.async {
                    
                    guard let faceObservation = res as? VNFaceObservation else { return }
                    
                    var x: CGFloat?
                    var y: CGFloat?
                    var width: CGFloat?
                    var height: CGFloat?
                    
                    var img_x: CGFloat?
                    var img_y: CGFloat?
                    var img_width: CGFloat?
                    var img_height: CGFloat?
                    
                    if self?.frontOn == false {
                       
                        width = (self?.view.frame.width)! * faceObservation.boundingBox.width * 2
                        x = (self?.view.frame.width)! * faceObservation.boundingBox.origin.x
                        height = (self?.view.frame.height)! * faceObservation.boundingBox.height
                        y = (self?.view.frame.height)! * (1 - faceObservation.boundingBox.origin.y) - height!
                        
                        img_width = uiImage.size.width * faceObservation.boundingBox.width * 2
                        img_x = uiImage.size.width * faceObservation.boundingBox.origin.x
                        img_height = uiImage.size.height * faceObservation.boundingBox.height
                        img_y = uiImage.size.height * (1 - faceObservation.boundingBox.origin.y) - img_height!
                    }
                    else {
                        
                        width = (self?.view.frame.width)! * faceObservation.boundingBox.width * 1.5
                        x = (self?.view.frame.width)! * (1 - faceObservation.boundingBox.origin.y)  - width!
                        height = (self?.view.frame.height)! * faceObservation.boundingBox.height / 1.5
                        y = (self?.view.frame.height)! * faceObservation.boundingBox.origin.x - height! / 4
                        
                        img_width = uiImage.size.width * faceObservation.boundingBox.width * 2
                        img_x = uiImage.size.width * (1 - faceObservation.boundingBox.origin.y) - img_width! * 1.2
                        img_height = uiImage.size.height * faceObservation.boundingBox.height
                        img_y = uiImage.size.height * faceObservation.boundingBox.origin.x - img_height! / 3
                    }
                    
                    self?.recView.frame = CGRect(x: x!, y: y!, width: width!, height: height!)
                    self?.view.addSubview(self!.recView)
                
                    var img = uiImage.cropping(to: CGRect(x: img_x!, y: img_y!, width: img_width!, height: img_height!))
                    
                    if self?.frontOn == true {
                        
                        img = img?.flipHorizontal()
                    }
                    
                    self?.imageView.image = img
                    self?.imageView.frame = CGRect(x: 30, y: 30, width: 100, height: 100)
                    self?.view.addSubview(self!.imageView)
                    
                    self?.reverseButton.frame = CGRect(x: (self?.view.bounds.width)! / 2 - 50, y: (self?.view.bounds.height)! - 100, width: 100, height: 50)
                    self?.reverseButton.addTarget(self, action: #selector(self?.onTapReverseButton(sender:)), for: .touchUpInside)
                    self?.view.addSubview(self!.reverseButton)
                    
                    self?.label.frame = CGRect(x: (self?.view.bounds.width)! / 2, y: (self?.view.bounds.height)!, width: 100, height: 100)
                    self?.view.addSubview(self!.label)
                    
//                    print(faceObservation.boundingBox, Date())
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
    
    func flipHorizontal() -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
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
