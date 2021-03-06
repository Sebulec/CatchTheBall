//
//  GameplayLogic.swift
//  CatchTheBall
//
//  Created by Sebastian Kotarski on 19/01/2021.
//  Copyright © 2021 Sebastian Kotarski. All rights reserved.
//

import Foundation

protocol GameplayLogicDelegate: class {
    func showScoreInfo(value: String)
    func setupProgressButton(selected: Bool, progress: Float)
    func setupGameState(_ state: GameState)
    func showFinalResults(resultText: String)
}

class GameplayLogic {

    // MARK: Outlets

    var gameState: GameState = .idle {
        didSet {
            delegate?.setupGameState(gameState)
        }
    }
    var shouldSaveBodyPosition = false

    // MARK: - Delegates

    weak var delegate: GameplayLogicDelegate?

    // MARK: - Properties
    
    private let timeToStartGame = 2

    private var score: Int = 0
    private var missed: Int = 0
    private var formattedScore: String { String(format: "Catched balls: %@\nMissed: %@", score.description, missed.description) }
    private var timer: Timer?
    private var gameCountdownCount = 2
    private var areBothHandsRaised = false {
        didSet {
            processHandsChangePosition()
        }
    }

    func didCatchBall() {
        guard case gameState = GameState.running else { return }
        score += 1
        delegate?.showScoreInfo(value: formattedScore)
    }

    func didMissBall() {
        guard case gameState = GameState.running else { return }
        missed += 1
        delegate?.showScoreInfo(value: formattedScore)
    }

    func performGameStartCountdown() {
        guard gameCountdownCount == timeToStartGame, timer == nil else { return }
        timer = buildTimer()
    }

    func stopGame() {
        shouldSaveBodyPosition = false
        gameState = .idle
        delegate?.showFinalResults(resultText: obtainGameEndText())
        score = 0
        missed = 0
        delegate?.setupGameState(.idle)
        delegate?.setupProgressButton(selected: false, progress: 0)
    }

    func shouldPrepareBall() -> Bool {
        gameState == GameState.running
    }

    private func stopGameStartCountdown() {
        timer?.invalidate()
        timer = nil
        gameCountdownCount = timeToStartGame
        delegate?.setupProgressButton(selected: false, progress: 0)
    }

    private func startGameSession() {
        shouldSaveBodyPosition = true
        gameState = .running
    }

    private func processHandsChangePosition() {
        guard case gameState = GameState.idle else { return }
        if areBothHandsRaised && !isCountingDown() {
            performGameStartCountdown()
        } else if !areBothHandsRaised {
            stopGameStartCountdown()
        }
    }

    private func isCountingDown() -> Bool {
        gameCountdownCount != timeToStartGame
    }

    private func buildTimer() -> Timer {
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }

    // MARK: - Actions
    @objc func updateTimer() {
        if(gameCountdownCount >= 0) {
            delegate?.setupProgressButton(
                selected: true,
                progress: Float((Float(timeToStartGame) - Float(gameCountdownCount)) / Float(timeToStartGame))
            )
            gameCountdownCount -= 1
        } else if areBothHandsRaised && gameCountdownCount == -1 {
            DispatchQueue.main.async { [self] in
                startGameSession()
            }
        }
    }

    private func obtainGameEndText() -> String {
        let ratio = calculateRatio()
        if ratio < 0.5 {
            return "Well, could be better\n Ratio: \(ratio)"
        } else if ratio >= 0.5 && ratio < 0.95 {
            return "Well done!\n Ratio: \(ratio)"
        } else {
            return "Great game!\n Ratio: \(ratio)"
        }
    }

    private func calculateRatio() -> Double {
        Double(score) / Double(missed)
    }
}

extension GameplayLogic: GameCharacterDelegate {
    func bothHandsPositionChange(areLifted: Bool) {
        areBothHandsRaised = areLifted
    }
}
