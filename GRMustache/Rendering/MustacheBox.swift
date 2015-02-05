//
//  MustacheBox.swift
//  GRMustache
//
//  Created by Gwendal Roué on 08/11/2014.
//  Copyright (c) 2014 Gwendal Roué. All rights reserved.
//



// =============================================================================
// MARK: - Core function types

public typealias SubscriptFunction = (key: String) -> MustacheBox?
public typealias FilterFunction = (argument: MustacheBox, partialApplication: Bool, error: NSErrorPointer) -> MustacheBox?
public typealias RenderFunction = (info: RenderingInfo, error: NSErrorPointer) -> Rendering?
public typealias WillRenderFunction = (tag: Tag, box: MustacheBox) -> MustacheBox
public typealias DidRenderFunction = (tag: Tag, box: MustacheBox, string: String?) -> Void


// =============================================================================
// MARK: - MustacheBox

public struct MustacheBox {
    public let isEmpty: Bool
    public let value: Any?
    public let mustacheBool: Bool
    public let objectForKeyedSubscript: SubscriptFunction?
    public private(set) var render: RenderFunction  // It should be a `let` property. But compilers spawns unwanted "variable 'self.render' captured by a closure before being initialized" errors that we work around by modifying this property (see below). Hence the `var`.
    public let filter: FilterFunction?
    public let willRender: WillRenderFunction?
    public let didRender: DidRenderFunction?
    
    private init(value: Any? = nil, mustacheBool: Bool? = nil, objectForKeyedSubscript: SubscriptFunction? = nil, render: RenderFunction? = nil, filter: FilterFunction? = nil, willRender: WillRenderFunction? = nil, didRender: DidRenderFunction? = nil) {
        let empty = (value == nil) && (objectForKeyedSubscript == nil) && (render == nil) && (filter == nil) && (willRender == nil) && (didRender == nil)
        self.isEmpty = empty
        self.value = value
        self.mustacheBool = mustacheBool ?? !empty
        self.objectForKeyedSubscript = objectForKeyedSubscript
        self.filter = filter
        self.willRender = willRender
        self.didRender = didRender
        if let render = render {
            self.render = render
        } else {
            // Avoid compiler error: variable 'self.render' captured by a closure before being initialized
            self.render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in return nil }
            self.render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                switch info.tag.type {
                case .Variable:
                    if let value = value {
                        return Rendering("\(value)")
                    } else {
                        return Rendering("")
                    }
                case .Section:
                    return info.tag.render(info.context.extendedContext(self), error: error)
                }
            }
        }
    }
    
    public static var empty: MustacheBox {
        return Box()
    }
}

public func Box(value: Any? = nil, mustacheBool: Bool? = nil, objectForKeyedSubscript: SubscriptFunction? = nil, render: RenderFunction? = nil, filter: FilterFunction? = nil, willRender: WillRenderFunction? = nil, didRender: DidRenderFunction? = nil) -> MustacheBox {
    return MustacheBox(value: value, mustacheBool: mustacheBool, objectForKeyedSubscript: objectForKeyedSubscript, render: render, filter: filter, willRender: willRender, didRender: didRender)
}



// =============================================================================
// MARK: - MustacheBox derivation

extension MustacheBox {
    // TODO: find better name
    public func boxWithRenderFunction(render: RenderFunction) -> MustacheBox {
        return MustacheBox(
            value: self.value,
            mustacheBool: self.mustacheBool,
            objectForKeyedSubscript: self.objectForKeyedSubscript,
            render: render,
            filter: self.filter,
            willRender: self.willRender,
            didRender: self.didRender)
    }
    
}



// =============================================================================
// MARK: - MustacheBox unwrapping

extension MustacheBox {
    
    public var intValue: Int? {
        if let int = value as? Int {
            return int
        } else if let double = value as? Double {
            return Int(double)
        } else {
            return nil
        }
    }
    
    public var doubleValue: Double? {
        if let int = value as? Int {
            return Double(int)
        } else if let double = value as? Double {
            return double
        } else {
            return nil
        }
    }
    
    public var stringValue: String? {
        if value is NSNull {
            return nil
        } else if let value = value {
            return "\(value)"
        } else {
            return nil
        }
    }
}


// =============================================================================
// MARK: - DebugPrintable

extension MustacheBox: DebugPrintable {
    
