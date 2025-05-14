//
//  SpecialButtonViewController.swift
//  ComponentsDemo
//
//  Created by Greg on 29/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit
import Darwin

@objc protocol SpecialButtonViewControllerDelegate
{
    func specialButtonViewControllerDidLock( _ controler : SpecialButtonViewController )
    func specialButtonViewControllerDidUnlock( _ controler : SpecialButtonViewController )
}

class SpecialButtonViewController: UIViewController {



    
    var delegate : SpecialButtonViewControllerDelegate!
        
    var unlockMode = true
        
    @IBOutlet var extrenalCircle: CircleView!
   
    @IBOutlet var lockButton: UIButton!
    @IBOutlet var lockLabel: UILabel!
        
 
      
        override func viewDidLoad() {
            super.viewDidLoad()
            
            //setup initial state
            if  unlockMode {
                self.switchToUnlockMode(false)
            }
            else {
                self.switchToLockMode(false )
            }
            
        }
        
        
        
        
        
        
        
       
        func switchToUnlockMode( _ animated : Bool ) {
            
            self.unlockMode = true
            
            
            self.lockButton.stopUnderteminedRotatinAnimation()
            
            
            self.lockButton.layer.cornerRadius = self.lockButton.bounds.size.height / 2.0
            self.lockButton.layer.masksToBounds = true
            self.lockLabel.text = NSLocalizedString("unlock", comment: "unlock")
            
            let animeBlock = { () -> Void in
                self.lockButton.setImage(UIImage(named: "Locky-FlatBlue"), for: UIControlState())
                self.lockLabel.alpha = 1
                self.extrenalCircle.color = self.flatBlue()
            }
            
            if  animated {
                UIView.transition(with: self.lockButton, duration: 0.3, options: UIViewAnimationOptions.transitionCrossDissolve, animations: animeBlock) { (completed) -> Void in
                        
                }
            }
            else {
               animeBlock()
            }
            
            
        }
        
    func flatBlue() -> UIColor {
        return UIColor(red: 28.0/256.0, green: 145.0/256.0, blue: 245.0/256.0, alpha: 1)
    }
    
    func flatRed() -> UIColor {
        return UIColor(red: 255.0/256.0, green: 91.0/256.0, blue: 82.0/256.0, alpha: 1)
    }
        
        
        
        func switchToLockMode( _ animated : Bool) {
            
            self.lockButton.stopUnderteminedRotatinAnimation()
            self.unlockMode = false
            
            
            
            self.lockButton.layer.cornerRadius = self.lockButton.bounds.size.height / 2.0
            self.lockButton.layer.masksToBounds = true
            self.lockLabel.text = NSLocalizedString("lock", comment: "lock")
            
            let animeBlock = { () -> Void in
                self.lockButton.setImage(UIImage(named: "Locky-FlatRed"), for: UIControlState())
                self.lockLabel.alpha = 1
                self.extrenalCircle.color = self.flatRed()
            }
            
            if  animated {
                UIView.transition(with: self.lockButton, duration: 0.3, options: UIViewAnimationOptions.transitionCrossDissolve, animations: animeBlock ) { (completed) -> Void in
                        
                }
            }
            else {
               animeBlock()
               
            }
            
            
            
            
        }
    
    @IBAction func lockButtonPressed(_ sender: AnyObject) {
        changeState()
    }
        
    
        func changeState( ) {
            if self.unlockMode {
                
                self.lockButton.addUnderteminedRotatingLayer()
                self.lockButton.startUnderteminedRotatinAnimation()
                self.lockLabel.alpha = 0
                
                self.dispatchMainAfter(0.1, block: { () -> Void in
                   self.delegate.specialButtonViewControllerDidUnlock(self)
                })
                
                
                
                
                
            }
            else {
                
                self.lockLabel.alpha = 0
                self.lockButton.addUnderteminedRotatingLayer()
                self.lockButton.startUnderteminedRotatinAnimation()
                
                
                self.dispatchMainAfter(0.1, block: { () -> Void in
                    self.delegate.specialButtonViewControllerDidLock(self)
                })
                
                
                
            }
        }
        
    
   

}
