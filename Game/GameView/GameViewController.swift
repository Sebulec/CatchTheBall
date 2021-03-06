//
//  GameViewController.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 18/10/2020.
//  Copyright © 2020 Sebastian Kotarski. All rights reserved.
//

import UIKit
import RealityKit
import ARKit
import Combine

class GameViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var arView: ARView!
    @IBOutlet var sceneView: ARSCNView!

    // MARK: - Properties
    private let scene = SCNView()
    private let gameCharacter = GameCharacter()
    private var sceneLoaded: SCNScene?
    private let gameplayLogic = GameplayLogic()

    var character: BodyTrackedEntity?
    let characterAnchor = AnchorEntity()

    private var isPreparingBall = false
    private let ballRespawnTime = 3.0
    private let ballNodeName = "ball"
    private let netDefaultName = "Net_default"
    private let gateNodeName = "gate"
    private let wallsNodeName = "walls"
    private let playerFieldNodeName = "player_field"
    private let markedNodeName = "marked_node"

    private let mainSceneName = "scenes.scnassets/main.scn"

    private let stopButtonTitle = "STOP"

    // MARK: - UI

    private lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 30)
        label.numberOfLines = 2
        label.textAlignment = .right
        label.isHidden = false
        return label
    }()

    private lazy var progressButton: ProgressButton = {
        let button = ProgressButton(progressColor: UIColor.red.withAlphaComponent(0.5), frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitle("how_to_start_game_description".localized, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 22)
        button.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)
        return button
    }()

    // MARK: - Initialization

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScenes()
        setupDelegates()
        setupWorld()
        setupGameCharacter()
        setupBall()
        setupViews()
        setupActions()
    }

    private func setupScenes() {
        sceneView.backgroundColor = .yellow
        view.backgroundColor = .clear

        scene.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(scene)

        sceneLoaded = SCNScene(named: mainSceneName)

        // Allow user translate image
        sceneView.cameraControlConfiguration.allowsTranslation = true

        // Set scene settings
        scene.scene = sceneLoaded

        sceneView.contentMode = .scaleToFill

        // Run a body tracking configration.
        let configuration = ARBodyTrackingConfiguration()
        configuration.automaticSkeletonScaleEstimationEnabled = false

        sceneView.session.run(configuration)

        arView.session.run(configuration)
        arView.session.delegate = self
        arView.scene.addAnchor(characterAnchor)

        sceneLoaded?.rootNode.addChildNode(gameCharacter)
    }

    private func setupDelegates() {
        gameplayLogic.delegate = self
        gameCharacter.delegate = gameplayLogic
        sceneView.session.delegate = self
    }

    func setupViews() {
        addSubviews()
        addConstraints()
    }

    private func addSubviews() {
        view.addSubview(scoreLabel)
        view.bringSubviewToFront(scoreLabel)
        view.addSubview(progressButton)
    }

    private func addConstraints() {
        NSLayoutConstraint.activate([
            scene.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor),
            scene.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor),
            scene.topAnchor.constraint(equalTo: sceneView.topAnchor),
            scene.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor),

            progressButton.heightAnchor.constraint(equalToConstant: 55),
            progressButton.topAnchor.constraint(equalTo: view.topAnchor),
            progressButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            progressButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

            scoreLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            scoreLabel.topAnchor.constraint(equalTo: progressButton.bottomAnchor, constant: 8),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ])
    }

    private func setupActions() {
        gameCharacter.onBothHandsUp = { [self] bothHandsUp in
            progressButton.backgroundColor = bothHandsUp ? UIColor.red : UIColor.lightGray
        }
    }
    
    func setupWorld() {
        sceneLoaded?.physicsWorld.contactDelegate = self
        sceneLoaded?.physicsWorld.gravity = SCNVector3(0, 0, 9.8)

        let gate = sceneLoaded?.rootNode.childNode(
            withName: gateNodeName,
            recursively: false
        )
        let myFloor = generateWall(for: SCNVector3(x: 0, y: 0, z: 0))
        myFloor.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
        sceneLoaded?.rootNode.addChildNode(myFloor)

        setupSurface(
            for: SCNVector3(0, 0, 0),
            height: CGFloat(Int(gate?.boundingBox.max.y ?? 0)),
            color: UIColor.clear
        )

        setupSurface(
            for: SCNVector3(35 + (gate?.boundingBox.max.x ?? 0), (gate?.position.y ?? 0), 0),
            height: CGFloat(Int(gate?.boundingBox.max.y ?? 0)),
            color: UIColor.clear
        )

        setupSurface(
            for: SCNVector3(-10, (gate?.boundingBox.max.y ?? 0), 0),
            height: CGFloat(Int(gate?.boundingBox.max.y ?? 0)),
            color: UIColor.clear,
            rotation: SCNVector3(Double.pi / 2, 0, 0)
        )
    }

    private func generateWall(for position: SCNVector3) -> SCNNode {
        let myFloor = SCNFloor()
        let myFloorNode = SCNNode(geometry: myFloor)
        myFloorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        myFloorNode.position = position
        return myFloorNode
    }

    private func setupSurface(
        for position: SCNVector3,
        height: CGFloat,
        color: UIColor,
        rotation: SCNVector3 = SCNVector3(0, -Double.pi / 2, 0)
    ) {
        let wall = SCNPlane(
            width: 10000,
            height: 10000
        )

        let outerSurfaceNode = SCNNode(geometry: wall)
        outerSurfaceNode.name = wallsNodeName
        outerSurfaceNode.geometry?.firstMaterial?.diffuse.contents = color
        outerSurfaceNode.geometry?.name = wallsNodeName
        outerSurfaceNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        outerSurfaceNode.eulerAngles = rotation

        sceneLoaded?.rootNode.addChildNode(outerSurfaceNode)
        outerSurfaceNode.position = position
    }

    func setupGameCharacter() {
        let gate = sceneLoaded?.rootNode.childNode(
            withName: gateNodeName,
            recursively: false
        )
        gate?.physicsBody?.collisionBitMask = PhysicsCategory.player

        if let gateSizeMax = gate?.boundingBox.max,
           let gateSizeMin = gate?.boundingBox.min {

            let width = abs(gateSizeMax.x) + abs(gateSizeMin.x)
            let height = abs(gateSizeMax.y) + abs(gateSizeMin.y)

            let box = SCNBox(
                width: CGFloat(width),
                height: CGFloat(height),
                length: 20,
                chamferRadius: 0
            )
            gameCharacter.geometry = box

            gameCharacter.position = SCNVector3(x: width / 2, y: gateSizeMax.y / 2 - 10, z: -160)
            gameCharacter.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        }
    }

    func setupBall() {
        guard let ball = sceneLoaded?.rootNode.childNode(
            withName: ballNodeName,
            recursively: false
        ) else { return }

        ball.geometry = SCNSphere(radius: 30)
        ball.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        ball.physicsBody?.restitution = 0.9
        ball.physicsBody?.angularDamping = 0.9
        ball.physicsBody?.isAffectedByGravity = true
        ball.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        ball.physicsBody!.contactTestBitMask = PhysicsCategory.ball
    }

    private func throwBall() {
        guard let ball = obtainBall() else { return }

        ball.position.z = -500
        ball.opacity = 1
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        let randomY = Int.random(in: 0...150)
        let randomX = Int.random(in: -50...50)
        ball.physicsBody?.applyForce(SCNVector3(randomX, randomY, -50), at: ball.position, asImpulse: true)
        ball.physicsBody?.velocity = SCNVector3(randomX, randomY, 50)
    }

    private func obtainBall() -> SCNNode? {
        sceneLoaded?.rootNode.childNode(
            withName: ballNodeName,
            recursively: false
        )
    }

    @objc
    private func didTapStop() {
        gameplayLogic.stopGame()
    }
}

