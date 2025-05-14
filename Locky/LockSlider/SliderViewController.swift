//
//  SliderViewController.swift
//  ComponentsDemo
//
//  Created by Greg on 04/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit
import Darwin

@objc protocol SliderViewControllerDelegate
{
    func sliderViewControllerDidLock( _ controler : SliderViewController )
    func sliderViewControllerDidUnlock( _ controler : SliderViewController )
}


let alphaForDisable : CGFloat = 0.7

class SliderViewController: UIViewController {

    var delegate : SliderViewControllerDelegate!
    
    var sliderUnlockMode = true
    
    
    
    
    
    @IBOutlet var sliderVisualEffect: UIVisualEffectView!
    @IBOutlet var sliderLabel: UILabel!
    @IBOutlet var blurEffectView: UIVisualEffectView!
    
    @IBOutlet var lockButton: UIButton!
    @IBOutlet var slider: UIImageView!
    
    
    
    var unlockGesture : UIPanGestureRecognizer!
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        blurEffectView.layer.cornerRadius = blurEffectView.bounds.size.height / 2.0
        blurEffectView.layer.masksToBounds = true
    }
    
    func setupGesture() {
        let swipGesture = UIPanGestureRecognizer(target: self, action: #selector(SliderViewController.swipeHandler(_:)))
        self.slider.isUserInteractionEnabled = true
        self.slider.addGestureRecognizer(swipGesture)
        self.unlockGesture = swipGesture
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGesture()

        //setup initial state
        if  sliderUnlockMode {
            self.switchToUnlockMode(false)
        }
        else {
            self.switchToLockMode(false )
        }
        
    }
    
    
    
    
    
    
    
    func maxTranslation() -> CGFloat {
        return self.view.frame.size.width - 2.0 * self.slider.center.x
    }
    
    
    func switchToUnlockMode( _ animated : Bool ) {
        
        
        self.sliderUnlockMode = true
        
        self.slider.stopUnderteminedRotatinAnimation()
        
        self.slider.layer.cornerRadius = self.slider.bounds.size.height / 2.0
        self.slider.layer.masksToBounds = true
        self.sliderLabel.text = NSLocalizedString("slide to unlock", comment: "")
        self.sliderLabel.animateLeftToRight()
        
        if  animated {
            self.unlockGesture.isEnabled = false
            UIView.transition(with: self.slider, duration: 0.3, options: UIViewAnimationOptions.transitionCrossDissolve, animations: { () -> Void in
                self.slider.image = UIImage(named: "sliderUnlockButton")
                }) { (completed) -> Void in
                    self.unlockGesture.isEnabled = true
                    self.bringBackSliderTo(true, recognizer: self.unlockGesture, completion : nil)
            }
        }
        else {
            self.slider.image = UIImage(named: "sliderUnlockButton")
            self.moveSlider(0)
        }
        
        
    }

    func switchToLockMode( _ animated : Bool) {
        
        self.slider.stopUnderteminedRotatinAnimation()
        self.sliderUnlockMode = false
        
        self.slider.layer.cornerRadius = self.slider.bounds.size.height / 2.0
        self.slider.layer.masksToBounds = true
        self.sliderLabel.text = NSLocalizedString("slide to lock", comment: "")
        self.sliderLabel.animateLeftToRight()
        
        if  animated {
            self.unlockGesture.isEnabled = false
            UIView.transition(with: self.slider, duration: 0.3, options: UIViewAnimationOptions.transitionCrossDissolve, animations: { () -> Void in
                self.slider.image = UIImage(named: "sliderLockButton")
                }) { (completed) -> Void in
                    self.unlockGesture.isEnabled = true
                    self.bringBackSliderTo(true, recognizer: self.unlockGesture, completion : nil)
            }
        }
        else {
            self.slider.image = UIImage(named: "sliderLockButton")
            self.moveSlider(0)
        }
        
        
        
        
    }
    
    
    
    
    func bringBackSliderTo(_ initialPosition : Bool,  recognizer : UIPanGestureRecognizer , completion : ((Bool) -> ())? )  {
        
        recognizer.isEnabled = false
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: UIViewAnimationOptions(), animations: { () -> Void in
            self.moveSlider(initialPosition ? 0 : self.maxTranslation() )
            self.slider.alpha = initialPosition ? 1 : alphaForDisable
            
            }) { (completed) -> Void in
                self.unlockGesture.isEnabled = true
                
                if  let myCompletion = completion {
                    myCompletion(true)
                }
                
        }
        
    }
    
    func moveSlider( _ translation : CGFloat ) {
        
        let progress : CGFloat = translation / maxTranslation()
        let maxRotation : CGFloat =  0//progress * 2 * CGFloat( M_PI )
       //println(self.slider.frame.height )
        let rotation = CGAffineTransform(  rotationAngle: maxRotation )
        let transform = CGAffineTransform(translationX: translation, y: 0)
        self.slider.transform = rotation.concatenating(transform)
        self.sliderLabel.alpha =  (1 - 2 * progress)
    }
    
    func changeState( ) {
        
        if  self.unlockGesture.isEnabled == false {
            print("Not expected case")
        }
        
            self.unlockGesture.isEnabled = false
            
            self.slider.addUnderteminedRotatingLayer()
            self.slider.startUnderteminedRotatinAnimation()
            
            let delay = 0.1 * Double(NSEC_PER_SEC)
            let time = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter( deadline: time , execute: { () -> Void in
                if self.sliderUnlockMode {
                    self.delegate.sliderViewControllerDidUnlock(self)
                } else {
                    self.delegate.sliderViewControllerDidLock(self)
                }
            })
        
    }
    
    func swipeHandler(_ recognizer : UIPanGestureRecognizer) {
        
        let translation = recognizer.translation(in: self.view)
        
        if recognizer.state == UIGestureRecognizerState.ended || recognizer.state == UIGestureRecognizerState.cancelled{
            if translation.x >= maxTranslation()  {
                changeState()
            }
            else {
                let velocity  = recognizer.velocity(in: self.view)
                
                print(velocity.x)
                if  velocity.x < 500 {
                    bringBackSliderTo( true , recognizer: recognizer , completion: nil)
                }
                else {
                    bringBackSliderTo(false, recognizer: recognizer, completion: { (completed) -> () in
                        self.changeState()
                    })
                }
            }
            
        }
        else {
            moveSlider(min( max(0, translation.x),self.maxTranslation()))
        }
    }

}

