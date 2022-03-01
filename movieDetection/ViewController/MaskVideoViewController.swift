//
//  VideoViewController.swift
//  movieDetection
//
//  Created by t032fj on 2022/02/13.
//

import UIKit
import AVFoundation
import Vision
import SnapKit
import CoreML

class MaskVideoViewController: UIViewController {
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var faceLayers: [CAShapeLayer] = []
    
    var uiImage = UIImage()
    
    let coreMLModel = mask_model()
    
    var recView: UIView = {
        let recView = UIView()
        recView.layer.borderWidth = 3.0
        recView.layer.borderColor = UIColor.green.cgColor
        return recView
    }()
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .red
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
        //front or back Camera
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

extension MaskVideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
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
            uiImage = UIImage(ciImage: ciImage)
            
            let img = uiImage.cropping(
                to: CGRect(x: img_x * widthScale, y: img_y * heightScale,
                           width: img_width * widthScale, height: img_height * heightScale))
            
            guard let img = img else { return }
            
            guard let buffer = img.getCVPixelBuffer(size: CGSize(width: 25, height: 25)) else {
                return
            }
            
            DispatchQueue.global(qos: .userInteractive).async {
                
                guard let output = try? self.coreMLModel.prediction(conv2d_27_input: buffer) else {
                    return
                }
                
                DispatchQueue.main.async {
                    
                    let didLabel = output.classLabel
                    
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