// MARK: - ARSessionDelegate

extension GameViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

            // Update the position of the character anchor's position.
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)

            if gameplayLogic.shouldSaveBodyPosition {
                gameplayLogic.shouldSaveBodyPosition = false
                gameCharacter.savedBodyPosition = bodyPosition
            }

            if let savedBodyPosition = gameCharacter.savedBodyPosition {
                let dist = savedBodyPosition.x - bodyPosition.x
                gameCharacter.updateBodyOffsetFromOriginPosition(offsetInMeters: dist)
            }

            // Also copy over the rotation of the body anchor, because the skeleton's pose
            // in the world is relative to the body anchor's rotation.
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation

            if let character = character, character.parent == nil {
                // Attach the character to its anchor as soon as
                // 1. the body anchor was detected and
                // 2. the character was loaded.
                characterAnchor.addChild(character)
            }
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if let detectedBody = frame.detectedBody {
            guard let interfaceOrientation = sceneView.window?.windowScene?.interfaceOrientation else { return }
            let transform = frame.displayTransform(for: interfaceOrientation, viewportSize: sceneView.frame.size)
            gameCharacter.setupJointLandmarks(
                skeleton: detectedBody.skeleton,
                transform: transform,
                sceneView: sceneView
            )
        }
    }
}

