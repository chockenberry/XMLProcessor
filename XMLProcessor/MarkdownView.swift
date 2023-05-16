//
//  MarkdownView.swift
//  XMLProcessor
//
//  Created by Craig Hockenberry on 5/16/23.
//

import SwiftUI

struct MarkdownView: View {
	let entry: Entry
	
	@State private var markdown: String = "**Loading…**"
	
	var body: some View {
		ScrollView {
			let options = AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: true, interpretedSyntax: .full)
			let attributedText = (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString("Parse Failure")
			Text(attributedText.styledText)
				.padding()
				.onAppear {
					Task {
						if let url = URL(string: entry.link + ".text") {
							if let (data, _) = try? await URLSession.shared.data(from: url) {
								if let string = String(data: data, encoding: .utf8) {
									print(string)
									markdown = string
									return
								}
							}
						}
						markdown = "_Load Failure_"
					}
				}
		}
		.navigationTitle(entry.title)
		.navigationBarTitleDisplayMode(.inline)
	}
}

extension AttributedString {
	
	// NOTE: For more information on how this styling works, check out Frank Rausch's project on GitHub:
	// https://github.com/frankrausch/AttributedStringStyledMarkdown
	
	var styledText: AttributedString {
		get {
			let fontSize: CGFloat = 18
			
			let font = UIFont.systemFont(ofSize: fontSize)
			let italicFont = UIFont.italicSystemFont(ofSize: fontSize)
			let boldFont = UIFont.boldSystemFont(ofSize: fontSize)
			let boldItalicFont: UIFont
			if let fontDescriptor = font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
				boldItalicFont = UIFont(descriptor: fontDescriptor, size: fontSize)
			}
			else {
				boldItalicFont = boldFont
			}
			
			let foregroundColor = UIColor.label
			
			do {
				var result = self
				result.font = font
				result.foregroundColor = foregroundColor
				
				let paragraphStyle = NSMutableParagraphStyle()
				paragraphStyle.lineSpacing = 1.0
				paragraphStyle.paragraphSpacing = 12.0
				paragraphStyle.lineBreakMode = .byTruncatingTail
				result.paragraphStyle = paragraphStyle
				
				for run in result.runs {
					let intent = run.attributes[AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute.self]
					if intent == .emphasized {
						result[run.range].font = italicFont
					}
					else if intent == .stronglyEmphasized {
						result[run.range].font = boldFont
					}
					else if intent == [.stronglyEmphasized, .emphasized] {
						result[run.range].font = boldItalicFont
					}
					
					if run.attributes[AttributeScopes.FoundationAttributes.LinkAttribute.self] != nil {
						result[run.range].link = nil // because UILabel is dumb and wants to make it blue.
						result[run.range].foregroundColor = UIColor(named: "AccentColor")
					}
				}
				
				for (intentBlock, intentRange) in result.runs[AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self].reversed() {
					guard let intentBlock else { continue }
					
					var listOrdered = false
					
					// NOTE: The paragraph styles only work in UIKit. They aren't supported yet in SwiftUI.
					
					for intent in intentBlock.components {
						switch intent.kind {
						case .paragraph:
							let paragraphStyle = NSMutableParagraphStyle()
							paragraphStyle.firstLineHeadIndent = 10.0
							paragraphStyle.headIndent = 0
							paragraphStyle.tailIndent = 0
							paragraphStyle.paragraphSpacing = 12.0

							result[intentRange].paragraphStyle = paragraphStyle
						case .header(level: let level):
							let headerFontSize = (fontSize + 8.0) - (CGFloat(level) * 2.0)
							let headerFont = UIFont.systemFont(ofSize: headerFontSize)

							result[intentRange].font = headerFont
						case .blockQuote:
							let blockParagraphStyle = NSMutableParagraphStyle()
							blockParagraphStyle.firstLineHeadIndent = 10.0
							blockParagraphStyle.headIndent = 10.0
							blockParagraphStyle.tailIndent = -10.0
							blockParagraphStyle.paragraphSpacing = 12.0

							result[intentRange].paragraphStyle = blockParagraphStyle
							result[intentRange].foregroundColor = .secondary
						case .orderedList:
							listOrdered = true
						case .unorderedList:
							listOrdered = false
						case .listItem(ordinal: let ordinal):
							if listOrdered {
								result.characters.insert(contentsOf: "\(ordinal) ", at: intentRange.lowerBound)
							}
							else {
								result.characters.insert(contentsOf: "• ", at: intentRange.lowerBound)
							}
						default:
							break
						}
					}
					
					result.characters.insert(contentsOf: "\n\n", at: intentRange.lowerBound)
				}
				return result
			}
		}
	}

}

struct MarkdownView_Previews: PreviewProvider {
	static var previews: some View {
		let entry = Entry(title: "Test Entry", date: Date(), link: "https://daringfireball.net/linked/2023/05/02/browser-company-swift-windows")
		MarkdownView(entry: entry)
	}
}
