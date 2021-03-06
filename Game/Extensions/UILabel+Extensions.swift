//
//  UILabel+Extensions.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 21/01/2021.
//  Copyright © 2021 Sebastian Kotarski. All rights reserved.
//

import UIKit

extension UILabel {
    var strokeTextAttributes: [NSAttributedString.Key : Any] {[
        .strokeColor : UIColor.black,
        .foregroundColor : UIColor.white,
        .strokeWidth : -2.0,
    ]}
}
