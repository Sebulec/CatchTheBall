//
//  Double+Extensions.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 09/11/2020.
//  Copyright © 2020 Sebastian Kotarski. All rights reserved.
//

import SceneKit

extension Double {
    var vector3D: SCNVector3 {
        .init(self, self, self)
    }
}
