//
//  IO.swift
//  MetalColor
//
//  Created by Ruoyu Fu on 20/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import UIKit
import MetalPerformanceShaders

var InputImageSize = 144


func Input(device: MTLDevice)->Layer{
    let scale = MPSImageLanczosScale(device: device)
    
    let library = device.newDefaultLibrary()!
    let gray3Fun = library.makeFunction(name: "gray")!
    let gray3 = try! device.makeComputePipelineState(function: gray3Fun)
    return { (commandbuffer, input) in
        let scaledID = MPSImageDescriptor(channelFormat: .float16,
                                          width: InputImageSize,
                                          height: InputImageSize,
                                          featureChannels: 1)

        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: InputImageSize,
                                          height: InputImageSize,
                                          featureChannels: 3)
        let scaled = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: scaledID)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
        scale.encode(commandBuffer: commandbuffer, sourceTexture: input.texture, destinationTexture: scaled.texture)
        let commandEncoder = commandbuffer.makeComputeCommandEncoder()
        commandEncoder.setTexture(scaled.texture, at: 0)
        commandEncoder.setTexture(output.texture, at: 1)
        commandEncoder.dispatch(pipeline: gray3, image: output)
        commandEncoder.endEncoding()
        releaseImage(scaled)
        return (commandbuffer, output)
    }
}

func AdjustGray(device: MTLDevice)->Layer{
    let scale = MPSCNNNeuronLinear(device: device, a: 1, b: -0.5)
    return { (commandbuffer, image) in
        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: image.width,
                                          height: image.height,
                                          featureChannels: image.featureChannels)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
        scale.encode(commandBuffer: commandbuffer, sourceImage: image, destinationImage: output)
        return (commandbuffer, output)
    }
}

func AdjustVGG(device: MTLDevice)->Layer{
    let library = device.newDefaultLibrary()!
    let addFun = library.makeFunction(name: "adjustVGG")!
    let add = try! device.makeComputePipelineState(function: addFun)

    return { (commandbuffer, image) in
        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: image.width,
                                          height: image.height,
                                          featureChannels: image.featureChannels)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
        let commandEncoder = commandbuffer.makeComputeCommandEncoder()
        commandEncoder.setTexture(image.texture, at: 0)
        commandEncoder.setTexture(output.texture, at: 1)
        commandEncoder.dispatch(pipeline: add, image: image)
        commandEncoder.endEncoding()
        releaseImage(image)
        return (commandbuffer, output)
    }
}
