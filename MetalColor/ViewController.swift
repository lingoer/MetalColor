//
//  ViewController.swift
//  MetalColor
//
//  Created by Ruoyu Fu on 19/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import UIKit
import CoreVideo
import AVFoundation
import MetalPerformanceShaders
import MetalKit
import Accelerate

let textureFormat = MPSImageFeatureChannelFormat.float16


class ViewController: UIViewController {

    @IBOutlet weak var mtkView: MTKView!

    let session = AVCaptureSession()
    let output = AVCaptureVideoDataOutput()
    var colorize: Layer?
    var videoTextureCache : CVMetalTextureCache?
    var commandQueue: MTLCommandQueue!
    var displayPipeline: MTLComputePipelineState!

    let semaphoreDraw = DispatchSemaphore(value: 0)
    let semaphoreCapture = DispatchSemaphore(value: 1)

    @IBOutlet weak var label: UILabel!
    @IBAction func changeQuality(_ sender: UISlider) {
        InputImageSize = Int(64 + (sender.value * 160))
        label.text = "Quality: \(InputImageSize)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        commandQueue = device.makeCommandQueue()
        guard let function = device.newDefaultLibrary()?.makeFunction(name: "display") else{
            return
        }

        
        displayPipeline = try! device.makeComputePipelineState(function: function)
        mtkView.device = device
        mtkView.delegate = self
        colorize = ColorNet(device: device)
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &videoTextureCache)
        videoInit()

    }

    func videoInit() {
        let queue = DispatchQueue(label: "com.color.back")
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        guard let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else { return }
        try? session.addInput(AVCaptureDeviceInput(device: videoDevice))
        session.addOutput(output)
        output.connection(withMediaType: AVMediaTypeVideo).videoOrientation = .portrait
        session.sessionPreset = AVCaptureSessionPreset352x288
        session.startRunning()
    }

    let sid     = MPSImageDescriptor(channelFormat: textureFormat, width: 160, height: 160, featureChannels: 3)
    let c1_0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 160, height: 160, featureChannels: 64)
    let c1id    = MPSImageDescriptor(channelFormat: textureFormat, width: 80, height: 80, featureChannels: 64)
    let c2_0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 80, height: 80, featureChannels: 128)
    let c2id    = MPSImageDescriptor(channelFormat: textureFormat, width: 40, height: 40, featureChannels: 128)
    let c3_0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 40, height: 40, featureChannels: 256)
    let c3id    = MPSImageDescriptor(channelFormat: textureFormat, width: 20, height: 20, featureChannels: 256)
    let c4id    = MPSImageDescriptor(channelFormat: textureFormat, width: 20, height: 20, featureChannels: 512)
    let oid     = MPSImageDescriptor(channelFormat: textureFormat, width: 160, height: 160, featureChannels: 2)
    var yTexture:MTLTexture? = nil

}
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        semaphoreCapture.wait()
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var yTextureRef : CVMetalTexture?
        let yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        let yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);

        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  videoTextureCache!,
                                                  pixelBuffer,
                                                  nil,
                                                  .r8Unorm,
                                                  yWidth, yHeight, 0,
                                                  &yTextureRef)
        yTexture = CVMetalTextureGetTexture(yTextureRef!)
        semaphoreDraw.signal()
    }
}

extension ViewController: MTKViewDelegate{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize){

    }
    func draw(in view: MTKView) {
        semaphoreDraw.wait()
        guard let drawable = view.currentDrawable,
         let yTexture = self.yTexture else {
            return
        }
        let commandBuffer = commandQueue.makeCommandBuffer()
        MPSTemporaryImage.prefetchStorage(with: commandBuffer, imageDescriptorList: [sid, c1_0id, c1id, c2_0id, c2id, c3_0id, c3id, c4id, oid])
        let src = MPSImage(texture: yTexture, featureChannels: 1)
        let (_, uv) = colorize!(commandbuffer: commandBuffer, image: src)
        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder.setTexture(yTexture, at: 0)
        encoder.setTexture(uv.texture, at: 1)
        encoder.setTexture(drawable.texture, at: 2)
        encoder.dispatch(pipeline: displayPipeline, width: drawable.texture.width, height: drawable.texture.height, featureChannels: 3)
        encoder.endEncoding()
        releaseImage(uv)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        drawable.present()
        semaphoreCapture.signal()
        
    }
}

