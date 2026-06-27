import Foundation

public struct Rect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum WindowAction: Equatable, Sendable {
    case leftHalf
    case rightHalf
}

public enum WindowFrameCalculator {
    public static func frame(for action: WindowAction, in visibleScreenFrame: Rect) -> Rect {
        let halfWidth = visibleScreenFrame.width / 2

        switch action {
        case .leftHalf:
            return Rect(
                x: visibleScreenFrame.x,
                y: visibleScreenFrame.y,
                width: halfWidth,
                height: visibleScreenFrame.height
            )
        case .rightHalf:
            return Rect(
                x: visibleScreenFrame.x + halfWidth,
                y: visibleScreenFrame.y,
                width: halfWidth,
                height: visibleScreenFrame.height
            )
        }
    }
}
