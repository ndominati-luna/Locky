//
//  LBLockyButton.swift
//  OnBoarding
//
//  Created by Greg on 10/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit

class LBLockyButton: LBAnimatableButton {

    override func applyCustomStyle ( ) {
        
        self.titleLabel?.font = UIFont.boldSystemFontOfSize(25)
        self.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        self.BackgroundC =  UIColor(white: 1, alpha: 0.3)
        self.cornerRadius = 8
        self.verticalMargin = 10
        self.horizontalMargin = 20
        self.a0Alpha = 0
        self.a1Alpha = 1
        self.a0Scale = 0.9
        self.a1Scale = 1
        self.aDuration = 0.5
        self.dumping = 0.5
        self.initialVelocity = 0
        
        
        
    }

}
