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
	@IBInspectable var a0XTranslation: CGFloat = 0 { didSet{ setupView() }}
	@IBInspectable var a1XTranslation: CGFloat = 0 { didSet{ setupView() }}
	@IBInspectable var a0YTranslation: CGFloat = 0 { didSet{ setupView() }}
	@IBInspectable var a1YTranslation: CGFloat = 0 { didSet{ setupView() }}
    @IBInspectable var aDuration : Float = 0.3 { didSet{ setupView() }}
    @IBInspectable var animProgress : CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var dumping : CGFloat = 1 { didSet{ setupView() }}
    @IBInspectable var initialVelocity : CGFloat = 0 { didSet{ setupView() }}
    @IBInspectable var delay : Float = 0 { didSet{ setupView() }}
    
	@IBInspectable var BackgroundC: UIColor = UIColor.clear { didSet{ setupView() }}
	@IBInspectable var imageColor: UIColor = UIColor.white {
		didSet{
			image = image?.withColor(imageColor)
			setupView()
		}
	}
    @IBInspectable var nextDelay: Float = 0    { didSet{ }}
    
    func setAnimProgress( _ progress : CGFloat , animated : Bool ) {
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
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        applyCustomStyle()
        setupView()
    }
    
    override func prepareForInterfaceBuilder() {
        applyCustomStyle()
        setupView()
    }
    
    func applyCustomStyle ( ) { // to be customized
    }
    
    
    // Setup the view appearance
    func setupView(){

        self.backgroundColor = BackgroundC
        self.alpha =  (a1Alpha - a0Alpha) * animProgress + a0Alpha
        
        let rotationDegree =  (a1Rotation - a0Rotation ) * animProgress + a0Rotation
        let rotationRadian = GLKMathDegreesToRadians( Float(rotationDegree))
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(rotationRadian))
		
		let xTranslation = (a1XTranslation - a0XTranslation) * animProgress + a0XTranslation
		let translationTransform = CGAffineTransform(translationX: xTranslation, y: 0)
		self.transform = rotationTransform.concatenating(translationTransform)
		
		let yTranslation = (a1YTranslation - a0YTranslation) * animProgress + a0YTranslation
		let translationYTransform = CGAffineTransform(translationX: 0, y: yTranslation)
		self.transform = self.transform.concatenating(translationYTransform)
		
        let scale = (a1Scale - a0Scale) * animProgress + a0Scale
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        self.transform = self.transform.concatenating(scaleTransform)
		
        self.setNeedsDisplay()
        self.setNeedsLayout()
    }
    
  
    func applyDefaultAnimationParam( _ model : LBAnimatableObject) {
        
        
        self.a0Alpha = model.a0Alpha
        self.a1Alpha = model.a1Alpha
        self.a0Rotation = model.a0Rotation
        self.a1Rotation = model.a1Rotation
        self.a0Scale = model.a0Scale
        self.a1Scale = model.a1Scale
		self.a0XTranslation = model.a0XTranslation
		self.a1XTranslation = model.a1XTranslation
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
