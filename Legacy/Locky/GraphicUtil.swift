//
//  GraphicUtil.swift
//  Locky
//
//  Created by Greg on 29/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

import Foundation

extension UIView {
    
    
    
    
    func startUnderteminedRotatinAnimation() {
        
        let spinAnimation = CABasicAnimation(keyPath: "transform.rotation");
        
        let value: Float = 2.0 * .pi
        spinAnimation.toValue        = NSNumber(value: value)
        spinAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        spinAnimation.duration       = 1.0;
        spinAnimation.repeatCount    = Float.infinity;
        
        if  let  circleLayer = self.circleLayerView() {
            //circleLayer.anchorPoint = CGPoint(x: 0.5 , y: 0.5 )
            circleLayer.layer.add(spinAnimation, forKey: "spinAnimation")
        }
        
    }
    
    func addUnderteminedRotatingLayer() {
        
        let circleView = UIView(frame: self.bounds)
        circleView.tag = 123456
        circleView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let circleLayer = CAShapeLayer()
        circleLayer.lineWidth = 2;
        circleLayer.fillColor = nil
        
        
        let bezierPath = UIBezierPath()
        bezierPath.addArc(withCenter: CGPoint(x: self.bounds.width / 2 , y: self.bounds.width / 2), radius: (self.bounds.width - circleLayer.lineWidth ) / 2.0 , startAngle: 0, endAngle:  0.2 * .pi, clockwise: true)
        circleLayer.path = bezierPath.cgPath
        
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.contentsScale = UIScreen.main.scale
        circleLayer.shouldRasterize = false
        
        circleView.layer.addSublayer(circleLayer)
        self.addSubview(circleView)
        
    }
    
    func stopUnderteminedRotatinAnimation() {
        
        
        if let circleView = self.circleLayerView() {
            circleView.removeFromSuperview()
        }
    }
    
    func circleLayerView() -> UIView? {
		let subViews = self.subviews
		for subview in subViews {
			if subview.tag == 123456 {
				return subview
			}
		}
		return nil
    }
}

extension UIView {
    func animateLeftToRight () {
		
		
        
        let maskLayer = CALayer()
        
        let image = UIImage(named: "sliderLabelMask")
        maskLayer.contents = image?.cgImage
        
        // Center the mask image on 0.0 of the text layer, so it starts to the right
        // of the text layer and moves to its left when we translate it by width.
        //maskLayer.contentsGravity = kCAGravityCenter;
        maskLayer.frame =  CGRect(x: -self.frame.size.width, y: 0.0, width: 2 * self.frame.size.width, height: self.frame.size.height);
        
        // Animate the mask layer's horizontal position
        let maskAnim = CABasicAnimation(keyPath: "position.x");
        
        let double = Double(self.frame.size.width)
        maskAnim.byValue = NSNumber(value: double as Double);
        maskAnim.repeatCount = Float.infinity; // HUGE_VALF will cause the animation to repeat forever.
        maskAnim.duration = 1.5;
        maskLayer.add(maskAnim, forKey: "slideAnimLTR")
        
        self.layer.mask = maskLayer;
    }
    
    
    func animateBottomUp () {
        
        
        
        let maskLayer = CALayer()
        
        let image = UIImage(named: "BottomUpMask")
        maskLayer.contents = image?.cgImage
        
        // Center the mask image on 0.0 of the text layer, so it starts to the right
        // of the text layer and moves to its left when we translate it by width.
        //maskLayer.contentsGravity = kCAGravityCenter;
        maskLayer.frame =  CGRect(x: 0,y: 0, width: self.frame.size.width, height: 2 * self.frame.size.height);
        
        // Animate the mask layer's horizontal position
        let maskAnim = CABasicAnimation(keyPath: "position.y");
        
        let double = Double(-self.frame.size.height)
        maskAnim.byValue = NSNumber(value: double as Double);
        maskAnim.repeatCount = Float.infinity; // HUGE_VALF will cause the animation to repeat forever.
        maskAnim.duration = 1.5;
        maskLayer.add(maskAnim, forKey: "slideAnimBU")
        
        self.layer.mask = maskLayer;
    }
    
}
