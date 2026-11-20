//
//  RootViewController.swift
//  OnBoarding
//
//  Created by Greg on 10/04/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

import UIKit

class OnBoardingController: UIViewController, UIPageViewControllerDelegate , UIPageViewControllerDataSource {

    var pageViewController: UIPageViewController!
    
    var controllerIdentifiers : Array<String> = ["OB1","OB2","OB3","OB4"]
    var controllersStoryboard : UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    
    
    func viewControllerAtIndex(  index : Int ) -> OnBoardingDetailController? {
        
        if (self.controllerIdentifiers.count == 0) || (index >= self.controllerIdentifiers.count) {
            return nil
        }
        

        
        let identifier = controllerIdentifiers[index]
        let controller = self.controllersStoryboard.instantiateViewControllerWithIdentifier(identifier) as! OnBoardingDetailController
        controller.dataObject = identifier
        return controller
        
    }
    
    
    func indexOfViewController(viewController: OnBoardingDetailController) -> Int {
        // Return the index of the given data view controller.
        // For simplicity, this implementation uses a static array of model objects and the view controller stores the model object; you can therefore use the model object to identify the index.
        
        let dataObject = viewController.dataObject
        
        var index = 0
        for  controllerIdentifier in self.controllerIdentifiers {
            if controllerIdentifier == dataObject {
                return index
            }
            index++
        }
        
        return NSNotFound
        
    }
    
    // MARK: - Page View Controller Data Source
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        var index = self.indexOfViewController(viewController as! OnBoardingDetailController)
        if (index == 0) || (index == NSNotFound) {
            return nil
        }
        
        index--
        return self.viewControllerAtIndex(index)
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        var index = self.indexOfViewController(viewController as! OnBoardingDetailController)
        if index == NSNotFound {
            return nil
        }
        
        index++
        if index == self.controllerIdentifiers.count {
            return nil
        }
        return self.viewControllerAtIndex(index)
    }

    
    
    func setupPageController () {
        
        self.pageViewController = UIPageViewController(transitionStyle: .Scroll, navigationOrientation: .Horizontal, options: nil)
        self.pageViewController!.delegate = self
        
        let controller = viewControllerAtIndex(0)
        
        if let startingViewController = controller {
            let viewControllers = [startingViewController]
            self.pageViewController.setViewControllers(viewControllers, direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: {done in })
        }
        
        
        self.pageViewController!.dataSource = self
        
        self.addChildViewController(self.pageViewController!)
        self.view.addSubview(self.pageViewController!.view)
        
        // Set the page view controller's bounds using an inset rect so that self's view is visible around the edges of the pages.
        var pageViewRect = self.view.bounds
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            pageViewRect = CGRectInset(pageViewRect, 40.0, 40.0)
        }
        self.pageViewController!.view.frame = pageViewRect
        
        self.pageViewController!.didMoveToParentViewController(self)
        
        // Add the page view controller's gesture recognizers to the book view controller's view so that the gestures are started more easily.
        self.view.gestureRecognizers = self.pageViewController!.gestureRecognizers
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // Configure the page view controller and add it as a child view controller.
       setupPageController()
    }


   
    func pageViewController(pageViewController: UIPageViewController, spineLocationForInterfaceOrientation orientation: UIInterfaceOrientation) -> UIPageViewControllerSpineLocation {
        
        let currentViewController = self.pageViewController!.viewControllers[0] as! UIViewController
        let viewControllers = [currentViewController]
        self.pageViewController!.setViewControllers(viewControllers, direction: .Forward, animated: true, completion: {done in })

        self.pageViewController!.doubleSided = false
        return .Min
      
    }
    
    
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return self.controllerIdentifiers.count
    }
   
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        let currentController = pageViewController.viewControllers[0] as! OnBoardingDetailController
        return self.indexOfViewController(currentController)
    }


}

