//
//  ViewController.swift
//  VisionKitDemo
//
//  Created by Bruno Guedes on 14/10/19.
//  Copyright © 2019 Bruno Guedes. All rights reserved.
//

import UIKit
import VisionKit
import Vision

class ViewController: UIViewController {

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var documentImageView: UIImageView!
    @IBOutlet var textView: UITextView!
    @IBOutlet var documentImageViewHeightConstraint: NSLayoutConstraint!
    
    var textRecognitionRequest = VNRecognizeTextRequest()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        textRecognitionRequest = VNRecognizeTextRequest(completionHandler: { [weak self] (request, error) in
            if let results = request.results, !results.isEmpty, let recognizedTextObservations = request.results as? [VNRecognizedTextObservation] {
                var transcript = ""
                for textObservation in recognizedTextObservations {
                    DispatchQueue.main.async {
                        guard
                            let imageWidth = self?.documentImageView.image?.size.width,
                            let imageHeight = self?.documentImageView.image?.size.height,
                            let viewWidth = self?.documentImageView.bounds.size.width,
                            imageWidth != 0 else { return }
                        let viewHeight = viewWidth * imageHeight / imageWidth
                        self?.documentImageViewHeightConstraint.constant = viewHeight
                        let objectRect = VNImageRectForNormalizedRect(textObservation.boundingBox, Int(viewWidth), Int(viewHeight))
                        let boxFrame = CGRect(x: objectRect.origin.x, y: viewHeight - objectRect.origin.y - objectRect.size.height, width: objectRect.size.width, height: objectRect.size.height)
                        let view = UIView(frame: boxFrame)
                        view.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                        if let topCandidate = textObservation.topCandidates(1).first {
                            transcript += topCandidate.string + "\n"
                            let label = UILabel(frame: view.bounds)
                            label.text = topCandidate.string
                            label.textColor = .lightText
                            view.addSubview(label)
                        }
                        self?.documentImageView.addSubview(view)
                    }
                }
                self?.textView.text = transcript
            }
        })
        // This doesn't require OCR on a live camera feed, select accurate for more accurate results.
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
    }

    @IBAction func onTapScan(_ sender: Any) {
        documentImageView.subviews.forEach { $0.removeFromSuperview() }
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = self
        present(documentCameraViewController, animated: true)
    }
    
    func processImage(image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Failed to get cgimage from input image")
            return
        }
        
        DispatchQueue.main.async {
            self.documentImageView.image = image
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([textRecognitionRequest])
        } catch {
            print(error)
        }
    }
    
}

extension ViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        self.activityIndicator.startAnimating()
        controller.dismiss(animated: true) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                for pageNumber in 0 ..< scan.pageCount {
                    let image = scan.imageOfPage(at: pageNumber)
                    self?.processImage(image: image)
                }
                DispatchQueue.main.async {
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }
}
