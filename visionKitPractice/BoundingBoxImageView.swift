//
//  BoundingBoxImageView.swift
//  visionKitPractice
//
//  Created by Levi Davis on 5/12/20.
//  Copyright © 2020 Levi Davis. All rights reserved.
//

import UIKit
import Vision
//Custom UIImage subclass that adds support for adding bounding boxes
class BoundingBoxImageView: UIImageView {
//    The bounding boxes that will show in the view
    private var boundingBoxViews = [UIView]()
    
//    Loads each individual boundingBox into the array.
    func load(boundingBoxes: [CGRect]) {
        removeBoundingBoxes()
        
        for box in boundingBoxes {
            load(boundingBox: box)
        }
    }
//    Removes all boundingBox subviews from superview and from the array.
    func removeBoundingBoxes() {
        for view in boundingBoxViews {
            view.removeFromSuperview()
        }
        boundingBoxViews.removeAll()
    }
    
    private func load(boundingBox: CGRect) {
        // Cache the image rectangle to avoid unneccessary work
        let imageRect = self.imageRect
//        Creat a mutable instance of a bounding box to be handled later.
        var boundingBox = boundingBox
        // Flip the Y axis of the bounding box because Vision uses a different coordinate system to that of UIKit
        boundingBox.origin.y = 1 - boundingBox.origin.y
        
//        Convert the boundingBox based on the imageRect
        var convertedBoundingBox = VNImageRectForNormalizedRect(boundingBox, Int(imageRect.width), Int(imageRect.height))
        
//        Adjust the boundingBox based on the position of the image inside the imageView
         // Note that we only adjust the axis that is not the same in both--because we're using `scaleAspectFit`, one of the axis will always be equal
        if frame.width - imageRect.width != 0 {
            convertedBoundingBox.origin.x += imageRect.origin.x
            convertedBoundingBox.origin.y -= convertedBoundingBox.height
        } else if frame.height - imageRect.height != 0 {
            convertedBoundingBox.origin.y += imageRect.origin.y
            convertedBoundingBox.origin.y -= convertedBoundingBox.height
        }
//        Enlarge the boundingBox so the text fits nicely.
        let enlargementAmount = CGFloat(2.2)
        convertedBoundingBox.origin.x -= enlargementAmount
        convertedBoundingBox.origin.y -= enlargementAmount
        convertedBoundingBox.size.width += enlargementAmount * 2
        convertedBoundingBox.size.height += enlargementAmount * 2
        
//        Create a view with a narrow border and transparent background as the bounding box
        let view = UIView(frame: convertedBoundingBox)
        view.layer.opacity = 1
        view.layer.borderColor = UIColor.orange.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 2
        view.layer.masksToBounds = true
        view.backgroundColor = .clear
        addSubview(view)
        boundingBoxViews.append(view)
    }
}
