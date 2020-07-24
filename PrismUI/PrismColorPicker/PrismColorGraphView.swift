//
//  PrismColorGraphView.swift
//  PrismUI
//
//  Created by Erik Bautista on 7/21/20.
//  Copyright © 2020 ErrorErrorError. All rights reserved.
//

import Cocoa

class PrismColorGraphView: NSView {

    private let strokeWidth: CGFloat = 3
    private var selectorRect: NSRect!
    private var saturationValueImage: CGImage?
    private var clickedBounds = false
    weak var delegate: PrismColorGraphDelegate?

    var color: PrismHSB = PrismHSB(hue: 1.0, saturation: 1.0, brightness: 1.0) {
        willSet(newVal) {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        selectorRect = NSRect(x: 0, y: 0, width: 26, height: 26)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let path = CGPath(roundedRect: bounds,
                          cornerWidth: selectorRect.width/2,
                          cornerHeight: selectorRect.width/2,
                          transform: nil)
        context.addPath(path)
        context.clip()
        drawBackgroundColor(context)
        drawSaturationBrightnessOverlay(context)
        drawSelector(context)
    }

    private func drawBackgroundColor(_ context: CGContext) {
        guard let hueColor = color.copy() as? PrismHSB else { return }
        hueColor.saturation = 1
        hueColor.brightness = 1
        hueColor.nsColor.setFill()
        context.fill(bounds)
    }

    private func drawSaturationBrightnessOverlay(_ contextDraw: CGContext) {
        guard saturationValueImage == nil else {
            contextDraw.draw(saturationValueImage!, in: bounds)
            return
        }
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext.init(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)
        guard let buffer = context?.data?.bindMemory(to: UInt32.self, capacity: width * height) else { return }
        let white = PrismRGB(red: 1.0, green: 1.0, blue: 1.0)
        let black = PrismRGB(red: 0.0, green: 0.0, blue: 0.0)
        let transparent = PrismRGB(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        for row in 0..<height {
            for column in 0..<width {
                let index = row * width + column
                let widthPercentage = CGFloat(column) / CGFloat(width)
                let heightPercentage = 1 - CGFloat(row) / CGFloat(height)
                let horizontalColor = linearGradient(fromColor: white,
                                                     toColor: transparent,
                                                     percent: widthPercentage)
                let verticalColor = linearGradient(fromColor: black,
                                                   toColor: transparent,
                                                   percent: heightPercentage)
                let blendColor = blend(src: verticalColor, dest: horizontalColor)
                buffer[index] =
                    UInt32(blendColor.red * 0xff) << 24 |
                    UInt32(blendColor.green * 0xff) << 16 |
                    UInt32(blendColor.blue * 0xff) << 8 |
                    UInt32(blendColor.alpha * 0xff)
            }
        }

        let image = context?.makeImage()
        saturationValueImage = image
        contextDraw.draw(saturationValueImage!, in: bounds)
    }

    private func linearGradient(fromColor: PrismRGB, toColor: PrismRGB, percent: CGFloat) -> PrismRGB {
        let red = lerp(fromValue: fromColor.red, toValue: toColor.red, percent: percent)
        let green = lerp(fromValue: fromColor.green, toValue: toColor.green, percent: percent)
        let blue = lerp(fromValue: fromColor.blue, toValue: toColor.blue, percent: percent)
        let alpha = lerp(fromValue: fromColor.alpha, toValue: toColor.alpha, percent: percent)
        return PrismRGB(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func blend(src: PrismRGB, dest: PrismRGB) -> PrismRGB {
        let red = blend(from: src.red, to: dest.red, alpha: src.alpha)
        let green = blend(from: src.green, to: dest.green, alpha: src.alpha)
        let blue = blend(from: src.blue, to: dest.blue, alpha: src.alpha)
        let alpha = 1 - (1 - src.alpha) * (1 - dest.alpha)
        return PrismRGB(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func lerp(fromValue: CGFloat, toValue: CGFloat, percent: CGFloat) -> CGFloat {
        return (toValue - fromValue) * percent + fromValue
    }

    func blend(from src: CGFloat, to dest: CGFloat, alpha: CGFloat) -> CGFloat {
        return (1 - alpha) * dest + alpha * src
    }

    private func drawSelector(_ context: CGContext) {
        let width: CGFloat = bounds.size.width - selectorRect.width
        let height: CGFloat = bounds.size.height - selectorRect.height

        let xAxis = color.saturation * width
        let yAxis = color.brightness * height
        selectorRect.origin = NSPoint(x: xAxis, y: yAxis)

        color.nsColor.setFill()
        context.fillEllipse(in: selectorRect)

        NSColor.white.setStroke()
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: selectorRect.insetBy(dx: strokeWidth/2, dy: strokeWidth/2))
        context.resetClip()
    }

    private func updateColorFromPoint(point: NSPoint, mouseUp: Bool = false) {
        guard let newColor = color.copy() as? PrismHSB else { return }

        let xAxis: CGFloat = min(max(point.x, 0), bounds.size.width)
        let yAxis: CGFloat = min(max(point.y, 0), bounds.size.height)

        let saturation = xAxis / self.bounds.size.width
        let brightness = yAxis / self.bounds.size.height
        newColor.saturation = saturation
        newColor.brightness = brightness
        color = newColor
        delegate?.didColorChange(color: color, mouseUp: mouseUp)
    }
}

// MARK: Mouse events
extension PrismColorGraphView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        guard let localPoint = window?.contentView?.convert(event.locationInWindow, to: self) else {
            print("Could not convert window point to local point")
            return
        }
        if self.bounds.contains(localPoint) {
            clickedBounds = true
            updateColorFromPoint(point: localPoint)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard let localPoint = window?.contentView?.convert(event.locationInWindow, to: self) else {
            print("Could not convert window point to local point")
            return
        }
        if clickedBounds {
            updateColorFromPoint(point: localPoint)
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard let localPoint = window?.contentView?.convert(event.locationInWindow, to: self) else {
            print("Could not convert window point to local point")
            return
        }
        if clickedBounds {
            updateColorFromPoint(point: localPoint, mouseUp: true)
            clickedBounds = false
        }
    }
}

protocol PrismColorGraphDelegate: AnyObject {
    func didColorChange(color: PrismHSB, mouseUp: Bool)
}