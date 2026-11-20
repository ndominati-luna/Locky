//
//  RootViewController.swift
//  OnBoarding
//
//  Created by Greg on 10/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit

@objcMembers
class OnBoardingController: UIViewController, UIPageViewControllerDelegate , UIPageViewControllerDataSource {

	@IBOutlet var backgroundImageView: UIImageView!
	var backgroundImage: UIImage!
    var pageViewController: UIPageViewController!
	
	var isOpenedFromSettings: Bool = false
	
	var controllerIdentifiers : Array<String> = ["OB1","OB2","OB4","OB5"]
    var controllersStoryboard : UIStoryboard = UIStoryboard(name: "Tips", bundle: nil)
    
    
    func viewControllerAtIndex(  _ index : Int ) -> OnBoardingDetailController? {
        
        if (self.controllerIdentifiers.count == 0) || (index >= self.controllerIdentifiers.count) {
            return nil
        }
        

        
        let identifier = controllerIdentifiers[index]
        let controller = self.controllersStoryboard.instantiateViewController(withIdentifier: identifier) as! OnBoardingDetailController
        controller.dataObject = identifier
		controller.isOpenedFromSettings = isOpenedFromSettings
        return controller
    }
    
    
    func indexOfViewController(_ viewController: OnBoardingDetailController) -> Int {
        // Return the index of the given data view controller.
        // For simplicity, this implementation uses a static array of model objects and the view controller stores the model object; you can therefore use the model object to identify the index.
        
        let dataObject = viewController.dataObject
        
        var index = 0
        for  controllerIdentifier in self.controllerIdentifiers {
            if controllerIdentifier == dataObject {
                return index
            }
            index += 1
        }
        
        return NSNotFound
        
    }
    
    // MARK: - Page View Controller Data Source -
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        var index = self.indexOfViewController(viewController as! OnBoardingDetailController)
        if (index == 0) || (index == NSNotFound) {
            return nil
        }
        
        index -= 1
        return self.viewControllerAtIndex(index)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        var index = self.indexOfViewController(viewController as! OnBoardingDetailController)
        if index == NSNotFound {
            return nil
        }
        
        index += 1
        if index == self.controllerIdentifiers.count {
            return nil
        }
        return self.viewControllerAtIndex(index)
    }

    
    
    func setupPageController () {
        
        self.pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        self.pageViewController!.delegate = self
        
        let controller = viewControllerAtIndex(0)
        
        if let startingViewController = controller {
            let viewControllers = [startingViewController]
            self.pageViewController.setViewControllers(viewControllers, direction: UIPageViewController.NavigationDirection.forward, animated: false, completion: {done in })
        }
        
        
        self.pageViewController!.dataSource = self
        
        self.addChild(self.pageViewController!)
        self.view.addSubview(self.pageViewController!.view)
        
        // Set the page view controller's bounds using an inset rect so that self's view is visible around the edges of the pages.
        var pageViewRect = self.view.bounds
        if UIDevice.current.userInterfaceIdiom == .pad {
            pageViewRect = pageViewRect.insetBy(dx: 40.0, dy: 40.0)
        }
        self.pageViewController!.view.frame = pageViewRect
        
        self.pageViewController!.didMove(toParent: self)
        
        // Add the page view controller's gesture recognizers to the book view controller's view so that the gestures are started more easily.
        self.view.gestureRecognizers = self.pageViewController!.gestureRecognizers
    }

    override func viewDidLoad() {
        super.viewDidLoad()
		
		if let image = self.backgroundImage {
			self.backgroundImageView.image = image
		}
		
		if let navController = self.navigationController {
			navController.navigationBar.tintColor = UIColor(white: 1, alpha: 0.3)
			navController.navigationBar.setBackgroundImage(UIImage(), for: .default)
			navController.navigationBar.isOpaque = false
			navController.navigationBar.isTranslucent = true
			navController.navigationBar.shadowImage = UIImage()
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.stop, target: self, action: #selector(OnBoardingController.closeTips))
		}
		
		if isOpenedFromSettings {
			controllerIdentifiers = ["OB1","OB2","OB4","OB5"]
		}
		
		setupPageController()
    }

	@objc func closeTips() {
		dismiss(animated: true, completion: nil)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		// In order to run the animation when the controller is presented modally we need to "transfer" this event
		// to the child view controller. But only in the case that this controller is not in a navigation controller.
		if let _ = self.navigationController {
			
		} else {
			if let controllers = self.pageViewController.viewControllers {
				controllers.first?.viewWillAppear(animated)
			}
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// In order to run the animation when the controller is presented modally we need to "transfer" this event
		// to the child view controller. But only in the case that this controller is not in a navigation controller.
		if let _ = self.navigationController {
			
		} else {
			if let controllers = self.pageViewController.viewControllers {
				controllers.first?.viewDidAppear(animated)
			}
		}
	}
	
    func pageViewController(_ pageViewController: UIPageViewController, spineLocationFor orientation: UIInterfaceOrientation) -> UIPageViewController.SpineLocation {
        
        let currentViewController = self.pageViewController!.viewControllers![0]
        let viewControllers = [currentViewController]
        self.pageViewController!.setViewControllers(viewControllers, direction: .forward, animated: true, completion: {done in })

        self.pageViewController!.isDoubleSided = false
        return .min
      
    }
    
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return self.controllerIdentifiers.count
    }
   
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        let currentController = pageViewController.viewControllers![0] as! OnBoardingDetailController
        return self.indexOfViewController(currentController)
    }


}

