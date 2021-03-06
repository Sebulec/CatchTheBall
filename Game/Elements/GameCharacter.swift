//
//  GameCharacter.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 02/11/2020.
//  Copyright © 2020 Sebastian Kotarski. All rights reserved.
//

import SceneKit
import ARKit
import RealityKit

protocol GameCharacterDelegate: class {
    func bothHandsPositionChange(areLifted: Bool)
}

class GameCharacter: SCNNode {
    var onBothHandsUp: Action<Bool>?
    var savedBodyPosition: simd_float3?

    weak var delegate: GameCharacterDelegate?

    private var firstRun = true
    private var nodes: [SCNNode] = []
    private var heightForRealPerson: CGFloat = 0
    private var widthForRealPerson: CGFloat = 0
    private var characterOffset: Float?

    private let characterOffsetMaxDistance: Float = 1

    private lazy var initialPosition: SCNVector3 = { position }()

    override init() {
        super.init()
        name = "Game character"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBodyOffsetFromOriginPosition(
        offsetInMeters: Float
    ) {
        if offsetInMeters > -1 && offsetInMeters < 1 {
            characterOffset = abs(boundingBox.min.x) * offsetInMeters
        } else if offsetInMeters > 1 {
            characterOffset = boundingBox.min.x
        } else {
            characterOffset = -boundingBox.min.x
        }
    }

    func setupJointLandmarks(
        skeleton: ARSkeleton2D,
        transform: CGAffineTransform,
        sceneView: ARSCNView
    ) {
        if firstRun {
            skeleton.jointLandmarks.forEach { (jointLandmark) in
                let node = SCNNode(geometry: SCNSphere(radius: 2))
                node.name = "node"
                node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
                node.physicsBody?.mass = 0
                node.physicsBody?.restitution = 0.9
                node.physicsBody?.friction = 0.9
                node.physicsBody?.angularDamping = 0.19
                node.physicsBody?.contactTestBitMask = PhysicsCategory.player

                node.castsShadow = false
                addChildNode(node)
                nodes.append(node)
            }
            firstRun = false
        }
        updateBodyElements(
            jointLandmarks: skeleton.jointLandmarks,
            transform: transform,
            sceneView: sceneView,
            skeleton: skeleton
        )
    }

    func updateBodyElements(
        jointLandmarks: [simd_float2],
        transform: CGAffineTransform,
        sceneView: ARSCNView,
        skeleton: ARSkeleton2D
    ) {
        let scaleByWidth = abs(CGFloat(geometry?.boundingBox.max.x ?? 0.0)) + abs(CGFloat(geometry?.boundingBox.min.x ?? 0.0))
        let scaleByHeight = abs(CGFloat(geometry?.boundingBox.max.y ?? 0.0)) + abs(CGFloat(geometry?.boundingBox.min.y ?? 0.0)) - 20

        let scaleSize = CGSize(width: scaleByWidth, height: scaleByHeight)

        setupHeightForRealPerson(
            size: scaleSize,
            jointLandmarks: jointLandmarks
        )

//        delegate?.bothHandsPositionChange(areLifted: true)
        delegate?.bothHandsPositionChange(areLifted: verifyBothHandsPositionAreHighest(skeleton: skeleton, jointLandmarks: jointLandmarks))

        jointLandmarks.enumerated().forEach { (index, element) in
            updateNodePosition(element, for: nodes[index], scaleSize, skeleton: skeleton, index: index)
        }
    }

    private func verifyBothHandsPositionAreHighest(
        skeleton: ARSkeleton2D,
        jointLandmarks: [simd_float2]
    ) -> Bool {
        let sortedListOfTwoElements = jointLandmarks.sortedDecreasing(direction: .vertical).suffix(2)

        guard let leftHandPosition = skeleton.landmark(for: .leftHand) else { return false }
        guard let rightHandPosition = skeleton.landmark(for: .rightHand) else { return false }

        return sortedListOfTwoElements.contains(leftHandPosition)
        && sortedListOfTwoElements.contains(rightHandPosition)
    }

    private func updateNodePosition(
        _ nodePosition: simd_float2?,
        for node: SCNNode,
        _ size: CGSize,
        skeleton: ARSkeleton2D,
        index: Int? = nil
    ) {
        guard let nodePosition = nodePosition, !nodePosition.x.isNaN, !nodePosition.y.isNaN else {
            node.isHidden = true
            return
        }

        node.isHidden = false
        node.name = "marked_node"
        node.physicsBody?.collisionBitMask = PhysicsCategory.player
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player

        let leftHand = skeleton.landmark(for: ARSkeleton.JointName.leftHand)
        let rightHand = skeleton.landmark(for: ARSkeleton.JointName.rightHand)
        let leftLeg = skeleton.landmark(for: ARSkeleton.JointName.leftFoot)
        let rightLeg = skeleton.landmark(for: ARSkeleton.JointName.rightFoot)
        let head = skeleton.landmark(for: .head)

        let markedLandmarks = [leftHand, rightHand, leftLeg, rightLeg, head]
        if markedLandmarks.contains(nodePosition) {
            node.geometry = SCNSphere(radius: 5)
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        } else {
            node.geometry = SCNSphere(radius: 2)
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        }

        guard let lowestPoint = skeleton.jointLandmarks.lowestPoint(), !lowestPoint.isNan() else { return }
        guard let innerPoint = skeleton.jointLandmarks.innerPoint(), !innerPoint.isNan() else { return }
        guard let outerPoint = skeleton.jointLandmarks.outerPoint(), !outerPoint.isNan() else { return }
        guard let highestPoint = skeleton.jointLandmarks.highestPoint(), !highestPoint.isNan() else { return }

        let normalizedCenter = CGPoint(
            x: (CGFloat(nodePosition[0]) - CGFloat(innerPoint.x)) / (CGFloat(outerPoint.x) - CGFloat(innerPoint.x)),
            y: (CGFloat(nodePosition[1]) - CGFloat(lowestPoint.y)) / (CGFloat(highestPoint.y) - CGFloat(lowestPoint.y))
        )

        let center = normalizedCenter.applying(CGAffineTransform.identity.scaledBy(x: size.width, y: size.height))

        let position = SCNVector3.init(-Float(center.x + CGFloat(boundingBox.min.x)) / 2, -Float(center.y + CGFloat(boundingBox.min.y)), 0)

        var newPosition = position
        newPosition.x = newPosition.x + (characterOffset ?? 0)

        node.position = newPosition
    }

    private func setupHeightForRealPerson(
        size: CGSize,
        jointLandmarks: [simd_float2]
    ) {
        guard let highestPoint = jointLandmarks.highestPoint(),
              let lowestPoint = jointLandmarks.lowestPoint(),
              let outerPoint = jointLandmarks.outerPoint(),
              let innerPoint = jointLandmarks.innerPoint() else { return }

        let diffBetweenWidthPoints: CGFloat = (CGFloat(abs(outerPoint.x)) - CGFloat(abs(innerPoint.x)))

        heightForRealPerson = size.height / (CGFloat(abs(highestPoint.y - lowestPoint.y)) * UIScreen.main.bounds.size.height)
        widthForRealPerson = size.width / (diffBetweenWidthPoints * UIScreen.main.bounds.size.width)
    }
}

extension Array where Element == simd_float2 {
    enum Direction {
        case vertical, horizontal
    }

    func sortedDecreasing(direction: Direction) -> Self {
        switch direction {
        case .horizontal:
            return self.sorted(by: orderByX).reversed()
        case .vertical:
            return self.sorted(by: orderByY).reversed()
        }
    }

    func highestPoint() -> Element? {
        self.max(by: orderByY)
    }

    func lowestPoint() -> Element? {
        self.min(by: orderByY)
    }

    func outerPoint() -> Element? {
        self.max(by: orderByX)
    }

    func innerPoint() -> Element? {
        self.min(by: orderByX)
    }

    private func orderByY(oneElement: Element, secondElement: Element) -> Bool {
        oneElement.y < secondElement.y
    }

    private func orderByX(oneElement: Element, secondElement: Element) -> Bool {
        oneElement.x < secondElement.x
    }
}

