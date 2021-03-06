//
//  Math.swift
//
//  Created by David Gavilan on 3/19/16.
//  Copyright © 2016 David Gavilan. All rights reserved.
//

import Foundation
import UIKit

let PI      : Float = 3.1415926535897932384626433832795
let PI_2    = 0.5 * PI
let PI2     = 2.0 * PI
let PI_INV  = 1.0 / PI
let NORM_SQR_ERROR_TOLERANCE : Float = 0.001
let π       : Double = Double(PI)

/// Converts angle in degrees to radians
public func DegToRad(_ angle: Float) -> Float {
    return angle * (PI/180.0)
}
/// Gets the sign of a number
func Sign(_ n: Float) -> Float {
    return (n>=0) ?1:-1
}
/// Max
func Max(_ a: CGFloat, b: CGFloat) -> CGFloat {
    return (a>=b) ?a:b
}
func Max(_ a: Float, b: Float) -> Float {
    return (a>=b) ?a:b
}
func Max(_ a: Int, b: Int) -> Int {
    return (a>=b) ?a:b
}
/// Min
func Min(_ a: CGFloat, b: CGFloat) -> CGFloat {
    return (a<=b) ?a:b
}
func Min(_ a: Float, b: Float) -> Float {
    return (a<=b) ?a:b
}
func Min(_ a: Int, b: Int) -> Int {
    return (a<=b) ?a:b
}
/// Ceil for ints
func CeilDiv(_ a: Int, b: Int) -> Int {
    return (a + b - 1) / b
}
public func IsClose(_ a: Float, _ b: Float, epsilon: Float = 0.0001) -> Bool {
    return ( fabsf( a - b ) < epsilon )
}
public func IsClose(_ a: CGFloat, _ b: CGFloat, epsilon: Float = 0.0001) -> Bool {
    return ( fabsf( Float(a - b) ) < epsilon )
}

/// Clamp
public func Clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
    return (value<min) ?min:(value>max) ?max:value
}
public func Clamp(_ value: Float, min: Float, max: Float) -> Float {
    return (value<min) ?min:(value>max) ?max:value
}
public func Clamp(_ value: Int, min: Int, max: Int) -> Int {
    return (value<min) ?min:(value>max) ?max:value
}
/// Random Int. Preferred to rand() % upperBound
public func Rand(_ upperBound: UInt32) -> UInt32 {
    return arc4random_uniform(upperBound)
}
public func Rand(_ upperBound: Int) -> Int {
    return Int(Rand(UInt32(upperBound)))
}
/// Random Float between 0 and 1
public func Randf() -> Float {
    return Float(Rand(10000)) * 0.0001
    // or use drand48? needs a seed srand48
}
/// Random sign
public func RandSign() -> Float {
    return (Rand(2) == 0 ? -1.0 : 1.0)
}
/// Random event with given probabily
public func RandEvent(_ probality: Float) -> Bool {
    let r = Float(Rand(10000))
    return r < 10000.0 * probality
}
public extension Array {
    public func shuffled() -> [Element] {
        var list = self
        for i in 0..<(list.count - 1) {
            // I need a seeded rand() to make it deterministic
            let upperBound = UInt32(list.count - i)
            let j = Int(UInt32(arc4random()) % upperBound) + i
            //let j = Int(arc4random_uniform(upperBound)) + i
            guard i != j else { continue }
            list.swapAt(i, j)
        }
        return list
    }
    public func randomElement() -> Element {
        let i = Rand(self.count)
        return self[i]
    }
    // https://stackoverflow.com/a/38156873/1765629
    public func chunked(by chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}

public extension Float {
    /// Rounds to decimal places value
    public func rounded(toPlaces places:Int) -> Float {
        let divisor = powf(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}
