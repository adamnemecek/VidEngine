//
//  VidController.swift
//  VidFramework
//
//  Created by David Gavilan on 2018/02/17.
//  Copyright © 2018 David Gavilan. All rights reserved.
//
import UIKit
import MetalKit
import CoreMotion
import AVFoundation
import simd

open class VidController: UIViewController, MTKViewDelegate {

    public var device: MTLDevice! = nil

    var commandQueue: MTLCommandQueue! = nil
    var timer: CADisplayLink! = nil
    var lastFrameTimestamp: TimeInterval = 0.0
    var elapsedTimeGPU: TimeInterval = 0.0
    let inflightSemaphore = DispatchSemaphore(value: Renderer.NumSyncBuffers)

    // for motion control
    let motionManager = CMMotionManager()
    var currentPitch : Double = 0
    var currentTouch = float2(0, -2)
    private var cameraAngleX: Float = 0
    private var cameraAngleY: Float = 0
    private var debugCube: CubePrimitive!
    private var _clearColor = UIColor.black

    public var clearColor: UIColor {
        get {
            return _clearColor
        }
        set {
            _clearColor = newValue
            let c = LinearRGBA(newValue)
            Renderer.shared.clearColor = MTLClearColor(red: Double(c.r), green: Double(c.g), blue: Double(c.b), alpha: Double(c.a))
        }
    }

    public var camera: Camera {
        get {
            return Renderer.shared.camera
        }
        set {
            Renderer.shared.camera = newValue
        }
    }
    public var isWideColor = false {
        didSet {
            if let view = self.view as? MTKView {
                // The pixel format for a MetalKit view must be bgra8Unorm, bgra8Unorm_srgb, rgba16Float, BGRA10_XR, or bgra10_XR_sRGB.
                // our shaders will be in linear RGB, so automatically apply γ
                view.colorPixelFormat = isWideColor ? .bgra10_XR_sRGB : .bgra8Unorm_srgb
            }
        }
    }
    public var textureLibrary: TextureLibrary {
        get {
            return Renderer.shared.textureLibrary
        }
    }

    open override func viewDidLoad() {

        super.viewDidLoad()

        device = MTLCreateSystemDefaultDevice()
        guard device != nil else { // Fallback to a blank UIView, an application could also fallback to OpenGL ES here.
            print("Metal is not supported on this device")
            self.view = UIView(frame: self.view.frame)
            return
        }

        // setup view properties
        let view = self.view as! MTKView
        view.device = device
        view.delegate = self
        isWideColor = true

        commandQueue = device.makeCommandQueue()
        commandQueue.label = "main command queue"

        setupMotionController()
    }

    override open func viewWillAppear(_ animated: Bool) {
        if device == nil {
            return
        }
        if Renderer.shared == nil {
            // already added in viewDidLoad, but if we dismissed the view and present it again, this will be necessary
            let view = self.view as! MTKView
            Renderer.shared = Renderer(device, view: view)
            clearColor = UIColor(red: 48/255, green: 45/255, blue: 45/255, alpha: 1)
            timer = CADisplayLink(target: self, selector: #selector(newFrame))
            timer.add(to: .main, forMode: .defaultRunLoopMode)
        }
    }

    override open func viewWillDisappear(_ animated: Bool) {
        if let _ = Renderer.shared {
            NotificationCenter.default.removeObserver(self)
            timer.remove(from: .main, forMode: .defaultRunLoopMode)
            timer = nil
            Renderer.shared = nil
            inflightSemaphore.signal()
        }
    }

    fileprivate func setupMotionController() {
        if motionManager.isGyroAvailable {
            motionManager.deviceMotionUpdateInterval = 0.2;
            motionManager.startDeviceMotionUpdates()

            motionManager.gyroUpdateInterval = 0.2
            if let queue = OperationQueue.current {
                motionManager.startGyroUpdates()
                motionManager.startGyroUpdates(to: queue) {
                    [weak self] (gyroData: CMGyroData?, error: Error?) in
                    guard let weakSelf = self else { return }
                    if let motion = weakSelf.motionManager.deviceMotion {
                        weakSelf.currentPitch = motion.attitude.pitch
                        //print(motion.attitude)
                    }
                    if let error = error {
                        NSLog("setupMotionController: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    fileprivate func dataUpdate(_ renderer: Renderer) {
        renderer.graphicsData.elapsedTime = Float(elapsedTimeGPU)
        renderer.graphicsData.currentPitch = Float(-sin(currentPitch))
        renderer.graphicsData.currentTouch = currentTouch
    }

    public func draw(in view: MTKView) {
        guard let renderer = Renderer.shared else {
            return
        }
        // use semaphore to encode 3 frames ahead
        let _ = inflightSemaphore.wait(timeout: .distantFuture)
        // could check here for .timedOut to count number of skipped frames

        dataUpdate(renderer)
        renderer.updateBuffers()

        let commandBuffer = commandQueue.makeCommandBuffer()
        commandBuffer?.label = "Frame command buffer"

        // use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use capture list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        commandBuffer?.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                strongSelf.inflightSemaphore.signal()
            }
            return
        }
        renderer.draw(view, commandBuffer: commandBuffer!)
    }


    // Updates the view’s contents upon receiving a change in layout, resolution, or size.
    // Use this method to recompute any view or projection matrices, or to regenerate any buffers to be compatible with the view’s new size.
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.setBounds(view.bounds)
    }

    // https://www.raywenderlich.com/81399/ios-8-metal-tutorial-swift-moving-to-3d
    @objc func newFrame(_ displayLink: CADisplayLink){
        if lastFrameTimestamp == 0.0 {
            lastFrameTimestamp = displayLink.timestamp
        }
        let elapsed = displayLink.timestamp - lastFrameTimestamp
        // when using timestamps, the interval switches between 16ms and 33ms,
        // while the render is always 60fps! Use .duration for GPU updates
        elapsedTimeGPU = displayLink.duration
        lastFrameTimestamp = displayLink.timestamp
        self.update(elapsed)
    }

    open func update(_ elapsed: TimeInterval) {

    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if Renderer.shared == nil {
            return
        }
        touchesMoved(touches, with: event)
    }
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if Renderer.shared == nil {
            return
        }
        let overTheFinger : CGFloat = -30
        for t in touches {
            let loc = t.location(in: view)
            currentTouch.x = 2 * Float(loc.x / view.bounds.width) - 1
            currentTouch.y = 1 - 2 * Float((loc.y + overTheFinger) / view.bounds.height)
        }
        if let touch = touches.first {
            let p0 = touch.previousLocation(in: self.view)
            let p1 = touch.location(in: self.view)
            // normalize delta using the FOV
            let fov = 2.0 * DegToRad(camera.fov)
            let x = fov * Float((p1.x - p0.x) / self.view.frame.width)
            let y = fov * Float((p1.y - p0.y) / self.view.frame.height)
            cameraAngleX += x
            cameraAngleY += y
            let qx = Quaternion.createRotationAxis(cameraAngleX, unitVector: float3(0,1,0))
            let qy = Quaternion.createRotationAxis(cameraAngleY, unitVector: float3(1,0,0))
            camera.transform.rotation = qy * qx
        }
    }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if Renderer.shared == nil {
            return
        }
        currentTouch.x = 0
        currentTouch.y = -2
    }
}