    public var debugDescription: String {
        if let value = value {
            return "MustacheBox(\(value))"  // remove the "Optional" in the output
        } else {
            return "MustacheBox(\(value))"
        }
    }
}


// =============================================================================
// MARK: - Key extraction

extension MustacheBox {
    
    subscript(key: String) -> MustacheBox {
        if let objectForKeyedSubscript = objectForKeyedSubscript {
            if let box = objectForKeyedSubscript(key: key) {
                return box
            }
        }
        return MustacheBox.empty
    }
}


// =============================================================================
// MARK: - Boxing of Core Mustache functions

public func Box(objectForKeyedSubscript: SubscriptFunction) -> MustacheBox {
    return MustacheBox(objectForKeyedSubscript: objectForKeyedSubscript)
}

public func Box(filter: FilterFunction) -> MustacheBox {
    return MustacheBox(filter: filter)
}

public func Box(render: RenderFunction) -> MustacheBox {
    return MustacheBox(render: render)
}

public func Box(willRender: WillRenderFunction) -> MustacheBox {
    return MustacheBox(willRender: willRender)
}

public func Box(didRender: DidRenderFunction) -> MustacheBox {
    return MustacheBox(didRender: didRender)
}


// =============================================================================
// MARK: - Boxing of Swift scalar types

public protocol MustacheBoxable {
    var mustacheBox: MustacheBox { get }
}

public func Box<T: MustacheBoxable>(boxable: T?) -> MustacheBox {
    if let boxable = boxable {
        return boxable.mustacheBox
    } else {
        return MustacheBox.empty
    }
}

extension MustacheBox: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        return self
    }
}

extension Bool: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                } else {
                    return info.tag.render(info.context, error: error)
                }
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: self,
            render: render)
    }
}

extension Int: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                } else {
                    return info.tag.render(info.context, error: error)
                }
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: (self != 0),
            render: render)
    }
}

extension Double: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                } else {
                    return info.tag.render(info.context, error: error)
                }
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: (self != 0.0),
            render: render)
    }
}

extension String: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        let objectForKeyedSubscript = { (key: String) -> MustacheBox? in
            switch key {
            case "length":
                return Box(countElements(self))
            default:
                return nil
            }
        }
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("\(self)")
            case .Section:
                return info.tag.render(info.context.extendedContext(Box(self)), error: error)
            }
        }
        return MustacheBox(
            value: self,
            mustacheBool: (countElements(self) > 0),
            objectForKeyedSubscript: objectForKeyedSubscript,
            render: render)
    }
}


// =============================================================================
// MARK: - Boxing of Swift sequences & collections

public func Box<S: SequenceType where S.Generator.Element: MustacheBoxable>(sequence: S?) -> MustacheBox {
    // TODO: test this method
    if let sequence = sequence {
        var boxSequence = map(sequence) { Box($0) }
        var emptySequence: Bool {
            for x in sequence {
                return false
            }
            return true
        }
        return MustacheBox(
            value: boxSequence,
            mustacheBool: !emptySequence,
            render: { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(sequence)), error: error)
                } else {
                    var buffer = ""
                    var contentType: ContentType?
                    let enumerationRenderingInfo = info.renderingInfoBySettingEnumerationItem()
                    for itemBox in boxSequence {
                        if let itemRendering = itemBox.render(info: enumerationRenderingInfo, error: error) {
                            if contentType == nil {
                                contentType = itemRendering.contentType
                                buffer += itemRendering.string
                            } else if contentType == itemRendering.contentType {
                                buffer += itemRendering.string
                            } else {
                                if error != nil {
                                    error.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Content type mismatch"])
                                }
                                return nil
                            }
                        } else {
                            return nil
                        }
                    }
                    
                    if let contentType = contentType {
                        return Rendering(buffer, contentType)
                    } else {
                        return info.tag.render(info.context, error: error)
                    }
                }
        })
    } else {
        return MustacheBox.empty
    }
}

