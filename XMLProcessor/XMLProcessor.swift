//
//  XMLProcessor.swift
//  XMLProcessor
//
//  Created by Craig Hockenberry on 5/15/23.
//

import Foundation

class XMLProcessor: NSObject {

	typealias Collector = Dictionary<String,Any>
	
	var textValue: String?
	var textNode: Bool = false
	
	var elementNameStack: [String] = []
	var elementAttributesStack: [[String : String]] = []

	var collectorStack: [Collector] = [[:]]

	var level = 0
	var debug = false
	
	func parse(data: Data, debug: Bool = false) -> (Collector?) {
		self.debug = debug
		
		let parser = XMLParser(data: data)
		parser.delegate = self
		parser.parse()
		
		if debug {
			if let data = try? JSONSerialization.data(withJSONObject: collectorStack.first!, options: [.prettyPrinted]) {
				if let debug = String(data: data, encoding: .utf8) {
					print(debug)
				}
			}
		}
		
		return collectorStack.first
	}
	
}

extension XMLProcessor: XMLParserDelegate {
	
	private func levelMessage(_ message: String) {
		if debug {
			let indent = String(repeating: ". ", count: level)
			print("\(indent)\(message)")
		}
	}

	private func updateCollector(_ currentCollector: Collector, elementName: String, elementValue: Any) -> Collector {
		var collector = currentCollector
		
		if collector.keys.contains(elementName) {
			// NOTE: If the dictionary already contains the key for the element name, put the existing values, and
			// any subsequent values, into an array.
			if var array = collector[elementName] as? Array<Any> {
				array.append(elementValue)
				collector[elementName] = array
			}
			else {
				let array = [collector[elementName] as Any, elementValue]
				collector[elementName] = array
			}
		}
		else {
			collector[elementName] = elementValue
		}

		return collector
	}

	private func elementAttributeName(for elementName: String) -> String {
		return elementName + "$attrs"
	}

	// MARK: -
	
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
		levelMessage("start \(elementName)")
		level += 1

		textValue = nil
		
		elementNameStack.append(elementName)
		elementAttributesStack.append(attributeDict)

		collectorStack.append([:])
	}
	
	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		level -= 1
		levelMessage("end \(elementName) \(textNode ? " (TEXT) " : "")")
		
		let elementName = elementNameStack.removeLast()
		let elementAttributes = elementAttributesStack.removeLast()
		
		if let lastCollector = collectorStack.popLast() {
			if var parentCollector = collectorStack.popLast() {
				if textNode {
					if let textValue {
						parentCollector = updateCollector(parentCollector, elementName: elementName, elementValue: textValue)
					}
					if !elementAttributes.isEmpty {
						let attributesElementName = elementAttributeName(for: elementName)
						parentCollector = updateCollector(parentCollector, elementName: attributesElementName, elementValue: elementAttributes)
					}
					collectorStack.append(parentCollector)
				}
				else {
					// skip empty element values
					if !lastCollector.isEmpty {
						parentCollector = updateCollector(parentCollector, elementName: elementName, elementValue: lastCollector)
					}
					if !elementAttributes.isEmpty {
						let attributesElementName = elementAttributeName(for: elementName)
						parentCollector = updateCollector(parentCollector, elementName: attributesElementName, elementValue: elementAttributes)
					}
					collectorStack.append(parentCollector)
				}
			}
		}
		
		textNode = false
	}
	
	func parser(_ parser: XMLParser, foundCharacters string: String) {
		let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
		if text.count > 0 {
			levelMessage("text = \(text)")
			if let textValue {
				self.textValue = textValue.appending(text)
			}
			else {
				self.textValue = text
			}
			textNode = true
		}
	}
	
	func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {

		// TODO: Handle other encodings?
		if let dataText = String(data: CDATABlock, encoding: .utf8) {
			levelMessage("dataText = \(dataText)")
			if let textValue {
				self.textValue = textValue.appending(dataText)
			}
			else {
				self.textValue = dataText
			}
			textNode = true
		}

	}
	
	func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
		assert(false, "XML parser failed with \(parseError)")
	}
		
}