// MARK: - SCNPhysicsContactDelegate

extension GameViewController: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        guard let nodeAName = contact.nodeA.name,
              let nodeBName = contact.nodeB.name else { return }

        guard contact.nodeA.geometry?.firstMaterial?.diffuse.contents as? NSObject == UIColor.red
                || contact.nodeB.geometry?.firstMaterial?.diffuse.contents as? NSObject == UIColor.red,
              !isPreparingBall
        else { return }

        if nodeAName == ballNodeName && nodeBName == netDefaultName {
            contact.nodeA.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            gameplayLogic.didMissBall()
            prepareNextBall(contact.nodeA)
        } else if nodeBName == ballNodeName && nodeAName == netDefaultName {
            contact.nodeB.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            gameplayLogic.didMissBall()
            prepareNextBall(contact.nodeB)
        } else if nodeAName == ballNodeName && nodeBName == markedNodeName {
            contact.nodeA.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            gameplayLogic.didCatchBall()
            prepareNextBall(contact.nodeA)
        } else if nodeBName == ballNodeName && nodeAName == markedNodeName {
            contact.nodeB.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            gameplayLogic.didCatchBall()
            prepareNextBall(contact.nodeB)
        }
    }

    private func prepareNextBall(_ previousBall: SCNNode? = nil) {
        guard !isPreparingBall && gameplayLogic.shouldPrepareBall() else { return }
        isPreparingBall = true
        DispatchQueue.main.asyncAfter(deadline: .now() + ballRespawnTime) { [self] in
            guard gameplayLogic.shouldPrepareBall() else { return }
            throwBall()
            isPreparingBall = false
        }
    }
}

// MARK: - GameplayLogicDelegate

extension GameViewController: GameplayLogicDelegate {

    func setupGameState(_ state: GameState) {
        switch state {
        case .idle: restartGame()
        case .running: startGameSession()
        }
    }

    private func restartGame() {
        progressButton.setTitle("how_to_start_game_description".localized, for: .normal)
        progressButton.backgroundColor = .clear
        scoreLabel.text = ""
        gameplayLogic.shouldSaveBodyPosition = true
    }

    private func startGameSession() {
        progressButton.setTitle(stopButtonTitle, for: .normal)
        progressButton.backgroundColor = .red
        prepareNextBall()
    }

    func setupProgressButton(selected: Bool, progress: Float) {
        DispatchQueue.main.async { [self] in
            if selected {
                progressButton.progress = CGFloat(progress)
            } else {
                progressButton.progress = 0.0
            }
        }
    }

    func showScoreInfo(value: String) {
        DispatchQueue.main.async { [self] in
            scoreLabel.attributedText = NSAttributedString(string: value, attributes: scoreLabel.strokeTextAttributes)
        }
    }

    func showFinalResults(resultText: String) {
        let alertController = UIAlertController(title: nil, message: resultText, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default))
        present(alertController, animated: true)
    }
}
