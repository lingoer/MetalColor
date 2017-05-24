//
//  UpscaleAdd.swift
//  MetalColor
//
//  Created by Ruoyu Fu on 20/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import Foundation
import MetalPerformanceShaders

func UpscaleAdd(device: MTLDevice)->(Node)->Layer{
    let library = device.newDefaultLibrary()!
    let addFun = library.makeFunction(name: "upscaleAdd")!
    let add = try! device.makeComputePipelineState(function: addFun)

    return { (_, mask) in
        return { (commandbuffer, source) in
            let outputID = MPSImageDescriptor(channelFormat: .float16,
                                              width: mask.width,
                                              height: mask.height,
                                              featureChannels: mask.featureChannels)
            let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
            let commandEncoder = commandbuffer.makeComputeCommandEncoder()
            commandEncoder.setTexture(source.texture, at: 0)
            commandEncoder.setTexture(mask.texture, at: 1)
            commandEncoder.setTexture(output.texture, at: 2)
            commandEncoder.dispatch(pipeline: add, image: mask)
            commandEncoder.endEncoding()
            releaseImage(source)
            releaseImage(mask)
            return (commandbuffer, output)
        }
    }
}

func Add(device: MTLDevice)->(Node)->Layer{
    let library = device.newDefaultLibrary()!
    let addFun = library.makeFunction(name: "add")!
    let add = try! device.makeComputePipelineState(function: addFun)

    return { source in
        return { (commandbuffer, image) in
            let outputID = MPSImageDescriptor(channelFormat: .float16,
                                              width: image.width,
                                              height: image.height,
                                              featureChannels: image.featureChannels)
            let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
            let commandEncoder = commandbuffer.makeComputeCommandEncoder()
            commandEncoder.setTexture(source.image.texture, at: 0)
            commandEncoder.setTexture(image.texture, at: 1)
            commandEncoder.setTexture(output.texture, at: 2)
            commandEncoder.dispatch(pipeline: add, image: image)
            commandEncoder.endEncoding()
            releaseImage(image)
            releaseImage(source.image)
            return (commandbuffer, output)
        }
    }
}
