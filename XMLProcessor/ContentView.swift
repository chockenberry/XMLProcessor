//
//  ContentView.swift
//  XMLProcessor
//
//  Created by Craig Hockenberry on 5/15/23.
//

import SwiftUI

struct Entry: Hashable {
	var title: String
	var date: Date
	var link: String
}

struct ContentView: View {
	
	@State private var entries: Array<Entry> = []
	
    var body: some View {
		NavigationStack {
			Form {
				ForEach(entries, id: \.self) { entry in
					NavigationLink {
						MarkdownView(entry: entry)
					} label: {
						HStack {
							Text(entry.title)
							Spacer()
							Text(entry.date, style: .date)
								.font(.caption)
								.foregroundColor(.secondary)
						}
					}
				}
			}
			.formStyle(.grouped)
			.navigationTitle("Daring Fireball Atom Feed")
			.navigationBarTitleDisplayMode(.inline)
			.onAppear {
				Task {
					let url = URL(string: "https://daringfireball.net/feeds/main")!
					if let (xml, _) = try? await URLSession.shared.data(from: url) {
						let processor = XMLProcessor()
						if let object = processor.parse(data: xml, debug: false) {
							// NOTE: It sure would be nice to have an easy way to unbox the feed Dictionary with a Decoder,
							// but there isn't, so we'll just poke around in the data and unbox the values ourself.
							if let feed = object["feed"] as? Dictionary<String,Any> {
								if let entries = feed["entry"] as? Array<Any> {
									self.entries = entries.compactMap({ element in
										if let entry = element as? Dictionary<String,Any> {
											if let title = entry["title"] as? String,
											   let published = entry["published"] as? String,
											   //let content = entry["content"] as? String,
											   let linkAttributes = entry["link$attrs"] as? Array<Any> {
												var relatedLink: String?
												var alternateLink: String?
												for linkAttribute in linkAttributes	{
													if let dictionary = linkAttribute as? Dictionary<String,Any> {
														if let linkRelationship = dictionary["rel"] as? String {
															if linkRelationship == "related" {
																if let linkValue = dictionary["href"] as? String {
																	relatedLink = linkValue
																}
															}
															else if linkRelationship == "alternate" {
																if let linkValue = dictionary["href"] as? String {
																	alternateLink = linkValue
																}
															}
														}
													}
												}
												let link = relatedLink ?? alternateLink ?? "https://daringfireball.net"
												if let date = ISO8601DateFormatter().date(from: published) {
													return Entry(title: title, date: date, link: link)
												}
											}
										}
										return nil
									})
								}
							}
						}
					}
				}
			}
		}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
