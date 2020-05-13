//
//  ViewController.swift
//  visionKitPractice
//
//  Created by Levi Davis on 5/12/20.
//  Copyright © 2020 Levi Davis. All rights reserved.
//

import UIKit
import Vision
import VisionKit

class ViewController: UIViewController {
    
    private var textRecognitionRequest = VNRecognizeTextRequest(completionHandler: nil)
    private let textRecognitionWorkQueue = DispatchQueue(label: "TextRecognitionQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private lazy var imageView: BoundingBoxImageView = {
        let imageView = BoundingBoxImageView()
        return imageView
    }()
    
    private lazy var textView: UITextView = {
        let textView = UITextView()
        return textView
    }()
    
    private lazy var scanButton: UIButton = {
        let button = UIButton()
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVision()
    }
    
    @objc private func scanButtonPressed() {
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = self
        present(scannerVC, animated: true, completion: nil)
    }
    
    private func setupVision() {
        textRecognitionRequest = VNRecognizeTextRequest{(request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {return}
            
            var detectedText = ""
            var boundingBoxes = [CGRect]()
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {return}
                detectedText += topCandidate.string
                detectedText += "\n"
                
                do {
                    guard let rectangle = try topCandidate.boundingBox(for: topCandidate.string.startIndex..<topCandidate.string.endIndex) else {return}
                    boundingBoxes.append(rectangle.boundingBox)
                } catch {
                    print(error)
                }
            }
            DispatchQueue.main.async {[weak self] in
                self?.scanButton.isEnabled = true
                self?.textView.text = detectedText
                self?.textView.flashScrollIndicators()
            }
        }
        
        textRecognitionRequest.recognitionLevel = .accurate
    }
    
    private func processImage(_ image: UIImage) {
        imageView.image = image
        imageView.removeBoundingBoxes()
        recognizeTextInImage(image)
    }
    
    private func recognizeTextInImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {return}
        
        textRecognitionWorkQueue.async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try requestHandler.perform([self.textRecognitionRequest])
            } catch {
                print(error)
            }
        }
    }
    
}

extension ViewController: VNDocumentCameraViewControllerDelegate {
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        for pageNumber in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageNumber)
        }
        controller.dismiss(animated: true, completion: nil)
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print(error)
        controller.dismiss(animated: true, completion: nil)
    }
}
