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
        //        print("Camera was able to capture a frame", Date())
        
        guard let pixcelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
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

