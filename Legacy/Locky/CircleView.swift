//
//  CirclePFImageView.swift
//  LagonProject
//
//  Created by Greg on 23/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit

@IBDesignable class CircleView: UIView {
    
    //var roundColor = UIColor.whiteColor()
    
    @IBInspectable var color: UIColor = UIColor.black    {
        didSet {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = self.frame.size.width/2.0
        self.clipsToBounds = true
        
        self.layer.borderWidth = 4
        
        self.layer.borderColor = self.color.cgColor
    }
   
}
