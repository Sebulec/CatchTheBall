//
//  simd_float2+Extensions.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 23/01/2021.
//  Copyright © 2021 Sebastian Kotarski. All rights reserved.
//

import ARKit

extension simd_float2 {
    var point: CGPoint {
        CGPoint(x: CGFloat(self[0]), y: CGFloat(self[1]))
    }
    
    func isNan() -> Bool {
        x.isNaN && y.isNaN
    }
}
