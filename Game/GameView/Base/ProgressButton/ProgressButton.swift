//
//  ProgressButton.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 21/01/2021.
//  Copyright © 2021 Sebastian Kotarski. All rights reserved.
//

import UIKit

class ProgressButton: UIButton {
    var progress: CGFloat = 0.5 {
        didSet {
            didUpdateProgress()
        }
    }
    private let progressColor: UIColor
    private weak var shapelayer : CAShapeLayer?

    init(progressColor: UIColor, frame: CGRect) {
        self.progressColor = progressColor
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setupShapeLayer()
    }

    private func setupShapeLayer() {
        guard shapelayer == nil else { return }

        let layer = CAShapeLayer()
        layer.frame = bounds
        layer.fillColor = UIColor.clear.cgColor
        let bezierPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 0, height: bounds.height))
        layer.path = bezierPath.cgPath
        layer.fillColor = progressColor.cgColor

        self.layer.insertSublayer(layer, at: 0)
        shapelayer = layer
    }

    private func didUpdateProgress() {
        let bezierPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: bounds.width * progress, height: bounds.height))

        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = shapelayer?.path
        animation.toValue = bezierPath.cgPath
        shapelayer?.add(animation, forKey: "progress")
        shapelayer?.path = bezierPath.cgPath
    }
    
}
