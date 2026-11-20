//
//  DataViewController.swift
//  OnBoarding
//
//  Created by Greg on 10/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit

class OnBoardingDetailController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var mainSubtitleLabel : UILabel?
    @IBOutlet weak var secondSubtitleLabel : UILabel?
    @IBOutlet var animatableButton: LBAnimatableButton?
    @IBOutlet var animatableImageView: LBAnimatableImageView?
    var dataObject: String!
    


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor.clearColor()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        executeActionOnAnimatableObject { (animatableObject) -> () in
            animatableObject.stopCurrentAnimation()
            if  animatableObject.shouldStartAnimationOnViewWillAppear() {
                animatableObject.setAnimProgress(1, animated: true)
            }
        }
        
    }
    
    func executeActionOnAnimatableObject ( action : (object : LBAnimatableObject) ->() ) {

        for subview in self.view.subviews {
            if  let animatableObject = subview as? LBAnimatableObject {
                action(object : animatableObject)
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        executeActionOnAnimatableObject({$0.stopCurrentAnimation()})

    }
    
    override func viewWillAppear(animated: Bool) {
        
        executeActionOnAnimatableObject { (animatableObject) -> () in
            if  animatableObject.shouldInitAnimationOnViewWillAppear() {
                animatableObject.setAnimProgress(0, animated: false)
            }
        }
        
 
    }


}

