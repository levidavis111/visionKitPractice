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
    
//    Recognition request defined later. Stored globally so it can be resued
    private var textRecognitionRequest = VNRecognizeTextRequest(completionHandler: nil)
    
//    Dedicated queue so the work can happen off the main thread.
    private let textRecognitionWorkQueue = DispatchQueue(label: "TextRecognitionQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private lazy var imageView: BoundingBoxImageView = {
        let imageView = BoundingBoxImageView()
        imageView.image = UIImage(named: "camera-icon")
        return imageView
    }()
    
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.text = "Text will go here."
        textView.font = UIFont(name: "Futura-Medium", size: 17)
        return textView
    }()
    
    private lazy var scanButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "camera-icon"), for: .normal)
        button.isEnabled = true
        button.addTarget(self, action: #selector(scanButtonPressed), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupVision()
        addSubViews()
        constrainSubviews()
    }
//    When pressed, checks to see it camera is available. If so, presentd VNDocument controller
    @objc private func scanButtonPressed() {
        print("Scan button pressed")
        checkCameraPermission()
    }
//    Configures vision recogntion request, with completion handler that is called later
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
                self?.imageView.load(boundingBoxes: boundingBoxes)
            }
        }
        
        textRecognitionRequest.recognitionLevel = .accurate
    }
//    Sets imageView, removes previous bounding boxes, attemps to reconginze text.
    private func processImage(_ image: UIImage) {
        imageView.image = image
        imageView.removeBoundingBoxes()
        recognizeTextInImage(image)
    }
//    Converts image, then calls request handler
    private func recognizeTextInImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {return}
        
        textView.text = ""
        scanButton.isEnabled = false
        
        textRecognitionWorkQueue.async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try requestHandler.perform([self.textRecognitionRequest])
            } catch {
                print(error)
            }
        }
    }
//    Checks camera availability. If available, presents VCDocument scanner.
    private func checkCameraPermission() {
        let cameraStatus = UIImagePickerController.isCameraDeviceAvailable(.rear)
        
        switch cameraStatus {
        case true:
            print("Rear camera available")
            presentScanner()
        case false:
            print("Rear camera not available")
        }
            
    }
//    Presents VNDocumens scanner.
    private func presentScanner() {
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = self
        present(scannerVC, animated: true, completion: nil)
    }
    
    private func addSubViews() {
        view.addSubview(imageView)
        view.addSubview(textView)
        view.addSubview(scanButton)
    }
    
    private func constrainSubviews() {
        constrainImageView()
        constrainTextView()
        constrainScanButton()
    }
    
    private func constrainImageView() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        [imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
         imageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
         imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
         imageView.heightAnchor.constraint(equalToConstant: view.safeAreaLayoutGuide.layoutFrame.height * 0.6)].forEach{$0.isActive = true}
    }
    
    private func constrainTextView() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        [textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
         textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
         textView.topAnchor.constraint(equalTo: imageView.bottomAnchor),
         textView.bottomAnchor.constraint(equalTo: scanButton.topAnchor)].forEach{$0.isActive = true}
    }
    
    private func constrainScanButton() {
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        [scanButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
         scanButton.heightAnchor.constraint(equalToConstant: 35),
         scanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)].forEach{$0.isActive = true}
    }
}

extension ViewController: VNDocumentCameraViewControllerDelegate {
//    Tells MainVC what to do when a scan from VNDocument VC is done.
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        guard scan.pageCount > 0 else {controller.dismiss(animated: true, completion: nil); return}
        
        let originalImage = scan.imageOfPage(at: 0)
        let fixedImage = reloadedImage(originalImage)
        controller.dismiss(animated: true, completion: nil)
        processImage(fixedImage)
    }
//    Error handling
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print(error)
        controller.dismiss(animated: true, completion: nil)
    }
    /// VisionKit currently has a bug where the images returned reference unique files on disk which are deleted after dismissing the VNDocumentCameraViewController.
    /// To work around this, we have to create a new UIImage from the data of the original image from VisionKit.
    private func reloadedImage(_ originalImage: UIImage) -> UIImage {
        guard let imageData = originalImage.jpegData(compressionQuality: 1), let reloadedImage = UIImage(data: imageData) else {return originalImage}
        return reloadedImage
    }
    
    
}