public func Box<C: CollectionType where C.Generator.Element: MustacheBoxable, C.Index: BidirectionalIndexType, C.Index.Distance == Int>(collection: C?) -> MustacheBox {
    if let collection = collection {
        var boxCollection = map(collection) { Box($0) }
        let count = countElements(collection)   // T.Index.Distance == Int
        return MustacheBox(
            value: boxCollection,
            mustacheBool: (count > 0),
            objectForKeyedSubscript: { (key: String) -> MustacheBox? in
                switch key {
                case "count":
                    return Box(count)
                case "firstObject":
                    if count > 0 {
                        return Box(collection[collection.startIndex])
                    } else {
                        return MustacheBox.empty
                    }
                case "lastObject":
                    if count > 0 {
                        return Box(collection[collection.endIndex.predecessor()])    // T.Index: BidirectionalIndexType
                    } else {
                        return MustacheBox.empty
                    }
                default:
                    return MustacheBox.empty
                }
            },
            render: { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(collection)), error: error)
                } else {
                    var buffer = ""
                    var contentType: ContentType?
                    let enumerationRenderingInfo = info.renderingInfoBySettingEnumerationItem()
                    for itemBox in boxCollection {
                        if let boxRendering = itemBox.render(info: enumerationRenderingInfo, error: error) {
                            if contentType == nil {
                                contentType = boxRendering.contentType
                                buffer += boxRendering.string
                            } else if contentType == boxRendering.contentType {
                                buffer += boxRendering.string
                            } else {
                                if error != nil {
                                    error.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Content type mismatch"])
                                }
                                return nil
                            }
                        } else {
                            return nil
                        }
                    }
                    
                    if let contentType = contentType {
                        return Rendering(buffer, contentType)
                    } else {
                        return info.tag.render(info.context, error: error)
                    }
                }
        })
    } else {
        return MustacheBox.empty
    }
}


// =============================================================================
// MARK: - Boxing of Swift dictionaries

public func Box<T: MustacheBoxable>(dictionary: [String: T]?) -> MustacheBox {
    if let dictionary = dictionary {
        var boxDictionary: [String: MustacheBox] = [:]
        for (key, item) in dictionary {
            boxDictionary[key] = Box(item)
        }
        return MustacheBox(
            value: boxDictionary,
            mustacheBool: true,
            objectForKeyedSubscript: { (key: String) -> MustacheBox? in
                return boxDictionary[key]
            },
            render: { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                switch info.tag.type {
                case .Variable:
                    return Rendering("\(boxDictionary)")
                case .Section:
                    return info.tag.render(info.context.extendedContext(Box(dictionary)), error: error)
                }
            }
        )
    } else {
        return MustacheBox.empty
    }
}


// =============================================================================
// MARK: - Boxing of Objective-C types

// The MustacheBoxable protocol can not be used by Objc classes, because MustacheBox is
// not compatible with ObjC. So let's define another protocol.
@objc public protocol ObjCMustacheBoxable {
    // Can not return a MustacheBox, because MustacheBox is not compatible with ObjC.
    // So let's return an ObjC object which wraps a MustacheBox.
    var mustacheBoxWrapper: ObjCBoxWrapper { get }
}

// The ObjC object which wraps a MustacheBox (see ObjCMustacheBoxable)
public class ObjCBoxWrapper: NSObject {
    let box: MustacheBox
    init(_ box: MustacheBox) {
        self.box = box
    }
}

public func Box(boxable: ObjCMustacheBoxable?) -> MustacheBox {
    if let boxable = boxable {
        return boxable.mustacheBoxWrapper.box
    } else {
        return MustacheBox.empty
    }
}

extension NSObject: ObjCMustacheBoxable {
    public var mustacheBoxWrapper: ObjCBoxWrapper {
        if let enumerable = self as? NSFastEnumeration {
            if respondsToSelector("objectAtIndexedSubscript:") {
                // Array
                var array: [MustacheBox] = []
                let generator = NSFastGenerator(enumerable)
                while true {
                    if let item: AnyObject = generator.next() {
                        var itemBox: MustacheBox = MustacheBox.empty
                        if let item = item as? ObjCMustacheBoxable {
                            itemBox = Box(item)
                        }
                        array.append(itemBox)
                    } else {
                        break
                    }
                }
                return ObjCBoxWrapper(Box(array))
            } else if respondsToSelector("objectForKeyedSubscript:") {
                // Dictionary
                var dictionary: [String: MustacheBox] = [:]
                let generator = NSFastGenerator(enumerable)
                while true {
                    if let key = generator.next() as? String {
                        let item = (self as AnyObject)[key]
                        var itemBox: MustacheBox = MustacheBox.empty
                        if let item = item as? ObjCMustacheBoxable {
                            itemBox = Box(item)
                        }
                        dictionary[key] = itemBox
                    } else {
                        break
                    }
                }
                return ObjCBoxWrapper(Box(dictionary))
            } else {
                // Set
                var set = NSMutableSet()
                let generator = NSFastGenerator(enumerable)
                while true {
                    if let object: AnyObject = generator.next() {
                        set.addObject(object)
                    } else {
                        break
                    }
                }
                return ObjCBoxWrapper(Box(set))
            }
            
        } else {
            return ObjCBoxWrapper(MustacheBox(
                value: self,
                mustacheBool: true,
                objectForKeyedSubscript: { (key: String) -> MustacheBox? in
                    if let value = self.valueForKey(key) as? ObjCMustacheBoxable {
                        return Box(value)
                    } else {
                        return MustacheBox.empty
                    }
                },
                render: { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
                    switch info.tag.type {
                    case .Variable:
                        return Rendering("\(self)")
                    case .Section:
                        return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                    }
            }))
        }
    }
}

