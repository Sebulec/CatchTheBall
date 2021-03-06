//
//  CGPoint+Extensions.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 23/01/2021.
//  Copyright © 2021 Sebastian Kotarski. All rights reserved.
//

import CoreGraphics

extension CGPoint {
    var nillIfNan: Self? {
        if x.isNaN || y.isNaN {
            return nil
        } else {
            return self
        }
    }
}
