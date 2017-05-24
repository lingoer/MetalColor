//
//  Helper.swift
//  MetalColor
//
//  Created by Ruoyu Fu on 24/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import Foundation
import MetalPerformanceShaders

typealias Node = (commandbuffer: MTLCommandBuffer, image: MPSImage)
typealias Layer = (Node) -> Node

precedencegroup PipePrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
}

infix operator |> : PipePrecedence

// TODO: use try catch
func |>
    (lhs: Node,
     rhs: Layer)
    -> Node {
        return rhs(lhs)
}

func retainImage(_ image: MPSImage, count: Int = 1) {
    (image as? MPSTemporaryImage)?.readCount += count
}

func releaseImage(_ image: MPSImage, count: Int = 1) {
    (image as? MPSTemporaryImage)?.readCount -= count
}

func retain(_ count: Int = 1) -> Layer{
    return { node in
        retainImage(node.image)
        return node
    }
}

func loadParam(name: String, ext: String? = nil, count: Int) -> [Float]? {
    let size = count * MemoryLayout<Float>.size
    guard let path = Bundle.main.path( forResource: name, ofType: ext) else{ return nil }
    let fd  = open( path, O_RDONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)
    defer { close(fd) }
    guard let hdrW = mmap(nil, size, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0) else { return nil }
    let w = UnsafePointer(hdrW.bindMemory(to: Float.self, capacity: size))
    return (0 ..< count).map{w[$0]}
}

extension MTLComputeCommandEncoder {

    public func dispatch(pipeline: MTLComputePipelineState,
                         width: Int,
                         height: Int,
                         featureChannels: Int,
                         numberOfImages: Int = 1) {
        let slices = ((featureChannels + 3)/4) * numberOfImages

        let h = pipeline.threadExecutionWidth
        let w = pipeline.maxTotalThreadsPerThreadgroup / h
        let d = 1
        let threadGroupSize = MTLSizeMake(w, h, d)

        let threadGroups = MTLSizeMake(
            (width  + threadGroupSize.width  - 1) / threadGroupSize.width,
            (height + threadGroupSize.height - 1) / threadGroupSize.height,
            (slices + threadGroupSize.depth  - 1) / threadGroupSize.depth)

        setComputePipelineState(pipeline)
        dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }

    public func dispatch(pipeline: MTLComputePipelineState, image: MPSImage) {
        dispatch(pipeline: pipeline,
                 width: image.width,
                 height: image.height,
                 featureChannels: image.featureChannels,
                 numberOfImages: image.numberOfImages)
    }

    func dispatch(pipeline: MTLComputePipelineState, node: Node) {
        dispatch(pipeline: pipeline,
                 width: node.image.width,
                 height: node.image.height,
                 featureChannels: node.image.featureChannels,
                 numberOfImages: node.image.numberOfImages)
    }
    
}

