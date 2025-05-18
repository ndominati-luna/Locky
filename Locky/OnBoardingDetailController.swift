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
	@IBOutlet var thiefEyes: LBAnimatableImageView!
	@IBOutlet var intrudersSwitch: UISwitch!
	
	@IBOutlet var intrudersLabel: UILabel!
	
	var dataObject: String!
    var isOpenedFromSettings: Bool = false


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor.clear
		self.view.translate()
		
		if isOpenedFromSettings {
            animatableButton?.setTitle(NSLocalizedString("Go back to Locky", comment: ""), for:UIControl.State())
			
			if let eyesImage = thiefEyes, let _ = intrudersSwitch, let _ = intrudersLabel {
				eyesImage.imageColor = UIColor.darkGray
				intrudersSwitch.removeFromSuperview()
				intrudersLabel.removeFromSuperview()
			}
		}
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        executeActionOnAnimatableObject { (animatableObject) -> () in
            animatableObject.stopCurrentAnimation()
            if  animatableObject.shouldStartAnimationOnViewWillAppear() {
                animatableObject.setAnimProgress(1, animated: true)
            }
        }
        
    }
    
    func executeActionOnAnimatableObject ( _ action : (_ object : LBAnimatableObject) ->() ) {

        for subview in self.view.subviews {
            if  let animatableObject = subview as? LBAnimatableObject {
                action(animatableObject)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        executeActionOnAnimatableObject({$0.stopCurrentAnimation()})

    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        executeActionOnAnimatableObject { (animatableObject) -> () in
            if  animatableObject.shouldInitAnimationOnViewWillAppear() {
                animatableObject.setAnimProgress(0, animated: false)
            }
        }
    }

	@IBAction func enjoyButtonPressed(_ sender: AnyObject) {
		self.dismiss(animated: true, completion: nil)
	}

	@IBAction func intrudersSwitchValueChanged(_ sender: UISwitch) {
		UserDefaults.saveUseBreak(inReport: NSNumber(value: sender.isOn as Bool));
		
		if (LockyManager.sharedInstance() as AnyObject).isMacConnected!
		{
			(LockyManager.sharedInstance() as AnyObject).sendBreakInReportStatus()
		}
	}
}

