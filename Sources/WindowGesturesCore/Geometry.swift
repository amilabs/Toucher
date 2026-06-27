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
    case maximize
    case verticalMaxCenterThird
    case restore
}

public enum WindowFrameCalculator {
    public static func frame(for action: WindowAction, in visibleScreenFrame: Rect) -> Rect {
        switch action {
        case .leftHalf:
            let halfWidth = visibleScreenFrame.width / 2
            return Rect(
                x: visibleScreenFrame.x,
                y: visibleScreenFrame.y,
                width: halfWidth,
                height: visibleScreenFrame.height
            )
        case .rightHalf:
            let halfWidth = visibleScreenFrame.width / 2
            return Rect(
                x: visibleScreenFrame.x + halfWidth,
                y: visibleScreenFrame.y,
                width: halfWidth,
                height: visibleScreenFrame.height
            )
        case .maximize:
            return visibleScreenFrame
        case .verticalMaxCenterThird:
            let newWidth = visibleScreenFrame.width / 3
            return Rect(
                x: visibleScreenFrame.x + (visibleScreenFrame.width - newWidth) / 2,
                y: visibleScreenFrame.y,
                width: newWidth,
                height: visibleScreenFrame.height
            )
        case .restore:
            return visibleScreenFrame
        }
    }
}
