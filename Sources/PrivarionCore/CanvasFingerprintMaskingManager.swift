import Foundation

public class CanvasFingerprintMaskingManager: @unchecked Sendable {
    
    public enum MaskingError: Error, LocalizedError {
        case invalidConfiguration
        case maskingNotEnabled
        case scriptGenerationFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "Invalid canvas fingerprint masking configuration"
            case .maskingNotEnabled:
                return "Canvas fingerprint masking is not enabled"
            case .scriptGenerationFailed:
                return "Failed to generate canvas masking script"
            }
        }
    }
    
    public enum MaskingLevel: String, CaseIterable, Codable {
        case off = "off"
        case minimal = "minimal"
        case moderate = "moderate"
        case aggressive = "aggressive"
        
        public var displayName: String {
            switch self {
            case .off: return "Off"
            case .minimal: return "Minimal"
            case .moderate: return "Moderate"
            case .aggressive: return "Aggressive"
            }
        }
        
        public var noiseFactor: Double {
            switch self {
            case .off: return 0.0
            case .minimal: return 0.01
            case .moderate: return 0.05
            case .aggressive: return 0.15
            }
        }
    }
    
    public struct MaskingOptions {
        public let level: MaskingLevel
        public let randomizeNoise: Bool
        public let blockReadback: Bool
        
        public init(level: MaskingLevel = .moderate,
                    randomizeNoise: Bool = true,
                    blockReadback: Bool = true) {
            self.level = level
            self.randomizeNoise = randomizeNoise
            self.blockReadback = blockReadback
        }
    }
    
    private let logger: PrivarionLogger
    private var currentLevel: MaskingLevel = .off
    private var noiseSeed: UInt64 = 0
    private let queue = DispatchQueue(label: "com.privarion.canvas.masking")
    
    public init(logger: PrivarionLogger = PrivarionLogger.shared) {
        self.logger = logger
    }
    
    public func enableMasking(options: MaskingOptions) throws {
        guard options.level != .off else {
            throw MaskingError.invalidConfiguration
        }
        
        logger.info("Enabling canvas fingerprint masking with level: \(options.level.rawValue)")
        
        queue.sync {
            self.currentLevel = options.level
            if options.randomizeNoise {
                self.noiseSeed = UInt64.random(in: 0...UInt64.max)
            }
        }
        
        logger.info("Canvas fingerprint masking enabled")
    }
    
    public func disableMasking() throws {
        logger.info("Disabling canvas fingerprint masking")
        
        queue.sync {
            self.currentLevel = .off
        }
        
        logger.info("Canvas fingerprint masking disabled")
    }
    
    public func getCurrentLevel() -> MaskingLevel {
        return queue.sync { currentLevel }
    }
    
    public func isEnabled() -> Bool {
        return queue.sync { currentLevel != .off }
    }
    
    public func generateMaskingScript() -> String {
        let level = queue.sync { currentLevel }
        
        guard level != .off else {
            return ""
        }
        
        return generateScriptForLevel(level)
    }
    
    private func generateScriptForLevel(_ level: MaskingLevel) -> String {
        let noiseFactor = level.noiseFactor
        
        return """
        (function() {
            'use strict';
            
            const NOISE_FACTOR = \(noiseFactor);
            
            function addNoise(value, max) {
                if (typeof value !== 'number') return value;
                const noise = (Math.random() - 0.5) * 2 * max * NOISE_FACTOR;
                return Math.round(value + noise);
            }
            
            const originalGetImageData = HTMLCanvasElement.prototype.getImageData;
            HTMLCanvasElement.prototype.getImageData = function(sx, sy, sw, sh) {
                const imageData = originalGetImageData.apply(this, arguments);
                const data = imageData.data;
                
                for (let i = 0; i < data.length; i += 4) {
                    data[i] = addNoise(data[i], 255);
                    data[i + 1] = addNoise(data[i + 1], 255);
                    data[i + 2] = addNoise(data[i + 2], 255);
                }
                
                return imageData;
            };
            
            const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
            HTMLCanvasElement.prototype.toDataURL = function() {
                const canvas = this;
                const ctx = canvas.getContext('2d');
                if (ctx) {
                    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                    const data = imageData.data;
                    
                    for (let i = 0; i < data.length; i += 4) {
                        data[i] = addNoise(data[i], 255);
                        data[i + 1] = addNoise(data[i + 1], 255);
                        data[i + 2] = addNoise(data[i + 2], 255);
                    }
                    
                    ctx.putImageData(imageData, 0, 0);
                }
                
                return originalToDataURL.apply(this, arguments);
            };
            
            const originalToBlob = HTMLCanvasElement.prototype.toBlob;
            HTMLCanvasElement.prototype.toBlob = function() {
                const canvas = this;
                const ctx = canvas.getContext('2d');
                if (ctx) {
                    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                    const data = imageData.data;
                    
                    for (let i = 0; i < data.length; i += 4) {
                        data[i] = addNoise(data[i], 255);
                        data[i + 1] = addNoise(data[i + 1], 255);
                        data[i + 2] = addNoise(data[i + 2], 255);
                    }
                    
                    ctx.putImageData(imageData, 0, 0);
                }
                
                return originalToBlob.apply(this, arguments);
            };
            
            const originalFillText = CanvasRenderingContext2D.prototype.fillText;
            CanvasRenderingContext2D.prototype.fillText = function() {
                this.fillStyle = addNoiseRandomness(this.fillStyle);
                return originalFillText.apply(this, arguments);
            };
            
            const originalStrokeText = CanvasRenderingContext2D.prototype.strokeText;
            CanvasRenderingContext2D.prototype.strokeText = function() {
                this.strokeStyle = addNoiseRandomness(this.strokeStyle);
                return originalStrokeText.apply(this, arguments);
            };
            
            function addNoiseRandomness(style) {
                if (typeof style !== 'string') return style;
                
                const randomOffset = Math.floor(Math.random() * 2);
                if (randomOffset === 0) {
                    return style;
                }
                
                return style;
            }
            
            const originalGetContext = HTMLCanvasElement.prototype.getContext;
            HTMLCanvasElement.prototype.getContext = function() {
                const context = originalGetContext.apply(this, arguments);
                
                if (context && arguments[0] === '2d') {
                    context.fillText = CanvasRenderingContext2D.prototype.fillText;
                    context.strokeText = CanvasRenderingContext2D.prototype.strokeText;
                }
                
                return context;
            };
            
            console.log('[Privarion] Canvas fingerprint masking enabled - level: \(level.rawValue)');
        })();
        """
    }
}
