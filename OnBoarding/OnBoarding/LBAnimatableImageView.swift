//
//  LBAnimatableButton.swift
//  OnBoarding
//
//  Created by Greg on 10/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit
import GLKit

@IBDesignable class LBAnimatableImageView: UIImageView , LBAnimatableObject{

    // MARK: Inspectable properties ******************************
    @IBInspectable var shouldAnimateOnViewDidLoad: Bool = false    { didSet{}}
    
   
    
    @IBInspectable var a0Alpha: CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var a1Alpha: CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var a0Scale: CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var a1Scale: CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var a0Rotation: CGFloat = 0 { didSet{ setupView() }}
    @IBInspectable var a1Rotation: CGFloat = 0 { didSet{ setupView() }}
    @IBInspectable var aDuration : Float = 0.3 { didSet{ setupView() }}
    @IBInspectable var animProgress : CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var dumping : CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var initialVelocity : CGFloat = 0 { didSet{ setupView() }}
    @IBInspectable var delay : Float = 0 { didSet{ setupView() }}
    
    @IBInspectable var BackgroundC: UIColor = UIColor.clearColor() { didSet{ setupView() }}
    @IBInspectable var nextDelay: Float = 0    { didSet{ }}
    
    
   
   
    
    
    func setAnimProgress( progress : CGFloat , animated : Bool ) {
        if   animated {
            UIView.setAnimationProgressOnObject(self, progress: progress, animated: animated, delay: 0)
        }
        else {
            self.animProgress = progress
            
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCustomStyle()
        setupView()
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        applyCustomStyle()
        setupView()
    }
    
    override func prepareForInterfaceBuilder() {
        applyCustomStyle()
        setupView()
    }
    
    func applyCustomStyle ( ) { // to be customized}
    }
    
    
    // Setup the view appearance
    func setupView(){

        self.backgroundColor = BackgroundC
        self.alpha =  (a1Alpha - a0Alpha) * animProgress + a0Alpha
        
        let rotationDegree =  (a1Rotation - a0Rotation ) * animProgress + a0Rotation
        let rotationRadian = GLKMathDegreesToRadians( Float(rotationDegree))
        let rotationTransform = CGAffineTransformMakeRotation(CGFloat(rotationRadian))
        
        let scale = (a1Scale - a0Scale) * animProgress + a0Scale
        let scaleTransform = CGAffineTransformMakeScale(scale, scale)
        self.transform = CGAffineTransformConcat(rotationTransform, scaleTransform)
        
        
        
        self.setNeedsDisplay()
        self.setNeedsLayout()
        
    }
    
  
    func applyDefaultAnimationParam( model : LBAnimatableObject) {
        
        
        self.a0Alpha = model.a0Alpha
        self.a1Alpha = model.a1Alpha
        self.a0Rotation = model.a0Rotation
        self.a1Rotation = model.a1Rotation
        self.a0Scale = model.a0Scale
        self.a1Scale = model.a1Scale
        self.aDuration = model.aDuration
        self.delay = model.delay
        self.dumping = model.dumping
        self.initialVelocity = model.initialVelocity
        
    }
    
    func nextAnimatedObject() -> LBAnimatableObject? {
        return self.nextAnimatedImageView
    }
    
    func stopCurrentAnimation() {
        self.layer.removeAllAnimations()
    }
    
    func shouldInitAnimationOnViewWillAppear () -> Bool{
        return true
    }
    
    func shouldStartAnimationOnViewWillAppear () -> Bool {
        return self.shouldAnimateOnViewDidLoad
    }
    
    @IBOutlet weak var nextAnimatedImageView : LBAnimatableImageView?
    
    

}