extension NSNull: ObjCMustacheBoxable {
    public override var mustacheBoxWrapper: ObjCBoxWrapper {
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            switch info.tag.type {
            case .Variable:
                return Rendering("")
            case .Section:
                if info.enumerationItem {
                    return info.tag.render(info.context.extendedContext(Box(self)), error: error)
                } else {
                    return info.tag.render(info.context, error: error)
                }
            }
        }
        return ObjCBoxWrapper(MustacheBox(
            value: self,
            mustacheBool: false,
            render: render))
    }
}

extension NSNumber: ObjCMustacheBoxable {
    public override var mustacheBoxWrapper: ObjCBoxWrapper {
        switch String.fromCString(objCType)! {
        case "c", "i", "s", "l", "q", "C", "I", "S", "L", "Q":
            return ObjCBoxWrapper(Box(Int(longLongValue)))
        case "f", "d":
            return ObjCBoxWrapper(Box(doubleValue))
        case "B":
            return ObjCBoxWrapper(Box(boolValue))
        default:
            fatalError("Not implemented yet")
        }
    }
}

extension NSString: ObjCMustacheBoxable {
    public override var mustacheBoxWrapper: ObjCBoxWrapper {
        return ObjCBoxWrapper(Box(self as String))
    }
}

extension NSSet: ObjCMustacheBoxable {
    public override var mustacheBoxWrapper: ObjCBoxWrapper {
        let objectForKeyedSubscript = { (key: String) -> MustacheBox? in
            switch key {
            case "count":
                return Box(self.count)
            case "anyObject":
                if let any = self.anyObject() as? ObjCMustacheBoxable {
                    return Box(any)
                } else {
                    return MustacheBox.empty
                }
            default:
                return nil
            }
        }
        let render = { (info: RenderingInfo, error: NSErrorPointer) -> Rendering? in
            if info.enumerationItem {
                return info.tag.render(info.context.extendedContext(Box(self)), error: error)
            } else {
                var buffer = ""
                var contentType: ContentType?
                let enumerationRenderingInfo = info.renderingInfoBySettingEnumerationItem()
                for item in self {
                    var itemBox: MustacheBox = MustacheBox.empty
                    if let item = item as? ObjCMustacheBoxable {
                        itemBox = Box(item)
                    }
                    if let boxRendering = itemBox.render(info: enumerationRenderingInfo, error: error) {
                        if contentType == nil {
                            contentType = boxRendering.contentType
                            buffer += boxRendering.string
                        } else if contentType == boxRendering.contentType {
                            buffer += boxRendering.string
                        } else {
                            if error != nil {
                                error.memory = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeRenderingError, userInfo: [NSLocalizedDescriptionKey: "Content type mismatch"])
                            }
                            return nil
                        }
                    } else {
                        return nil
                    }
                }
                
                if let contentType = contentType {
                    return Rendering(buffer, contentType)
                } else {
                    switch info.tag.type {
                    case .Variable:
                        return Rendering("")
                    case .Section:
                        return info.tag.render(info.context, error: error)
                    }
                }
            }
        }
        return ObjCBoxWrapper(MustacheBox(
            value: self,
            mustacheBool: (self.count > 0),
            objectForKeyedSubscript: objectForKeyedSubscript,
            render: render))
    }
}