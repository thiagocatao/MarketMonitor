import Foundation

enum MarketCheckerError: Error, LocalizedError {
    case pythonNotFound
    case scriptNotFound
    case timeout
    case parseError(String)
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound: return "Python not found at configured path"
        case .scriptNotFound: return "market_monitor.py script not found"
        case .timeout: return "Market check timed out after 60s"
        case .parseError(let raw): return "Failed to parse output: \(raw.prefix(200))"
        case .processError(let err): return "Python error: \(err.prefix(200))"
        }
    }
}

enum MarketChecker {
    static func check(
        pythonPath: String,
        scriptPath: String,
        configPath: String,
        mode: String = "full"
    ) async throws -> CheckResult {
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw MarketCheckerError.pythonNotFound
        }
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw MarketCheckerError.scriptNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                process.arguments = [scriptPath, "--config", configPath, "--mode", mode]

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + 60)
                timer.setEventHandler {
                    if process.isRunning { process.terminate() }
                }
                timer.resume()

                do {
                    try process.run()
                    process.waitUntilExit()
                    timer.cancel()

                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let errString = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: MarketCheckerError.processError(errString))
                        return
                    }

                    do {
                        let decoder = JSONDecoder()
                        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                            positiveInfinity: "Infinity",
                            negativeInfinity: "-Infinity",
                            nan: "NaN"
                        )
                        let result = try decoder.decode(CheckResult.self, from: outData)
                        continuation.resume(returning: result)
                    } catch {
                        let raw = String(data: outData, encoding: .utf8) ?? "empty"
                        continuation.resume(throwing: MarketCheckerError.parseError(raw))
                    }
                } catch {
                    timer.cancel()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
