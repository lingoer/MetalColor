//
//  BatchNorm.swift
//  MetalColor
//
//  Created by Ruoyu Fu on 20/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import Foundation
import MetalPerformanceShaders


func BatchNorm(features: Int, device: MTLDevice, name: String) -> Layer {
    

    let beta        = loadParam(name: name + "_bn_beta", count: features)!
    let gamma       = loadParam(name: name + "_bn_gamma", count: features)!
    let mean        = loadParam(name: name + "_bn_mean", count: features)!
    let variance    = loadParam(name: name + "_bn_variance", count: features)!

    let bBuffer = device.makeBuffer(bytes: beta, length: features*4, options: [])
    let gBuffer = device.makeBuffer(bytes: gamma, length: features*4, options: [])
    let mBuffer = device.makeBuffer(bytes: mean, length: features*4, options: [])
    let vBuffer = device.makeBuffer(bytes: variance, length: features*4, options: [])

    let library = device.newDefaultLibrary()!
    let bnFun = library.makeFunction(name: "batch_normal")!
    let bn = try! device.makeComputePipelineState(function: bnFun)
    let bnFunrgb = library.makeFunction(name: "batch_normal_rgba")!
    let bnrgb = try! device.makeComputePipelineState(function: bnFunrgb)
    return { (commandbuffer, image) in
        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: image.width,
                                          height: image.height,
                                          featureChannels: features)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)

        let commandEncoder = commandbuffer.makeComputeCommandEncoder()
        commandEncoder.setTexture(image.texture, at: 0)
        commandEncoder.setTexture(output.texture, at: 1)
        commandEncoder.setBuffer(bBuffer, offset: 0, at: 0)
        commandEncoder.setBuffer(gBuffer, offset: 0, at: 1)
        commandEncoder.setBuffer(mBuffer, offset: 0, at: 2)
        commandEncoder.setBuffer(vBuffer, offset: 0, at: 3)
        if (features<=4) {
            commandEncoder.dispatch(pipeline: bnrgb, image: image)

        }else{
            commandEncoder.dispatch(pipeline: bn, image: image)
        }
        commandEncoder.endEncoding()
        releaseImage(image)
        return (commandbuffer, output)
    }
}
