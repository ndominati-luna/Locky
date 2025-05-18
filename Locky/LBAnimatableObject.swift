//
//  LBAnimatableObject.swift
//  OnBoarding
//
//  Created by Greg on 13/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import Foundation
import UIKit



protocol LBAnimatableObject {
    func shouldStartAnimationOnViewWillAppear () -> Bool
    func shouldInitAnimationOnViewWillAppear () -> Bool
    
    func setAnimProgress( _ progress : CGFloat , animated : Bool )
    
    func applyDefaultAnimationParam( _ model : LBAnimatableObject)
    
    func stopCurrentAnimation()
    func nextAnimatedObject() -> LBAnimatableObject?
    
    
    
    var nextDelay: Float  { set get}
    
    var a0Alpha: CGFloat { set get  }
    var a1Alpha: CGFloat { get set }
    var a0Scale: CGFloat { get set }
    var a1Scale: CGFloat { get set }
    var a0Rotation: CGFloat { get set }
    var a1Rotation: CGFloat { get set }
	var a0XTranslation: CGFloat { get set}
	var a1XTranslation: CGFloat { get set }
	var a0YTranslation: CGFloat { get set}
	var a1YTranslation: CGFloat { get set }
    var aDuration : Float { get set }
    var animProgress : CGFloat { set get }
    var dumping : CGFloat { get set }
    var initialVelocity : CGFloat { get set }
    var delay : Float { get set }
    
    
    
    
    
}



extension  UIView  {
    
    //    class func copyDefaultAnimationParam( fromObject :  LBAnimatableObject,  inout toObject : LBAnimatableObject) ->() {
    //
    //        toObject.a0Alpha = fromObject.a0Alpha
    //        toObject.a1Alpha = fromObject.a1Alpha
    //        toObject.a0Rotation = fromObject.a0Rotation
    //        toObject.a1Rotation = fromObject.a1Rotation
    //        toObject.a0Scale = fromObject.a0Scale
    //        toObject.a1Scale = fromObject.a1Scale
    //        toObject.aDuration = fromObject.aDuration
    //        toObject.aDelay = fromObject.aDelay
    //        toObject.dumping = fromObject.dumping
    //        toObject.initialVelocity = fromObject.initialVelocity
    //
    //    }
    
    
    class func setAnimationProgressOnObject( _ animatableObject : LBAnimatableObject , progress : CGFloat , animated : Bool , delay : Float) {
        if   animated {
            
            UIView.animate(withDuration: TimeInterval(animatableObject.aDuration), delay: TimeInterval(animatableObject.delay) + TimeInterval(delay) , usingSpringWithDamping: animatableObject.dumping, initialSpringVelocity: animatableObject.initialVelocity, options: UIView.AnimationOptions(), animations: { () -> Void in
                animatableObject.setAnimProgress(progress, animated: false)
                
                }, completion: { (succeed) -> Void in
                    
                    if  succeed {
                        if let nextObject = animatableObject.nextAnimatedObject()  {
                           // nextObject.applyDefaultAnimationParam(animatableObject)
                            
                            
                            self.setAnimationProgressOnObject(nextObject, progress: progress, animated: animated, delay: animatableObject.nextDelay)
                            
                            
                            
                            
                        }
                        
                    }
            })
            
            
            
        }
        else {
            animatableObject.setAnimProgress(progress, animated: false)
            
        }
    }
}
