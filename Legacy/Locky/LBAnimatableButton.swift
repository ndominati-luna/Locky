//
//  LBAnimatableButton.swift
//  OnBoarding
//
//  Created by Greg on 10/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit
import GLKit

@IBDesignable @objcMembers class LBAnimatableButton: UIButton , LBAnimatableObject {

    // MARK: Inspectable properties ******************************

    func nextAnimatedObject() -> LBAnimatableObject? {
        return nil
    }
    
    func shouldStartAnimationOnViewWillAppear () -> Bool {
        return self.shouldAnimateOnViewDidLoad
    }
    
    
    func stopCurrentAnimation() {
        self.layer.removeAllAnimations()
    }
    
    
    @IBInspectable var shouldAnimateOnViewDidLoad: Bool = true    {
        didSet{
            setupView()
        }
    }
    
    func shouldInitAnimationOnViewWillAppear () -> Bool{
        return true
    }
    
    @IBInspectable var cornerRadius : CGFloat = 0 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var BackgroundC: UIColor = UIColor.clear    {
        didSet{
            setupView()
        }
    }
    
   
    @IBInspectable var verticalMargin: CGFloat = 0 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var horizontalMargin: CGFloat = 0 {
        didSet{
            setupView()
        }
    }
    
    
    @IBInspectable var a0Alpha: CGFloat = 1 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var a1Alpha: CGFloat = 1 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var a0Scale: CGFloat = 1 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var a1Scale: CGFloat = 1 {
        didSet{
            setupView()
        }
    }
	
	@IBInspectable var a0XTranslation: CGFloat = 0 {
		didSet{
			setupView()
		}
	}
	
	@IBInspectable var a1XTranslation: CGFloat = 0 {
		didSet{
			setupView()
		}
	}
	
	@IBInspectable var a0YTranslation: CGFloat = 0 {
		didSet{
			setupView()
		}
	}
	
	@IBInspectable var a1YTranslation: CGFloat = 0 {
		didSet{
			setupView()
		}
	}
	
    @IBInspectable var a0Rotation: CGFloat = 0 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var a1Rotation: CGFloat = 0 {
        didSet{
            setupView()
        }
    }
    
    
    @IBInspectable var aDuration : Float = 0.3 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var animProgress : CGFloat = 1 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var dumping : CGFloat = 0.5 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var initialVelocity : CGFloat = 1 {
        didSet{
            setupView()
        }
    }
    
    @IBInspectable var delay : Float = 0 {
        didSet{
            setupView()
        }
    }
 
    func setAnimProgress( _ progress : CGFloat , animated : Bool ) {
        if   animated {
            UIView.setAnimationProgressOnObject(self, progress: progress, animated: animated, delay: 0)
        }
        else {
            self.animProgress = progress
            
        }
    }
    
    
    @IBInspectable var nextDelay: Float = 0    {
        didSet{
            
        }
    }
    

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCustomStyle()
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        applyCustomStyle()
        setupView()
    }
    
    override func prepareForInterfaceBuilder() {
        applyCustomStyle()
        setupView()
    }
    
    func applyCustomStyle ( ) {
        // to be subclassed
        
    }
    
 
    
    // Setup the view appearance
    func setupView(){
        
        self.layer.cornerRadius = cornerRadius
        self.layer.masksToBounds = true
        self.backgroundColor = BackgroundC
        self.alpha =  (a1Alpha - a0Alpha) * animProgress + a0Alpha
        
        let rotationDegree =  (a1Rotation - a0Rotation ) * animProgress + a0Rotation
        let rotationRadian = GLKMathDegreesToRadians( Float(rotationDegree))
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(rotationRadian))
		
		let xTranslation = (a1XTranslation - a0XTranslation) * animProgress + a0XTranslation
		let translationTransform = CGAffineTransform(translationX: xTranslation, y: 0)
		self.transform = rotationTransform.concatenating(translationTransform)
		
        let scale = (a1Scale - a0Scale) * animProgress + a0Scale
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        self.transform = self.transform.concatenating(scaleTransform)
        
        self.contentEdgeInsets = UIEdgeInsets(top: verticalMargin, left: horizontalMargin, bottom: verticalMargin, right: horizontalMargin)
        
        self.setNeedsDisplay()
        self.setNeedsLayout()
        
    }
    
    
    func applyDefaultAnimationParam( _ model : LBAnimatableObject) {
        
    }
    
  

}
