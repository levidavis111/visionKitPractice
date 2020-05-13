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
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        guard scan.pageCount > 0 else {controller.dismiss(animated: true, completion: nil); return}
        
        let originalImage = scan.imageOfPage(at: 0)
        let fixedImage = reloadedImage(originalImage)
        controller.dismiss(animated: true, completion: nil)
        processImage(fixedImage)
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print(error)
        controller.dismiss(animated: true, completion: nil)
    }
    
    private func reloadedImage(_ originalImage: UIImage) -> UIImage {
        guard let imageData = originalImage.jpegData(compressionQuality: 1), let reloadedImage = UIImage(data: imageData) else {return originalImage}
        return reloadedImage
    }
}
