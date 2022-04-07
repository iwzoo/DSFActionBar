//
//  DSFActionBarButton.swift
//  DSFActionBar
//
//  Created by Darren Ford on 7/1/21.
//
//  MIT license
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
//  documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#if os(macOS)

import AppKit

@IBDesignable
public class DSFActionBarButton: NSButton {
	// MARK: - Init and setup

	var parent: DSFActionBarProtocol!

    public var actionBlock: (() -> Void)? {
		didSet {
			self.action = nil
			self.target = nil
			self.menu = nil
		}
	}

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		self.setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		self.setup()
	}

	@objc private func setup() {
		self.translatesAutoresizingMaskIntoConstraints = false
		self.wantsLayer = true
	}

	private lazy var buttonLayer: CALayer = {
		self.layer!
	}()

	// MARK: - Cleanup

	deinit {
		if let t = self.trackingArea {
			self.removeTrackingArea(t)
		}
		self.trackingArea = nil
		self.menu = nil
		self.target = nil
	}

	// MARK: - Sizing

	public override var intrinsicContentSize: NSSize {
		var sz = super.intrinsicContentSize
		if #available(macOS 11, *) {
			sz.width -= 4
		}
		return sz
	}

	public override var controlSize: NSControl.ControlSize {
		get {
			super.controlSize
		}
		set {
			super.controlSize = newValue
			self.updateFont()
		}
	}

	private func updateFont() {
		let fs = NSFont.systemFontSize(for: self.controlSize)
		self.font = NSFont.systemFont(ofSize: fs)
		self.needsDisplay = true
	}

    public override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()

		self.updateMenuStatus()
	}

	func updateMenuStatus() {
		if let _ = self.menu {
			self.image = Self.menuImage
			self.imageScaling = .scaleNone
			self.imagePosition = .imageRight
		}
		else {
// 			self.image = nil
// 			self.imageScaling = .scaleNone
// 			self.imagePosition = .imageRight
		}
	}

	override open func drawFocusRingMask() {
		let r = NSBezierPath(roundedRect: self.bounds, xRadius: 4, yRadius: 4)
		r.fill()
	}

    public override func updateLayer() {
		self.buttonLayer.cornerRadius = 4
	}

    public override var state: NSControl.StateValue {
		get {
			return super.state
		}
		set {
			super.state = newValue
			if (newValue == .on) {
				self.buttonLayer.backgroundColor = self.activeColor.cgColor
			}
			else {
				self.buttonLayer.backgroundColor = nil
			}
		}
	}

	// MARK: - Tracking Area

	private var trackingArea: NSTrackingArea?
	override open func updateTrackingAreas() {
		super.updateTrackingAreas()

		if let t = self.trackingArea {
			self.removeTrackingArea(t)
		}
		let newTrackingArea = NSTrackingArea(
			rect: self.bounds,
			options: [
				.mouseEnteredAndExited,
				.activeInActiveApp,
			],
			owner: self,
			userInfo: nil
		)
		self.addTrackingArea(newTrackingArea)
	}

	// MARK: - Mouse Actions

	private var mouseIsDown: Bool = false
	private var mouseInside: Bool = false
	private var mouseDragLocationX: CGFloat?

	public var hoverColorAlpha: CGFloat = 0.1
    	public var pressedColorAlpha: CGFloat = 0.25
    	public var activeColorAlpha: CGFloat = 0.2

	var hoverColor: NSColor {
		return UsingEffectiveAppearance(of: self) {
			let hc = parent.backgroundColor.flatContrastColor().withAlphaComponent(hoverColorAlpha)
			return hc
		}
	}

	var pressedColor: NSColor {
		return UsingEffectiveAppearance(of: self) {
			let hc = parent.backgroundColor.flatContrastColor().withAlphaComponent(pressedColorAlpha)
			return hc
		}
	}

	var activeColor: NSColor {
		return UsingEffectiveAppearance(of: self) {
			let hc = parent.backgroundColor.flatContrastColor().withAlphaComponent(activeColorAlpha)
			return hc
		}
	}

    public override func mouseEntered(with _: NSEvent) {
		guard self.isEnabled else { return }
		// Highlight with quaternary label color

		if (self.state == .on) {
			self.buttonLayer.backgroundColor = self.activeColor.cgColor
		}
		else if self.mouseIsDown {
			self.buttonLayer.backgroundColor = self.pressedColor.cgColor
		}
		else {
			self.buttonLayer.backgroundColor = self.hoverColor.cgColor
		}
		self.mouseInside = true
	}

    public override func mouseExited(with _: NSEvent) {

		if (self.state == .on) {
			self.buttonLayer.backgroundColor = self.activeColor.cgColor
		}
		else {
			self.buttonLayer.backgroundColor = nil
		}
		self.mouseInside = false
	}

    public override func mouseDown(with _: NSEvent) {
		guard self.isEnabled else { return }
		self.buttonLayer.backgroundColor = self.pressedColor.cgColor
		self.mouseIsDown = true
	}

    public override func mouseDragged(with event: NSEvent) {
		let location = convert(event.locationInWindow, from: nil)
		if self.mouseDragLocationX == nil {
			self.mouseDragLocationX = location.x
		}
		else if abs(self.mouseDragLocationX! - location.x) < 10 {
			// Do nothing. Need to be sticky to avoid accidental drags
		}
		else {
			// Let the next responder up the chain handle it (should be the action bar!)
			self.mouseInside = false
			self.mouseDragLocationX = nil
			super.mouseDragged(with: event)
		}
	}

    public override func mouseUp(with _: NSEvent) {
		if self.mouseInside {
			self.buttonLayer.backgroundColor = self.hoverColor.cgColor
			if let t = self.target {
				_ = t.perform(self.action, with: self)
			}
			else if let block = self.actionBlock {
				block()
			}
			if let menu = self.menu {
				menu.popUp(positioning: nil, at: NSPoint(x: self.bounds.minX, y: self.bounds.maxY + 8), in: self)
			}
		}
		else {
			self.buttonLayer.backgroundColor = nil
		}

		if (self.state == .on) {
			self.buttonLayer.backgroundColor = self.pressedColor.cgColor
		}

		self.mouseIsDown = false
	}

    public override func rightMouseDown(with _: NSEvent) {
		self.parent?.rightClick(for: self)
	}
}

extension DSFActionBarButton: DSFActionBarItem {
    public var position: CGRect {
		return self.parent.rect(for: self)
	}

    public override var menu: NSMenu? {
		get {
			super.menu
		}
		set {
			super.menu = newValue
			if newValue != nil {
				self.action = nil
				self.target = nil
			}
			self.updateMenuStatus()
		}
	}

    public var disabled: Bool {
		get {
			return !super.isEnabled
		}
		set {
			super.isEnabled = !newValue
		}
	}

    public func setAction(_ action: Selector, for target: AnyObject) {
		self.action = action
		self.target = target
		self.menu = nil
		self.updateMenuStatus()
	}
}

extension DSFActionBarButton {
	static var menuImage: NSImage = {
		let im = NSImage(size: NSSize(width: 9, height: 16))
		im.lockFocus()

		NSColor.white.setStroke()

		let path = NSBezierPath()
		path.move(to: NSPoint(x: 2, y: 9))
		path.line(to: NSPoint(x: 5, y: 6))
		path.line(to: NSPoint(x: 8, y: 9))
		path.lineWidth = 1.5
		path.lineCapStyle = .round
		path.stroke()
		im.unlockFocus()
		im.isTemplate = true
		return im
	}()
}

#endif
