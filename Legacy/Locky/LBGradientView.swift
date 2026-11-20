//
//  BWGradientView.swift
//  TBUIComponent
//
//  Created by Yari D'areglia on 06/09/14.
//  Copyright (c) 2014 Yari D'areglia. All rights reserved.
//

import UIKit
import QuartzCore
import GLKit

@IBDesignable class LBGradientView: UIView {
    

    // MARK: Inspectable properties ******************************
    
    @IBInspectable var startColor: UIColor = UIColor.white {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var endColor: UIColor = UIColor.black {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var startX: CGFloat = 0 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var startY: CGFloat = 0.5 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var endX: CGFloat = 1 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var endY: CGFloat = 0.5 {
        didSet{
            setupView()
        }
    }
    
    
    
    
    
    
    
    // MARK: Overrides ******************************************
    
    override class var layerClass:AnyClass{
        return CAGradientLayer.self
    }
    

    
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
 
        setupView()
    }
    
    
    
    // MARK: Internal functions *********************************
    
    
    // Setup the view appearance
    fileprivate func setupView(){
        
        let colors:Array<AnyObject> = [startColor.cgColor, endColor.cgColor]
        gradientLayer.colors = colors
        
      
        gradientLayer.startPoint = CGPoint(x: startX, y:startY)
        gradientLayer.endPoint = CGPoint(x: endX, y:endY)
     
        
        
        
      
        self.setNeedsDisplay()
        
    }
    
    // Helper to return the main layer as CAGradientLayer
    var gradientLayer: CAGradientLayer {
        return layer as! CAGradientLayer
    }
    
}
